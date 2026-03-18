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
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        centerTitle: true,
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
          return ListView.builder(
            padding: EdgeInsets.all(20),
            itemCount: audios.length,
            itemBuilder: (context, i) {
              String titulo = audios[i]['titulo'];
              return Container(
                margin: EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: Icon(Icons.play_arrow, color: Colors.orange[800]),
                  ),
                  title: Text(
                    titulo,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    audios[i]['categoria'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: FutureBuilder<bool>(
                    future: _estaTerminado(titulo),
                    builder: (context, res) {
                      if (res.data == true) {
                        return Image.asset(
                          'LOGO_ONDA_URBANITA.png',
                          height: 60,
                        );
                      }
                      return Icon(Icons.arrow_forward_ios, size: 14);
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
