import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../config/curso_input_formatter.dart';
import '../config/secrets.dart';

class AdminUploadScreen extends StatefulWidget {
  final Map? programaAEditar;

  AdminUploadScreen({this.programaAEditar});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final tituloCtrl = TextEditingController();
  final categoriaCtrl = TextEditingController();
  final colabCtrl = TextEditingController();
  final youtubeCtrl = TextEditingController();
  final cursoCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  PlatformFile? archivoAudio;
  PlatformFile? archivoPortada;
  bool subiendo = false;
  String mensajeEstado = "";
  double valorProgreso = 0.0;

  final String githubToken = Secrets.githubToken;
  final String repoOwner = "ondaurbanita-code";
  final String repoName = "radio-onda-urbanita";

  @override
  void initState() {
    super.initState();
    if (widget.programaAEditar != null) {
      tituloCtrl.text = widget.programaAEditar!['titulo'] ?? "";
      categoriaCtrl.text = widget.programaAEditar!['categoria'] ?? "";
      colabCtrl.text = widget.programaAEditar!['colaboradores'] ?? "";
      cursoCtrl.text = widget.programaAEditar!['curso'] ?? "";
      youtubeCtrl.text = widget.programaAEditar!['youtube'] ?? "";
      descCtrl.text = widget.programaAEditar!['descripcion'] ?? "";
    }
  }

  Future<void> seleccionarAudio() async {
    var res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: true,
    );
    if (res != null) setState(() => archivoAudio = res.files.first);
  }

  Future<void> seleccionarPortada() async {
    var res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res != null) setState(() => archivoPortada = res.files.first);
  }

  void actualizarProgreso(double destino, String mensaje) {
    setState(() {
      mensajeEstado = mensaje;
      valorProgreso = destino;
    });
  }

  Future<void> enviarNotificacion(String titulo) async {
    try {
      final jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/service-account.json');
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(
        jsonString,
      );
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await auth.clientViaServiceAccount(
        accountCredentials,
        scopes,
      );

      final body = {
        'message': {
          'topic': 'anuncios_radio',
          'notification': {
            'title': '¡Nuevo programa disponible!',
            'body': 'Ya puedes escuchar: $titulo',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'channel_id': 'radio_notifications',
            },
          },
        },
      };

      await client.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/ondaurbanita-radio/messages:send',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      client.close();
    } catch (e) {
      print(e);
    }
  }

  Future<void> subirAGithub() async {
    if (widget.programaAEditar == null && archivoAudio == null) return;
    if (tituloCtrl.text.isEmpty || cursoCtrl.text.isEmpty) return;

    setState(() => subiendo = true);
    try {
      String nombreLimpio = tituloCtrl.text.trim().replaceAll(' ', '_');
      actualizarProgreso(0.2, "Procesando archivos...");

      if (archivoAudio != null) {
        await enviarArchivoGithub(
          "lib/audios/$nombreLimpio.mp3",
          archivoAudio!.bytes!,
        );
      }

      String urlPortada =
          widget.programaAEditar?['imagen'] ??
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/logo.png";

      if (archivoPortada != null) {
        String ext = archivoPortada!.extension ?? "jpg";
        await enviarArchivoGithub(
          "lib/portadas/$nombreLimpio.$ext",
          archivoPortada!.bytes!,
        );
        urlPortada =
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/$nombreLimpio.$ext";
      }

      actualizarProgreso(0.7, "Actualizando base de datos...");

      Map itemActualizado = {
        "titulo": tituloCtrl.text.trim(),
        "categoria": categoriaCtrl.text.trim(),
        "colaboradores": colabCtrl.text.trim(),
        "curso": cursoCtrl.text.trim(),
        "youtube": youtubeCtrl.text.trim(),
        "descripcion": descCtrl.text.trim(),
        "imagen": urlPortada,
        "url":
            widget.programaAEditar?['url'] ??
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nombreLimpio.mp3",
      };

      await actualizarJsonGithub(itemActualizado);

      if (widget.programaAEditar == null) {
        await enviarNotificacion(tituloCtrl.text.trim());
      }

      actualizarProgreso(1.0, "¡Listo!");
      await Future.delayed(Duration(seconds: 1));

      Navigator.pop(context, itemActualizado);
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => subiendo = false);
    }
  }

  Future<void> enviarArchivoGithub(String path, List<int> bytes) async {
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/$path",
    );
    String? sha;
    var res = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    if (res.statusCode == 200) sha = jsonDecode(res.body)['sha'];

    await http.put(
      url,
      headers: {
        "Authorization": "token $githubToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "message": "Upload $path",
        "content": base64Encode(bytes),
        "sha": sha,
      }),
    );
  }

  Future<void> actualizarJsonGithub(Map item) async {
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/lista_audios.json",
    );
    var res = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    var data = jsonDecode(res.body);
    List content = jsonDecode(
      utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))),
    );

    if (widget.programaAEditar != null) {
      int idx = content.indexWhere(
        (e) => e['url'] == widget.programaAEditar!['url'],
      );
      if (idx != -1) content[idx] = item;
    } else {
      content.add(item);
    }

    await http.put(
      url,
      headers: {"Authorization": "token $githubToken"},
      body: jsonEncode({
        "message": "Update JSON",
        "content": base64Encode(utf8.encode(jsonEncode(content))),
        "sha": data['sha'],
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.programaAEditar == null ? "Nuevo Programa" : "Editar Programa",
        ),
        backgroundColor: Colors.orange,
      ),
      body: subiendo ? _buildProgreso() : _buildFormulario(),
    );
  }

  Widget _buildProgreso() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: valorProgreso, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            mensajeEstado,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: tituloCtrl,
            decoration: InputDecoration(labelText: "Nombre"),
          ),
          TextField(
            controller: colabCtrl,
            decoration: InputDecoration(labelText: "Colaboradores"),
          ),
          TextField(
            controller: categoriaCtrl,
            decoration: InputDecoration(labelText: "Categoría"),
          ),
          TextField(
            controller: cursoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [CursoInputFormatter()],
            decoration: InputDecoration(labelText: "Curso (25/26)"),
          ),
          TextField(
            controller: youtubeCtrl,
            decoration: InputDecoration(labelText: "Link YouTube"),
          ),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: InputDecoration(labelText: "Descripción"),
          ),
          SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.audio_file, color: Colors.orange),
            title: Text(
              archivoAudio?.name ??
                  (widget.programaAEditar != null
                      ? "Audio ya subido"
                      : "Seleccionar MP3"),
            ),
            onTap: seleccionarAudio,
          ),
          ListTile(
            leading: Icon(Icons.image, color: Colors.blue),
            title: Text(archivoPortada?.name ?? "Cambiar Portada (Opcional)"),
            onTap: seleccionarPortada,
          ),
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: subirAGithub,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(
                widget.programaAEditar == null ? "PUBLICAR" : "GUARDAR CAMBIOS",
              ),
            ),
          ),
        ],
      ),
    );
  }
}