import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=${Secrets.fcmServerKey}',
        },
        body: jsonEncode({
          'to': '/topics/anuncios_radio',
          'notification': {
            'title': '¡Nuevo programa disponible!',
            'body': 'Ya puedes escuchar: $titulo',
            'sound': 'default',
          },
        }),
      );
    } catch (e) {
      print(e);
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
      actualizarProgreso(0.2, "Subiendo audio...");
      await enviarArchivoGithub(
        "lib/audios/$nombreLimpio.mp3",
        archivoAudio!.bytes!,
      );

      String urlPortada =
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/default.png";
      if (archivoPortada != null) {
        String ext = archivoPortada!.extension ?? "jpg";
        await enviarArchivoGithub(
          "lib/portadas/$nombreLimpio.$ext",
          archivoPortada!.bytes!,
        );
        urlPortada =
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/$nombreLimpio.$ext";
      }

      await actualizarJsonGithub(urlPortada, nombreLimpio);
      await enviarNotificacion(tituloCtrl.text.trim());
      actualizarProgreso(1.0, "¡Publicado!");

      final nuevo = {
        "titulo": tituloCtrl.text.trim(),
        "categoria": categoriaCtrl.text.trim(),
        "colaboradores": colabCtrl.text.trim(),
        "curso": cursoCtrl.text.trim(),
        "youtube": youtubeCtrl.text.trim(),
        "descripcion": descCtrl.text.trim(),
        "imagen": urlPortada,
        "url":
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nombreLimpio.mp3",
      };

      Navigator.pop(context, nuevo);
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
        title: Text("Nuevo Programa"),
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
          Text(mensajeEstado, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          LinearProgressIndicator(value: valorProgreso, color: Colors.orange),
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
            decoration: InputDecoration(labelText: "Colaboradores (opcional)"),
          ),
          TextField(
            controller: categoriaCtrl,
            decoration: InputDecoration(labelText: "Categoría"),
          ),
          TextField(
            controller: cursoCtrl,
            decoration: InputDecoration(labelText: "Curso"),
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
          ListTile(
            title: Text(archivoAudio?.name ?? "Audio MP3"),
            trailing: Icon(Icons.audio_file),
            onTap: seleccionarAudio,
          ),
          ListTile(
            title: Text(archivoPortada?.name ?? "Portada (Opcional)"),
            trailing: Icon(Icons.image),
            onTap: seleccionarPortada,
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: subirAGithub,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text("Subir el programa"),
          ),
        ],
      ),
    );
  }
}
