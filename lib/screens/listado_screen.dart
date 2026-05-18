import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/custom_drawer.dart';
import '../config/secrets.dart';
import 'player_screen.dart';
import 'admin_upload_screen.dart';

class ListadoScreen extends StatefulWidget {
  const ListadoScreen({super.key});

  @override
  State<ListadoScreen> createState() => _ListadoScreenState();
}

class _ListadoScreenState extends State<ListadoScreen> {
  // traemos las credenciales guardadas en la clase secreta para conectar con github
  final String githubToken = Secrets.githubToken;
  final String repoOwner = "ondaurbanita-code";
  final String repoName = "radio-onda-urbanita";

  // variables de estado para almacenar los audios descargados y el control de la ui
  List? _audiosLocales;
  bool _cargando = true;
  String?
  _urlBorrando; // almacena la url del audio que se esta eliminando para bloquear su tarjeta
  List<String> _escuchados =
      []; // lista de id de audios que el usuario ya ha terminado
  String? _rol;
  String? _nombre;
  String?
  _cursoMasReciente; // guarda el curso academico mas alto para expandirlo por defecto

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // cargamos toda la informacion necesaria de golpe al iniciar la pantalla
  Future<void> _cargarDatos() async {
    await _cargarInfoUsuario();
    await _cargarEscuchadosFirebase();
    await _inicializarLista();
  }

