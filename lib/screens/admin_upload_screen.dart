import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

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

      actualizarProgreso(0.1, "Conectando con GitHub...");
      await Future.delayed(Duration(milliseconds: 500));

      actualizarProgreso(0.2, "Subiendo audio...");
      String pathAudio = "lib/audios/$nombreLimpio.mp3";
      await enviarArchivoGithub(pathAudio, archivoAudio!.bytes!);
      actualizarProgreso(0.5, "Audio subido correctamente");

      String urlPortada =
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/default.png";

      if (archivoPortada != null) {
        actualizarProgreso(0.6, "Subiendo imagen de portada...");
        String ext = archivoPortada!.extension ?? "jpg";
        String pathPortada = "lib/portadas/$nombreLimpio.$ext";
        await enviarArchivoGithub(pathPortada, archivoPortada!.bytes!);
        urlPortada =
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/$nombreLimpio.$ext";
        actualizarProgreso(0.8, "Portada subida");
      }

      actualizarProgreso(0.9, "Actualizando lista de programas...");
      await actualizarJsonGithub(urlPortada, nombreLimpio);

      actualizarProgreso(1.0, "¡Publicado con éxito!");

      final nuevoPrograma = {
        "titulo": tituloCtrl.text.trim(),
        "categoria": categoriaCtrl.text.trim(),
        "curso": cursoCtrl.text.trim(),
        "youtube": youtubeCtrl.text.trim(),
        "imagen": urlPortada,
        "url":
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nombreLimpio.mp3",
      };

      await Future.delayed(Duration(seconds: 1));
      if (mounted) Navigator.pop(context, nuevoPrograma);
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

    String base64File = base64Encode(bytes);
    var body = {"message": "Upload $path", "content": base64File};
    if (sha != null) body["sha"] = sha;

    await http.put(
      url,
      headers: {
        "Authorization": "token $githubToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
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
    var data = jsonDecode(resGet.body);
    List content = jsonDecode(
      utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))),
    );

    content.add({
      "titulo": tituloCtrl.text.trim(),
      "categoria": categoriaCtrl.text.trim(),
      "curso": cursoCtrl.text.trim(),
      "youtube": youtubeCtrl.text.trim(),
      "imagen": urlPortada,
      "url":
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nombreLimpio.mp3",
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
      body: subiendo
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mensajeEstado,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(begin: 0, end: valorProgreso),
                      builder: (context, value, _) => Column(
                        children: [
                          LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.grey[200],
                            color: Colors.orange,
                            minHeight: 12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "${(value * 100).toInt()}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    decoration: InputDecoration(
                      labelText: "Curso (ej: 25/26)",
                    ),
                  ),
                  TextField(
                    controller: youtubeCtrl,
                    decoration: InputDecoration(
                      labelText: "Link de YouTube",
                    ),
                  ),
                  SizedBox(height: 20),
                  ListTile(
                    tileColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(archivoAudio?.name ?? "Seleccionar MP3"),
                    trailing: Icon(
                      Icons.audio_file,
                      color: Colors.orange,
                    ),
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
