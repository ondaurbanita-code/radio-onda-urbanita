import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarEscuchados();
    _inicializarLista();
  }

  Future<void> _cargarEscuchados() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _escuchados = prefs.getStringList('podcasts_vistos') ?? [];
    });
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
        }
        _cargando = false;
      });
    }
  }

  Future<void> _abrirYoutube(String url) async {
    if (url.isEmpty) return;

    final uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("no se pudo abrir el enlace: $e");
    }
  }

  Future<void> _borrarArchivoFisico(String urlApi) async {
    var url = Uri.parse(urlApi);
    var resGet = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    if (resGet.statusCode == 200) {
      var sha = jsonDecode(resGet.body)['sha'];
      await http.delete(
        url,
        headers: {"Authorization": "token $githubToken"},
        body: jsonEncode({"message": "Delete file", "sha": sha}),
      );
    }
  }

  Future<void> eliminarPrograma(Map audio) async {
    final prefs = await SharedPreferences.getInstance();
    String idAudio = audio['url'];

    _escuchados.remove(idAudio);
    await prefs.setStringList('podcasts_vistos', _escuchados);
    await prefs.remove('posicion_$idAudio');

    setState(() {
      _audiosLocales?.removeWhere(
        (item) =>
            item['titulo'] == audio['titulo'] && item['url'] == audio['url'],
      );
    });

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
            "message": "Eliminar ${audio['titulo']}",
            "content": base64Encode(utf8.encode(jsonEncode(content))),
            "sha": data['sha'],
          }),
        );
      }

      String nombreMp3 = audio['url'].split('/').last;
      await _borrarArchivoFisico(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/audios/$nombreMp3",
      );

      if (audio['imagen'] != null && !audio['imagen'].contains('default.png')) {
        String nombreImg = audio['imagen'].split('/').last;
        await _borrarArchivoFisico(
          "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/portadas/$nombreImg",
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Programa eliminado")));
    } catch (e) {
      _inicializarLista();
    }
  }

  void _confirmarEliminacion(Map audio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("¿Eliminar programa?"),
        content: Text(
          "Se borrará de GitHub y se limpiará tu progreso de este audio.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              eliminarPrograma(audio);
            },
            child: Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Programas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        actions: [
          if (user?.email == "ondaurbanita@gmail.com")
            IconButton(
              icon: Icon(Icons.add, color: Colors.orange),
              onPressed: () async {
                final nuevo = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminUploadScreen()),
                );
                if (nuevo != null) setState(() => _audiosLocales?.add(nuevo));
              },
            ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: _inicializarLista,
              child: _audiosLocales == null || _audiosLocales!.isEmpty
                  ? ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Text("No hay programas"),
                          ),
                        ),
                      ],
                    )
                  : _construirLista(user),
            ),
    );
  }

  Widget _construirLista(User? user) {
    Map<String, List> grupos = {};
    for (var audio in _audiosLocales!) {
      String c = audio['curso'] ?? "24/25";
      if (!grupos.containsKey(c)) grupos[c] = [];
      grupos[c]!.add(audio);
    }

    List<String> nombresCursos = grupos.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    String cursoActual = nombresCursos.isNotEmpty ? nombresCursos.first : "";

    return ListView.builder(
      padding: EdgeInsets.all(15),
      itemCount: nombresCursos.length,
      itemBuilder: (context, index) {
        String curso = nombresCursos[index];
        return ExpansionTile(
          initiallyExpanded: curso == cursoActual,
          title: Text(
            "Curso $curso",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange[900],
            ),
          ),
          children: grupos[curso]!.map((audio) {
            bool visto = _escuchados.contains(audio['url']);
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: visto
                    ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : null,
                title: Text(
                  audio['titulo'],
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (audio['youtube'] != null &&
                        audio['youtube'].toString().isNotEmpty)
                      IconButton(
                        icon: Icon(
                          FontAwesomeIcons.youtube,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _abrirYoutube(audio['youtube']),
                      ),
                    if (user?.email == "ondaurbanita@gmail.com")
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _confirmarEliminacion(audio),
                      ),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(
                        listaAudios: grupos[curso]!,
                        indiceInicial: grupos[curso]!.indexOf(audio),
                      ),
                    ),
                  );
                  _cargarEscuchados();
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}