  // lee el rol y el nombre del usuario logueado desde su documento de firestore
  Future<void> _cargarInfoUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();
    if (mounted && doc.exists) {
      setState(() {
        _rol = doc.data()?['rol'];
        _nombre = doc.data()?['nombre'];
      });
    }
  }

  // descarga la coleccion de programas terminados para poder pintarle el tick verde al usuario
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

  // descarga el archivo json crudo de github con el timestamp para evitar la cache del navegador
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
            // extraemos los años de los cursos, los ordenamos de mayor a menor y elegimos el primero
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

  // funcion tecnica para borrar binarios mp3 o imagenes directamente del repositorio mediante la api v3
  Future<void> _borrarArchivoFisico(String urlCompleta) async {
    try {
      String path = urlCompleta.split('/master/').last;
      var urlApi = Uri.parse(
        "https://api.github.com/repos/$repoOwner/$repoName/contents/$path",
      );
      // paso 1: pedimos el archivo para obtener su codigo identificador sha obligatorio
      var res = await http.get(
        urlApi,
        headers: {"Authorization": "token $githubToken"},
      );
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        // paso 2: mandamos la peticion delete pasandole el token y el sha obtenido
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
      print(e);
    }
  }

  // proceso principal para borrar un programa de todos los servidores (cascada manual)
  Future<void> eliminarPrograma(Map audio) async {
    // mostramos un dialogo de confirmacion preventivo
    bool? confirmar = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("¿Eliminar programa?"),
        content: Text(
          "Se borrará de GitHub y el historial de TODOS los usuarios en Firebase. Esta acción es irreversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text("Sí, borrar todo", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _urlBorrando = audio['url']);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Eliminando '${audio['titulo']}'..."),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // paso 1: buscamos y borramos los registros de progreso de este audio en todos los usuarios usando collectiongroup
      var registrosFirebase = await FirebaseFirestore.instance
          .collectionGroup('progreso')
          .where('titulo', isEqualTo: audio['titulo'])
          .where('terminado', whereIn: [true, false])
          .get();

      if (registrosFirebase.docs.isNotEmpty) {
        // usamos un lote (batch) para borrar todas las referencias de firebase de golpe de forma segura
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in registrosFirebase.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // paso 2: borramos el archivo mp3 fisico del storage de github
      await _borrarArchivoFisico(audio['url']);
      // borramos tambien la caratula si no es el logotipo por defecto del centro escolar
      if (audio['imagen'] != null && !audio['imagen'].contains('logo.png')) {
        await _borrarArchivoFisico(audio['imagen']);
      }

      // paso 3: descargamos, decodificamos de base64, modificamos y resubimos el archivo index lista_audios.json
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

        // localizamos la posicion del objeto mapa dentro del array json
        int idx = content.indexWhere(
          (e) => e['url'] == audio['url'] && e['titulo'] == audio['titulo'],
        );

        if (idx != -1) {
          content.removeAt(idx); // lo sacamos de la lista
          // hacemos el put definitivo mandando el nuevo json codificado de nuevo en base64
          await http.put(
            urlJson,
            headers: {"Authorization": "token $githubToken"},
            body: jsonEncode({
              "message": "Delete total: ${audio['titulo']}",
              "content": base64Encode(utf8.encode(jsonEncode(content))),
              "sha": dataJson['sha'],
              // sha del json antiguo obligatorio para modificarlo
            }),
          );
        }
      }

      // refrescamos la lista de la pantalla volviendo a descargar el json actualizado
      await _inicializarLista();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Programa eliminado correctamente"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al borrar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _urlBorrando = null,
        ); // liberamos el bloqueo de la interfaz
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _rol == 'admin' || _rol == 'superadmin';
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawer(rol: _rol, nombre: _nombre),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Programas",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          // si es administrador, le mostramos el acceso directo para saltar a subir un programa nuevo
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.orange),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => AdminUploadScreen()),
                );
                _inicializarLista(); // actualiza la lista al volver por si ha subido algo
              },
            ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : _buildLista(isAdmin),
    );
  }

  // construye la lista agrupando los podcasts dinamicamente por la clave de su curso academico
  Widget _buildLista(bool isAdmin) {
    Map<String, List> grupos = {};
    for (var a in _audiosLocales!) {
      String c = a['curso'] ?? "24/25";
      if (!grupos.containsKey(c)) grupos[c] = [];
      grupos[c]!.add(a);
    }
    // ordenamos las pestañas desplegables para que los cursos mas nuevos salgan arriba del todo
    List<String> cursos = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.all(10),
      itemCount: cursos.length,
      itemBuilder: (c, i) {
        String curso = cursos[i];
        return ExpansionTile(
          initiallyExpanded: curso == _cursoMasReciente,
          // despliega de forma automatica solo el curso actual
          title: Text(
            "Curso $curso",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          children: grupos[curso]!.map((audio) {
            // comprobamos si este audio especifico ya esta marcado en el array de escuchados
            bool escuchado =
                _escuchados.contains("${audio['titulo']}-${audio['url']}") ||
                _escuchados.contains(audio['titulo']);
            String? youtubeUrl = audio['youtube'];
            bool estaBorrando = _urlBorrando == audio['url'];

            return ClipRect(
              child: Stack(
                children: [
                  // bloqueamos las pulsaciones y bajamos la opacidad de la celda si el programa se esta eliminando
                  IgnorePointer(
                    ignoring: estaBorrando,
                    child: Opacity(
                      opacity: estaBorrando ? 0.4 : 1.0,
                      child: ListTile(
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
                            // si el mapa contiene enlace de video, pintamos el boton de youtube de color rojo
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
                            // si es admin le pintamos los indicadores visuales de edicion y borrado masivo
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
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                        onTap: () async {
                          // abrimos el reproductor pasandole la lista del bloque actual y la posicion elegida
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => PlayerScreen(
                                listaAudios: grupos[curso]!,
                                indiceInicial: grupos[curso]!.indexOf(audio),
                              ),
                            ),
                          );
                          // al regresar refrescamos los ticks verdes por si ha terminado de oir algun podcast
                          await _cargarEscuchadosFirebase();
                        },
                        // modo atajo exclusivo para administradores: editar manteniendo pulsada la tarjeta
                        onLongPress: isAdmin
                            ? () async {
                                Map? nuevoMapa = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => AdminUploadScreen(
                                      programaAEditar: audio,
                                    ),
                                  ),
                                );
                                if (nuevoMapa != null) {
                                  setState(() {
                                    int idx = _audiosLocales!.indexWhere(
                                      (e) => e['url'] == audio['url'],
                                    );
                                    if (idx != -1)
                                      _audiosLocales![idx] = nuevoMapa;
                                  });
                                  _inicializarLista();
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                  // capa visual superpuesta (backdropfilter) para emborronar la tarjeta mientras corre el borrado
                  if (estaBorrando)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(
                          color: Colors.white.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.orange,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}