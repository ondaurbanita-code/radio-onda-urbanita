import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final tituloCtrl = TextEditingController();
  final categoriaCtrl = TextEditingController();
  final youtubeCtrl = TextEditingController();
  final cursoCtrl = TextEditingController();

  PlatformFile? archivoAudio;
  PlatformFile? archivoPortada;
  bool subiendo = false;

  final String githubToken = "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";
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

      String pathAudio = "lib/audios/$nombreLimpio.mp3";
      await enviarArchivoGithub(pathAudio, archivoAudio!.bytes!);

      String urlPortada =
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/default.png";
      if (archivoPortada != null) {
        String ext = archivoPortada!.extension ?? "jpg";
        String pathPortada = "lib/portadas/$nombreLimpio.$ext";
        await enviarArchivoGithub(pathPortada, archivoPortada!.bytes!);
        urlPortada =
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/$nombreLimpio.$ext";
      }

      await actualizarJsonGithub(urlPortada, nombreLimpio);

      if (mounted) Navigator.pop(context);
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
    if (getRes.statusCode == 200) {
      sha = jsonDecode(getRes.body)['sha'];
    }

    String base64File = base64Encode(bytes);

    var body = {"message": "Subida de archivo: $path", "content": base64File};
    if (sha != null) {
      body["sha"] = sha;
    }

    var res = await http.put(
      url,
      headers: {
        "Authorization": "token $githubToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("Fallo al subir $path: ${res.body}");
    }
  }

  Future<void> actualizarJsonGithub(
    String urlPortada,
    String nombreLimpio,
  ) async {
    String pathJson = "lib/lista_audios.json";
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/$pathJson",
    );

    var resGet = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    if (resGet.statusCode != 200) throw Exception("No se pudo leer el JSON");

    var data = jsonDecode(resGet.body);
    String sha = data['sha'];

    String rawContent = data['content'].replaceAll('\n', '');
    List content = jsonDecode(utf8.decode(base64.decode(rawContent)));

    content.add({
      "titulo": tituloCtrl.text.trim(),
      "categoria": categoriaCtrl.text.trim(),
      "curso": cursoCtrl.text.trim(),
      "youtube": youtubeCtrl.text.trim(),
      "imagen": urlPortada,
      "url":
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nombreLimpio.mp3",
    });

    var resPut = await http.put(
      url,
      headers: {"Authorization": "token $githubToken"},
      body: jsonEncode({
        "message": "Update lista_audios.json",
        "content": base64Encode(utf8.encode(jsonEncode(content))),
        "sha": sha,
      }),
    );

    if (resPut.statusCode != 200)
      throw Exception("Error al actualizar lista_audios.json");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Nuevo Programa"),
        backgroundColor: Colors.orange,
      ),
      body: subiendo
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 20),
                  Text("Subiendo a GitHub..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: tituloCtrl,
                    decoration: InputDecoration(
                      labelText: "Nombre del programa",
                    ),
                  ),
                  TextField(
                    controller: categoriaCtrl,
                    decoration: InputDecoration(labelText: "Categoría"),
                  ),
                  TextField(
                    controller: cursoCtrl,
                    decoration: InputDecoration(labelText: "Curso (ej: 25/26)"),
                  ),
                  TextField(
                    controller: youtubeCtrl,
                    decoration: InputDecoration(labelText: "Link de YouTube"),
                  ),
                  SizedBox(height: 20),
                  ListTile(
                    tileColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(archivoAudio?.name ?? "Seleccionar MP3"),
                    trailing: Icon(Icons.audio_file, color: Colors.orange),
                    onTap: seleccionarAudio,
                  ),
                  SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(
                      archivoPortada?.name ?? "Seleccionar Portada (Opcional)",
                    ),
                    trailing: Icon(Icons.image, color: Colors.orange),
                    onTap: seleccionarPortada,
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: subirAGithub,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Confirmar y subir a GitHub",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
