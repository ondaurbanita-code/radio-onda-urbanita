import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/secrets.dart';
import 'player_screen.dart';
import 'admin_upload_screen.dart';

class ListadoScreen extends StatefulWidget {
  const ListadoScreen({super.key});

  @override
  State<ListadoScreen> createState() => _ListadoScreenState();
}

class _ListadoScreenState extends State<ListadoScreen> {
  final String githubToken = Secrets.githubToken;
  final String repoOwner = "ondaurbanita-code";
  final String repoName = "radio-onda-urbanita";

  List? _audiosLocales;
  bool _cargando = true;
  List<String> _escuchados = [];
  String? _rol;
  String? _cursoMasReciente;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await _cargarRol();
    await _cargarEscuchadosFirebase();
    await _inicializarLista();
  }

  Future<void> _cargarRol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (mounted && snapshot.docs.isNotEmpty) {
        setState(() => _rol = snapshot.docs.first.data()['rol']);
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _cargarEscuchadosFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('progreso')
        .where('terminado', isEqualTo: true)
        .get();
    if (mounted) {
      setState(
        () => _escuchados = snapshot.docs
            .map((doc) => doc.data()['url_id'] as String)
            .toList(),
      );
    }
  }

  Future<void> _inicializarLista() async {
    var url = Uri.parse(
      "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/lista_audios.json?t=${DateTime.now().millisecondsSinceEpoch}",
    );
    var respuesta = await http.get(url);
    if (mounted) {
      setState(() {
        if (respuesta.statusCode == 200) {
          _audiosLocales = jsonDecode(respuesta.body);
          if (_audiosLocales != null && _audiosLocales!.isNotEmpty) {
            List<String> cursos = _audiosLocales!
                .map((a) => (a['curso'] as String?) ?? "24/25")
                .toList();
            cursos.sort((a, b) => b.compareTo(a));
            _cursoMasReciente = cursos.first;
          }
        }
        _cargando = false;
      });
    }
  }

  Future<void> eliminarPrograma(Map audio) async {
    setState(
      () => _audiosLocales?.removeWhere(
        (item) =>
            item['titulo'] == audio['titulo'] && item['url'] == audio['url'],
      ),
    );
    try {
      String pathJson = "lib/lista_audios.json";
      var urlJson = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/$pathJson",
      );
      var resGet = await http.get(
        urlJson,
        headers: {"Authorization": "token $githubToken"},
      );
      if (resGet.statusCode == 200) {
        var data = jsonDecode(resGet.body);
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
            "message": "Eliminar",
            "content": base64Encode(utf8.encode(jsonEncode(content))),
            "sha": data['sha'],
          }),
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Programa eliminado")));
    } catch (e) {
      _inicializarLista();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool tienePermisos = _rol == 'admin' || _rol == 'superadmin';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Programas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if (tienePermisos)
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.orange),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => AdminUploadScreen()),
                );
                _inicializarLista();
              },
            ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : _construirLista(tienePermisos),
    );
  }

  Widget _construirLista(bool tienePermisos) {
    Map<String, List> grupos = {};
    for (var audio in _audiosLocales!) {
      String c = audio['curso'] ?? "24/25";
      if (!grupos.containsKey(c)) grupos[c] = [];
      grupos[c]!.add(audio);
    }
    List<String> nombresCursos = grupos.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.all(10),
      itemCount: nombresCursos.length,
      itemBuilder: (context, index) {
        String curso = nombresCursos[index];
        bool esElMasNuevo = curso == _cursoMasReciente;

        return Card(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: ExpansionTile(
            initiallyExpanded: esElMasNuevo,
            iconColor: Colors.orange,
            textColor: Colors.orange[800],
            title: Text(
              "Curso $curso",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            children: grupos[curso]!
                .map(
                  (audio) => ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    leading: _escuchados.contains(audio['url'])
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : Icon(Icons.radio, color: Colors.grey[400]),
                    title: Text(
                      audio['titulo'],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      audio['categoria'] ?? "Radio",
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: tienePermisos
                        ? IconButton(
                            icon: Icon(
                              Icons.delete_sweep,
                              color: Colors.red[300],
                            ),
                            onPressed: () => eliminarPrograma(audio),
                          )
                        : Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => PlayerScreen(
                          listaAudios: grupos[curso]!,
                          indiceInicial: grupos[curso]!.indexOf(audio),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
