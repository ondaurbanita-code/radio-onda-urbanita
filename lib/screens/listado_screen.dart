import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_screen.dart';
import 'login_screen.dart';

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
  Future<bool> _estaTerminado(String titulo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('terminado_$titulo') ?? false;
  }

  Future<List> _obtenerAudios() async {
    var url = Uri.parse(
      "https://raw.githubusercontent.com/ondaurbanita-code/radio-onda-urbanita/refs/heads/master/lib/lista_audios.json",
    );
    var respuesta = await http.get(url);
    if (respuesta.statusCode == 200) return jsonDecode(respuesta.body);
    return [];
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            ),
            child: Text(
              "¿A qué espera? Inicie sesión",
              style: TextStyle(color: Colors.orange[800], fontSize: 12),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List>(
        future: _obtenerAudios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          if (snapshot.hasError || !snapshot.hasData)
            return Center(child: Text("Error al cargar"));

          var audios = snapshot.data!;
          String cursoHoy = obtenerCursoActual();
          Map<String, List> grupos = {};

          for (var audio in audios) {
            String c = audio['curso'] ?? "24/25";
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
                              if (res.data == true)
                                return Image.asset(
                                  'assets/logo.png',
                                  height: 25,
                                );
                              return Icon(Icons.arrow_forward_ios, size: 12);
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
