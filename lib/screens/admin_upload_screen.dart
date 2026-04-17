import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../config/secrets.dart';

class AdminUploadScreen extends StatefulWidget {
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
    String aa = DateTime.now().year.toString().substring(2);
    String as = (DateTime.now().year + 1).toString().substring(2);
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

      final String proyectoId = "ondaurbanita-radio";
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$proyectoId/messages:send',
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
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'channel_id': 'radio_notifications',
            },
          },
          'data': {'type': 'nuevo_audio'},
        },
      };

      await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      client.close();
    } catch (e) {
      print("error enviando notificacion v1: $e");
    }
  }

  Future<void> subirAGithub() async {
    if (archivoAudio == null ||
        tituloCtrl.text.isEmpty ||
        cursoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rellena los campos obligatorios")),
      );
      return;
    }

    setState(() => subiendo = true);

    try {
      String nombreLimpio = tituloCtrl.text.trim().replaceAll(' ', '_');

      actualizarProgreso(0.1, "Preparando archivos...");

      actualizarProgreso(0.3, "Subiendo audio a la nube...");
      await enviarArchivoGithub(
        "lib/audios/$nombreLimpio.mp3",
        archivoAudio!.bytes!,
      );

      String urlPortada =
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/logo.png";

      if (archivoPortada != null) {
        actualizarProgreso(0.6, "Subiendo imagen de portada...");
        String ext = archivoPortada!.extension ?? "jpg";
        await enviarArchivoGithub(
          "lib/portadas/$nombreLimpio.$ext",
          archivoPortada!.bytes!,
        );
        urlPortada =
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/$nombreLimpio.$ext";
      }

      actualizarProgreso(0.8, "Actualizando listado general...");
      await actualizarJsonGithub(urlPortada, nombreLimpio);

      actualizarProgreso(0.9, "Notificando a los oyentes...");
      await enviarNotificacion(tituloCtrl.text.trim());

      actualizarProgreso(1.0, "¡Publicado con éxito!");
      await Future.delayed(Duration(seconds: 1));

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => subiendo = false);
    }
  }

  Future<void> enviarArchivoGithub(String path, List<int> bytes) async {
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/$path",
    );
    String? sha;
    var getRes = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    if (getRes.statusCode == 200) sha = jsonDecode(getRes.body)['sha'];

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

  Future<void> actualizarJsonGithub(String urlP, String nLimpio) async {
    String path = "lib/lista_audios.json";
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/$path",
    );
    var res = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    var data = jsonDecode(res.body);
    List content = jsonDecode(
      utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))),
    );

    content.add({
      "titulo": tituloCtrl.text.trim(),
      "categoria": categoriaCtrl.text.trim(),
      "colaboradores": colabCtrl.text.trim(),
      "curso": cursoCtrl.text.trim(),
      "youtube": youtubeCtrl.text.trim(),
      "descripcion": descCtrl.text.trim(),
      "imagen": urlP,
      "url":
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nLimpio.mp3",
    });

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
        title: Text("Nuevo Programa"),
        backgroundColor: Colors.orange,
      ),
      body: subiendo ? _buildProgreso() : _buildFormulario(),
    );
  }

  Widget _buildProgreso() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: valorProgreso,
              color: Colors.orange,
            ),
            SizedBox(height: 30),
            Text(
              mensajeEstado,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "${(valorProgreso * 100).toInt()}%",
              style: TextStyle(
                fontSize: 24,
                color: Colors.orange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
            decoration: InputDecoration(labelText: "Colaboradores (opcional)"),
          ),
          TextField(
            controller: categoriaCtrl,
            decoration: InputDecoration(labelText: "Categoría"),
          ),
          TextField(
            controller: cursoCtrl,
            decoration: InputDecoration(labelText: "Curso (Formato 25/26)"),
          ),
          TextField(
            controller: youtubeCtrl,
            decoration: InputDecoration(labelText: "Link YouTube (Opcional)"),
          ),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Descripción corta (Opcional)",
            ),
          ),
          SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(Icons.audio_file, color: Colors.orange),
              title: Text(archivoAudio?.name ?? "Seleccionar Audio MP3"),
              onTap: seleccionarAudio,
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.image, color: Colors.blue),
              title: Text(
                archivoPortada?.name ?? "Seleccionar Portada (Opcional)",
              ),
              onTap: seleccionarPortada,
            ),
          ),
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: subirAGithub,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(
                "PUBLICAR PROGRAMA",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
