import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'player_screen.dart';

class ListadoScreen extends StatelessWidget {
  const ListadoScreen({super.key});

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
            return Center(child: Text("error al cargar programas"));
          }

          var audios = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.all(20),
            itemCount: audios.length,
            itemBuilder: (context, i) {
              return Card(
                margin: EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: Icon(Icons.mic, color: Colors.orange),
                  title: Text(audios[i]['titulo']),
                  subtitle: Text(audios[i]['categoria']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayerScreen(
                          urlAudio: audios[i]['url'],
                          titulo: audios[i]['titulo'],
                        ),
                      ),
                    );
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
