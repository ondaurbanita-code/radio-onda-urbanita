import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../widgets/curso_input_formatter.dart';
import '../config/secrets.dart';

class AdminUploadScreen extends StatefulWidget {
  final Map?
  programaAEditar; // si pasamos datos entra en modo edicion, si es null entra en modo creacion

  const AdminUploadScreen({super.key, this.programaAEditar});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _formKey =
      GlobalKey<
        FormState
      >(); // clave global para validar todos los campos del formulario a la vez

  // controladores para capturar los datos de texto de los campos del podcast
  final tituloCtrl = TextEditingController();
  final categoriaCtrl = TextEditingController();
  final colabCtrl = TextEditingController();
  final youtubeCtrl = TextEditingController();
  final cursoCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // variables para almacenar de forma temporal los archivos binarios seleccionados
  PlatformFile? archivoAudio;
  PlatformFile? archivoPortada;
  bool subiendo =
      false; // booleano para alternar entre la vista del formulario y la pantalla de progreso
  String mensajeEstado =
      ""; // texto dinamico que informa que paso de la subida se esta ejecutando
  double valorProgreso = 0.0; // valor decimal para controlar la barra de carga

  // traemos las credenciales desde la clase secreta externa para la api de github
  final String githubToken = Secrets.githubToken;
  final String repoOwner = "ondaurbanita-code";
  final String repoName = "radio-onda-urbanita";

  @override
  void initState() {
    super.initState();
    // si el objeto mapa contiene datos, autorrellenamos los controladores para editar
    if (widget.programaAEditar != null) {
      tituloCtrl.text = widget.programaAEditar!['titulo'] ?? "";
      categoriaCtrl.text = widget.programaAEditar!['categoria'] ?? "";
      colabCtrl.text = widget.programaAEditar!['colaboradores'] ?? "";
      cursoCtrl.text = widget.programaAEditar!['curso'] ?? "";
      youtubeCtrl.text = widget.programaAEditar!['youtube'] ?? "";
      descCtrl.text = widget.programaAEditar!['descripcion'] ?? "";
    }
  }

