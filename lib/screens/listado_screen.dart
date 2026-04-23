import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    var doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();
    if (mounted && doc.exists) setState(() => _rol = doc.data()?['rol']);
  }

  Future<void> _cargarEscuchadosFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('progreso')
        .where('terminado', isEqualTo: true)
        .get();

    if (mounted) {
      setState(() {
        _escuchados = snap.docs.map((doc) {
          var data = doc.data();
          if (data.containsKey('titulo') && data.containsKey('url_id')) {
            return "${data['titulo']}-${data['url_id']}";
          }
          return doc.id.replaceAll('_', ' ');
        }).toList();
      });
    }
  }

  Future<void> _inicializarLista() async {
    var url = Uri.parse(
      "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/lista_audios.json?t=${DateTime.now().millisecondsSinceEpoch}",
    );
    var res = await http.get(url);
    if (mounted) {
      setState(() {
        if (res.statusCode == 200) {
          _audiosLocales = jsonDecode(res.body);
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

  Future<void> _borrarArchivoFisico(String urlCompleta) async {
    try {
      String path = urlCompleta.split('/master/').last;
      var urlApi = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/$path",
      );
      var res = await http.get(
        urlApi,
        headers: {"Authorization": "token $githubToken"},
      );
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        await http.delete(
          urlApi,
          headers: {"Authorization": "token $githubToken"},
          body: jsonEncode({
            "message": "Delete physical file: $path",
            "sha": data['sha'],
          }),
        );
      }
    } catch (e) {
      print("error borrando archivo fisico: $e");
    }
  }

  Future<void> eliminarPrograma(Map audio) async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("¿Eliminar programa?"),
        content: Text("Se borrará el registro y sus archivos físicos."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text("Sí", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cargando = true);
    try {
      await _borrarArchivoFisico(audio['url']);
      if (audio['imagen'] != null && !audio['imagen'].contains('logo.png')) {
        await _borrarArchivoFisico(audio['imagen']);
      }

      var urlJson = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/lista_audios.json",
      );
      var resJson = await http.get(
        urlJson,
        headers: {"Authorization": "token $githubToken"},
      );

      if (resJson.statusCode == 200) {
        var dataJson = jsonDecode(resJson.body);
        List content = jsonDecode(
          utf8.decode(base64.decode(dataJson['content'].replaceAll('\n', ''))),
        );
        int idx = content.indexWhere(
          (e) =>
              e['url'] == audio['url'] &&
              e['curso'] == audio['curso'] &&
              e['titulo'] == audio['titulo'],
        );

        if (idx != -1) {
          content.removeAt(idx);
          await http.put(
            urlJson,
            headers: {"Authorization": "token $githubToken"},
            body: jsonEncode({
              "message": "Delete: ${audio['titulo']}",
              "content": base64Encode(utf8.encode(jsonEncode(content))),
              "sha": dataJson['sha'],
            }),
          );
        }
      }
      await _inicializarLista();
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _rol == 'admin' || _rol == 'superadmin';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Programas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (isAdmin)
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
          : _buildLista(isAdmin),
    );
  }

  Widget _buildLista(bool isAdmin) {
    Map<String, List> grupos = {};
    for (var a in _audiosLocales!) {
      String c = a['curso'] ?? "24/25";
      if (!grupos.containsKey(c)) grupos[c] = [];
      grupos[c]!.add(a);
    }
    List<String> cursos = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.all(10),
      itemCount: cursos.length,
      itemBuilder: (c, i) {
        String curso = cursos[i];
        return ExpansionTile(
          initiallyExpanded: curso == _cursoMasReciente,
          title: Text(
            "Curso $curso",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          children: grupos[curso]!.map((audio) {
            bool escuchado =
                _escuchados.contains("${audio['titulo']}-${audio['url']}") ||
                _escuchados.contains(audio['titulo']);
            String? youtubeUrl = audio['youtube'];

            return ListTile(
              leading: Icon(
                escuchado ? Icons.check_circle : Icons.radio,
                color: escuchado ? Colors.green : Colors.grey[400],
              ),
              title: Text(
                audio['titulo'],
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                audio['descripcion'] ?? audio['categoria'] ?? "Radio",
                maxLines: 1,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (youtubeUrl != null && youtubeUrl.isNotEmpty)
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.youtube,
                        color: Color(0xFFFF0000),
                        size: 20,
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(youtubeUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  if (isAdmin) ...[
                    Icon(
                      Icons.edit_note,
                      size: 18,
                      color: Colors.orange.withOpacity(0.6),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: Colors.red[300],
                        size: 20,
                      ),
                      onPressed: () => eliminarPrograma(audio),
                    ),
                  ] else if (youtubeUrl == null || youtubeUrl.isEmpty)
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => PlayerScreen(
                      listaAudios: grupos[curso]!,
                      indiceInicial: grupos[curso]!.indexOf(audio),
                    ),
                  ),
                );
                await _cargarEscuchadosFirebase();
              },
              onLongPress: isAdmin
                  ? () async {
                      Map? nuevoMapa = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) =>
                              AdminUploadScreen(programaAEditar: audio),
                        ),
                      );
                      if (nuevoMapa != null) {
                        setState(() {
                          int idx = _audiosLocales!.indexWhere(
                            (e) => e['url'] == audio['url'],
                          );
                          if (idx != -1) _audiosLocales![idx] = nuevoMapa;
                        });
                        _inicializarLista();
                      }
                    }
                  : null,
            );
          }).toList(),
        );
      },
    );
  }
}