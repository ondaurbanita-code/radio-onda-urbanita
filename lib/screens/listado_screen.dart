import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/secrets.dart';
import 'player_screen.dart';

String obtenerCursoActual() {
  DateTime ahora = DateTime.now();
  int year = ahora.year;
  if (ahora.month < 9) {
    return "${(year - 1).toString().substring(2)}/${year.toString().substring(2)}";
  } else {
    return "${year.toString().substring(2)}/${(year + 1).toString().substring(2)}";
  }
}

class ListadoScreen extends StatefulWidget {
  const ListadoScreen({super.key});

  @override
  State<ListadoScreen> createState() => _ListadoScreenState();
}

class _ListadoScreenState extends State<ListadoScreen> {
  final String githubToken = Secrets.githubToken;
  final String repoOwner = "ondaurbanita-code";
  final String repoName = "radio-onda-urbanita";

  Future<bool> _estaTerminado(String titulo) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('progreso')
        .doc(titulo)
        .get();

    return doc.exists && (doc.data()?['terminado'] ?? false);
  }

  Future<List> _obtenerAudios() async {
    var url = Uri.parse(
      "https://raw.githubusercontent.com/ondaurbanita-code/radio-onda-urbanita/refs/heads/master/lib/lista_audios.json",
    );
    var respuesta = await http.get(url);
    if (respuesta.statusCode == 200) return jsonDecode(respuesta.body);
    return [];
  }

  Future<void> eliminarPrograma(Map audio) async {
    try {
      String pathJson = "lib/lista_audios.json";
      var urlJson = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/$pathJson",
      );

      var resGet = await http.get(
        urlJson,
        headers: {"Authorization": "token $githubToken"},
      );
      var data = jsonDecode(resGet.body);
      String shaJson = data['sha'];
      List content = jsonDecode(
        utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))),
      );

      content.removeWhere(
        (item) =>
            item['titulo'] == audio['titulo'] && item['url'] == audio['url'],
      );

      await http.put(
        urlJson,
        headers: {"Authorization": "token $githubToken"},
        body: jsonEncode({
          "message": "Eliminar programa: ${audio['titulo']}",
          "content": base64Encode(utf8.encode(jsonEncode(content))),
          "sha": shaJson,
        }),
      );

      String nombreArchivo = audio['url'].split('/').last;
      var urlAudio = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/audios/$nombreArchivo",
      );
      var resAudio = await http.get(
        urlAudio,
        headers: {"Authorization": "token $githubToken"},
      );

      if (resAudio.statusCode == 200) {
        await http.delete(
          urlAudio,
          headers: {"Authorization": "token $githubToken"},
          body: jsonEncode({
            "message": "Borrar archivo audio: $nombreArchivo",
            "sha": jsonDecode(resAudio.body)['sha'],
          }),
        );
      }

      if (audio['imagen'] != null && !audio['imagen'].contains('default.png')) {
        String nombreImg = audio['imagen'].split('/').last;
        var urlImg = Uri.parse(
          "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/portadas/$nombreImg",
        );
        var resImg = await http.get(
          urlImg,
          headers: {"Authorization": "token $githubToken"},
        );

        if (resImg.statusCode == 200) {
          await http.delete(
            urlImg,
            headers: {"Authorization": "token $githubToken"},
            body: jsonEncode({
              "message": "Borrar portada: $nombreImg",
              "sha": jsonDecode(resImg.body)['sha'],
            }),
          );
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint("error al eliminar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Programas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List>(
        future: _obtenerAudios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text("Error al cargar"));
          }

          var audios = snapshot.data!;
          String cursoHoy = obtenerCursoActual();
          Map<String, List> grupos = {};

          for (var audio in audios) {
            String c = audio['curso'] ?? "23/24";
            if (!grupos.containsKey(c)) grupos[c] = [];
            grupos[c]!.add(audio);
          }

          List<String> nombresCursos = grupos.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: EdgeInsets.all(15),
            itemCount: nombresCursos.length,
            itemBuilder: (context, index) {
              String cursoNombre = nombresCursos[index];
              List audiosDelCurso = grupos[cursoNombre]!;

              return ExpansionTile(
                title: Text(
                  "Curso $cursoNombre",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                initiallyExpanded: cursoNombre == cursoHoy,
                children: audiosDelCurso.map((audio) {
                  String titulo = audio['titulo'];
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[50],
                        child: Icon(Icons.play_arrow, color: Colors.orange),
                      ),
                      title: Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.youtube,
                            color: Colors.red,
                            size: 14,
                          ),
                          SizedBox(width: 10),
                          FutureBuilder<bool>(
                            future: _estaTerminado(titulo),
                            builder: (context, res) {
                              if (res.data == true) {
                                return Image.asset(
                                  'assets/logo.png',
                                  height: 25,
                                );
                              }
                              return Icon(
                                Icons.cancel,
                                size: 12,
                                color: Colors.grey,
                              );
                            },
                          ),
                          if (currentUser?.email == "ondaurbanita@gmail.com")
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text("¿Eliminar?"),
                                    content: Text(
                                      "Se borrarán los archivos de GitHub.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text("No"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          eliminarPrograma(audio);
                                        },
                                        child: Text(
                                          "Sí",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayerScreen(
                              listaAudios: audiosDelCurso,
                              indiceInicial: audiosDelCurso.indexOf(audio),
                            ),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