  // metodo asincrono para abrir el explorador de archivos y elegir el audio mp3
  Future<void> seleccionarAudio() async {
    var res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData:
          true, // con esto leemos los bytes directos en memoria para subirlos
    );
    if (res != null) setState(() => archivoAudio = res.files.first);
  }

  // metodo asincrono para abrir el explorador y elegir la imagen de la caratula
  Future<void> seleccionarPortada() async {
    var res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res != null) setState(() => archivoPortada = res.files.first);
  }

  // funcion auxiliar rapida para refrescar la interfaz con el estado actual de la subida
  void actualizarProgreso(double destino, String mensaje) {
    setState(() {
      mensajeEstado = mensaje;
      valorProgreso = destino;
    });
  }

  // conecta con google api usando la cuenta de servicio local para enviar notificaciones push fcm v1
  Future<void> enviarNotificacion(String titulo) async {
    try {
      // paso 1: cargamos el json fisico de la cuenta de servicio desde la carpeta assets
      final jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/service-account.json');
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(
        jsonString,
      );
      // paso 2: definimos el alcance (scope) requerido para mensajeria de firebase
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      // paso 3: creamos el cliente autenticado autenticandonos contra los servidores de google
      final client = await auth.clientViaServiceAccount(
        accountCredentials,
        scopes,
      );

      // estructuramos el cuerpo del payload de la notificacion push asignandola al topico global
      final body = {
        'message': {
          'topic': 'anuncios_radio',
          'notification': {
            'title': '¡Nuevo programa disponible!',
            'body': 'Ya puedes escuchar: $titulo',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              'channel_id': 'radio_notifications',
              // debe coincidir con el del main
            },
          },
        },
      };

      // lanzamos la peticion post definitiva usando la api http rest v1 de firebase
      await client.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/ondaurbanita-radio/messages:send',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      client
          .close(); // cerramos el cliente de google para no consumir memoria ram
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // orquestador principal que ejecuta la subida de binarios y actualiza la base de datos json
  Future<void> subirAGithub() async {
    if (widget.programaAEditar == null && archivoAudio == null) return;

    setState(() => subiendo = true);
    try {
      // reemplazamos espacios por guiones bajos para que el nombre de los archivos no de problemas de rutas
      String nombreLimpio = tituloCtrl.text.trim().replaceAll(' ', '_');
      actualizarProgreso(0.2, "Procesando archivos...");

      // paso 1: si se seleccionó un audio nuevo, lo mandamos al repositorio
      if (archivoAudio != null) {
        await enviarArchivoGithub(
          "lib/audios/$nombreLimpio.mp3",
          archivoAudio!.bytes!,
        );
      }

      // por defecto asignamos la ruta de la imagen actual o la caratula base del colegio
      String urlPortada =
          widget.programaAEditar?['imagen'] ??
          "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/logo.png";

      // paso 2: si se seleccionó una caratula nueva, la subimos y actualizamos la url
      if (archivoPortada != null) {
        String ext = archivoPortada!.extension ?? "jpg";
        await enviarArchivoGithub(
          "lib/portadas/$nombreLimpio.$ext",
          archivoPortada!.bytes!,
        );
        urlPortada =
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/portadas/$nombreLimpio.$ext";
      }

      actualizarProgreso(0.7, "Actualizando base de datos...");

      // paso 3: preparamos el nuevo mapa con todos los campos limpios mapeados
      Map itemActualizado = {
        "titulo": tituloCtrl.text.trim(),
        "categoria": categoriaCtrl.text.trim(),
        "colaboradores": colabCtrl.text.trim(),
        "curso": cursoCtrl.text.trim(),
        "youtube": youtubeCtrl.text.trim(),
        "descripcion": descCtrl.text.trim(),
        "imagen": urlPortada,
        "url":
            widget.programaAEditar?['url'] ??
            "https://raw.githubusercontent.com/$repoOwner/$repoName/master/lib/audios/$nombreLimpio.mp3",
      };

      // paso 4: insertamos o modificamos la lista dentro del archivo json general en github
      await actualizarJsonGithub(itemActualizado);

      // paso 5: si es un programa totalmente nuevo dispararmos de forma automatica la alerta fcm
      if (widget.programaAEditar == null) {
        await enviarNotificacion(tituloCtrl.text.trim());
      }

      actualizarProgreso(1.0, "¡Listo!");
      await Future.delayed(Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(
          context,
          itemActualizado,
        ); // regresamos al listado pasando el mapa modificado
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() => subiendo = false);
      }
    }
  }

  // sube de forma asincrona un array de bytes binarios hacia el path del repositorio usando put
  Future<void> enviarArchivoGithub(String path, List<int> bytes) async {
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/$path",
    );
    String? sha;
    // primero hacemos un get para comprobar si el archivo ya existe y sacar su sha obligatorio
    var res = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    if (res.statusCode == 200) sha = jsonDecode(res.body)['sha'];

    // ejecutamos el put mandando el payload obligatorio con el contenido convertido en base64
    await http.put(
      url,
      headers: {
        "Authorization": "token $githubToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "message": "Upload $path",
        "content": base64Encode(bytes),
        // conversion a string base64 obligatoria para la api de github
        "sha": sha,
        // si es nulo crea el archivo, si tiene sha lo sobrescribe
      }),
    );
  }

  // descarga la lista json index, la decodifica, muta los datos de los audios y la vuelve a subir
  Future<void> actualizarJsonGithub(Map item) async {
    var url = Uri.parse(
      "https://api.github.com/repos/$repoOwner/$repoName/contents/lib/lista_audios.json",
    );
    var res = await http.get(
      url,
      headers: {"Authorization": "token $githubToken"},
    );
    var data = jsonDecode(res.body);
    // quitamos los saltos de linea antes de decodificar de base64 a string plano de dart
    List content = jsonDecode(
      utf8.decode(base64.decode(data['content'].replaceAll('\n', ''))),
    );

    if (widget.programaAEditar != null) {
      // si estamos editando, buscamos la posicion exacta del audio original por su url identificativa
      int idx = content.indexWhere(
        (e) => e['url'] == widget.programaAEditar!['url'],
      );
      if (idx != -1)
        content[idx] = item; // reemplazamos el mapa viejo por el nuevo
    } else {
      content.add(
        item,
      ); // si es nuevo simplemente lo añadimos al final de la lista
    }

    // subimos el json definitivo convirtiendo el mapa de nuevo a bytes codificados en base64
    await http.put(
      url,
      headers: {"Authorization": "token $githubToken"},
      body: jsonEncode({
        "message": "Update JSON",
        "content": base64Encode(utf8.encode(jsonEncode(content))),
        "sha": data['sha'],
        // pasamos el sha del archivo antiguo para autorizar la mutacion
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.programaAEditar == null ? "Nuevo Programa" : "Editar Programa",
        ),
        backgroundColor: Colors.orange,
      ),
      // operador ternario para pintar la barra de progreso mientras corre el proceso asincrono
      body: subiendo ? _buildProgreso() : _buildFormulario(),
    );
  }

  // widget que dibuja la pantalla de carga porcentual dinamica
  Widget _buildProgreso() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: valorProgreso, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            mensajeEstado,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // widget que pinta el formulario con todos los campos requeridos para la radio
  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        // asignamos la clave para poder disparar las validaciones automaticas
        child: Column(
          children: [
            TextFormField(
              controller: tituloCtrl,
              decoration: InputDecoration(labelText: "Nombre"),
              validator: (v) => v!.isEmpty ? "El nombre es obligatorio" : null,
            ),
            TextFormField(
              controller: colabCtrl,
              decoration: InputDecoration(labelText: "Colaboradores"),
            ),
            TextFormField(
              controller: categoriaCtrl,
              decoration: InputDecoration(labelText: "Categoría"),
            ),
            // campo del curso con formateador de texto automatizado (inputformatter)
            TextFormField(
              controller: cursoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [CursoInputFormatter()],
              // inyectamos el filtro de mascara custom
              decoration: InputDecoration(
                labelText: "Curso (25/26)",
                hintText: "Ej: 24/25",
              ),
              // logica de validacion para impedir años incompletos o fechas del futuro
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Introduce un curso";
                }
                if (value.length >= 2) {
                  int yearEscrito = int.parse(value.substring(0, 2));
                  int yearActual = int.parse(
                    DateTime.now().year.toString().substring(2),
                  );
                  if (yearEscrito > yearActual) {
                    return "Estás intentando poner una fecha futura";
                  }
                }
                if (value.length < 5) {
                  return "Formato incompleto (XX/XX)";
                }
                return null;
              },
            ),
            TextFormField(
              controller: youtubeCtrl,
              decoration: InputDecoration(labelText: "Link YouTube"),
            ),
            TextFormField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: "Descripción"),
            ),
            SizedBox(height: 20),
            // botones de tipo listtile para lanzar de forma comoda el selector de archivos locales
            ListTile(
              leading: Icon(Icons.audio_file, color: Colors.orange),
              title: Text(
                archivoAudio?.name ??
                    (widget.programaAEditar != null
                        ? "Audio ya subido"
                        : "Seleccionar MP3"),
              ),
              onTap: seleccionarAudio,
            ),
            ListTile(
              leading: Icon(Icons.image, color: Colors.blue),
              title: Text(archivoPortada?.name ?? "Cambiar Portada (Opcional)"),
              onTap: seleccionarPortada,
            ),
            SizedBox(height: 30),
            // boton de confirmacion final que valida todo el formulario antes de llamar al backend
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    subirAGithub(); // solo dispara el proceso si las cajas pasan los validadores
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(
                  widget.programaAEditar == null
                      ? "PUBLICAR"
                      : "GUARDAR CAMBIOS",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
