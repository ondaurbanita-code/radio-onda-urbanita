import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_screen.dart';

class ListadoScreen extends StatefulWidget {
  const ListadoScreen({super.key});

  @override
  State<ListadoScreen> createState() => _ListadoScreenState();
}

class _ListadoScreenState extends State<ListadoScreen> {
  Map<String, bool> audiosCompletados = {};

  @override
  void initState() {
    super.initState();
    _cargarEstadosCompletados();
  }

  Future<void> _cargarEstadosCompletados() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {});
  }

  Future<bool> _estaTerminado(String titulo) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('terminado_$titulo') ?? false;
  }

  Future<List> _obtenerAudios() async {
    var url = Uri.parse(
      "https://raw.githubusercontent.com/ondaurbanita-code/radio-onda-urbanita/refs/heads/master/lib/lista_audios.json",
    );
    var respuesta = await http.get(url);
    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Programas"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List>(
        future: _obtenerAudios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("error al cargar programas"));
          }

          var audios = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: audios.length,
            itemBuilder: (context, i) {
              String titulo = audios[i]['titulo'];

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: const Icon(
                    Icons.mic,
                    color: Colors.orange,
                    size: 30,
                  ),
                  title: Text(
                    titulo,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(audios[i]['categoria']),
                  trailing: FutureBuilder<bool>(
                    future: _estaTerminado(titulo),
                    builder: (context, res) {
                      if (res.data == true) {
                        return Image.asset(
                          'LOGO_ONDA_URBANITA.png',
                          height: 60,
                        );
                      }
                      return Icon(
                        Icons.arrow_forward_ios,
                        size: 15,
                        color: Colors.grey,
                      );
                    },
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayerScreen(
                          urlAudio: audios[i]['url'],
                          titulo: titulo,
                        ),
                      ),
                    );
                    setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
