import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<List> _obtenerAudios() async {
    var url = Uri.parse("https://raw.githubusercontent.com/ondaurbanita-code/radio-onda-urbanita/main/lista_audios.json");
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Icon(Icons.menu, color: Colors.black),
        title: Icon(Icons.star, color: Colors.yellow),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Column(
          children: [
            sectionButton("Quiénes somos", context),
            SizedBox(height: 20),
            sectionButton("Programas de radio", context),
            SizedBox(height: 20),
            sectionButton("Contacto", context),
          ],
        ),
      ),
    );
  }

  Widget sectionButton(String text, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (text == "Programas de radio") {
          _mostrarListaAudios(context);
        }
      },
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _mostrarListaAudios(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FutureBuilder<List>(
          future: _obtenerAudios(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
            var audios = snapshot.data!;
            return ListView.builder(
              itemCount: audios.length,
              itemBuilder: (context, i) {
                return ListTile(
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
                );
              },
            );
          },
        );
      },
    );
  }
}