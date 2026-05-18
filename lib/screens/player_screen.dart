import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_drawer.dart';

class PlayerScreen extends StatefulWidget {
  final List listaAudios;
  final int indiceInicial;

  const PlayerScreen({
    super.key,
    required this.listaAudios,
    required this.indiceInicial,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // variables del motor de audio y control de tiempos de la cancion
  late AudioPlayer _player;
  late int _indiceActual;
  Duration _posicion = Duration.zero;
  Duration _total = Duration.zero;
  bool _cargando =
      true; // indicador para esperar a que monte el buffer de audio
  String? _rol;
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _indiceActual = widget.indiceInicial;
    _cargarInfoUsuario();

    // stream activo que detecta la posicion del segundo actual y la guarda en firebase
    _player.positionStream.listen((p) {
      if (mounted) {
        setState(() => _posicion = p);
        _guardarProgresoActual(
          p,
        ); // guarda el progreso de forma constante en la nube
      }
    });

    // stream para obtener la duracion maxima del podcast
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _total = d ?? Duration.zero);
    });

    // stream que detecta cuando el audio llega al final del todo de forma automatica
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _registrarProgresoTerminado(
          true,
        ); // lo marca como completado en firebase
      }
    });

    // stream que se entera si cambia de cancion para actualizar el titulo en la pantalla
    _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null) return;
      final index = sequenceState.currentIndex;
      if (mounted && index != _indiceActual) {
        setState(() {
          _indiceActual = index;
        });
      }
    });

    _prepararPlaylist();
  }

  // recupera los datos del perfil por si abrimos el menu lateral desde el reproductor
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

  // empaqueta la lista de reproduccion con los metadatos obligatorios para segundo plano
  Future<void> _prepararPlaylist() async {
    setState(() => _cargando = true);

    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: widget.listaAudios.map((audio) {
        return AudioSource.uri(
          Uri.parse(audio['url']),
          tag: MediaItem(
            id: audio['url'],
            album: "Onda Urbanita",
            title: audio['titulo'],
            artist: audio['colaboradores'] ?? "Radio",
            artUri: Uri.parse(
              audio['imagen'],
            ), // caratula que se vera en la barra del sistema
          ),
        );
      }).toList(),
    );

    try {
      await _player.setAudioSource(playlist, initialIndex: _indiceActual);
      await _player.setLoopMode(
        LoopMode.off,
      ); // desactivamos bucles automaticos

      // control de continuidad de escucha: recuperamos el segundo donde el usuario se quedo
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final audio = widget.listaAudios[_indiceActual];
        // reemplazamos espacios por guiones para que el id del documento de progreso sea limpio
        final tituloDoc = audio['titulo'].toString().replaceAll(' ', '_');
        var doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('progreso')
            .doc(tituloDoc)
            .get();

        // si existe registro previo movemos el puntero del reproductor (seek) a ese segundo
        if (doc.exists && doc.data()?['segundos_actuales'] != null) {
          int seg = doc.data()!['segundos_actuales'];
          await _player.seek(Duration(seconds: seg), index: _indiceActual);
        }
      }

      if (mounted) {
        setState(() => _cargando = false);
        _player.play(); // arranca el play de forma automatica al entrar
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irASiguiente() {
    if (_player.hasNext) {
      _player.seekToNext();
    }
  }

  // funcion para ir atras o reiniciar el audio actual segun el segundo donde este
  void _irAAnterior() {
    if (_player.position.inSeconds >= 2) {
      _player.seek(
        Duration.zero,
      ); // si lleva mas de 2 segundos vuelve al principio del audio
    } else if (_player.hasPrevious) {
      _player
          .seekToPrevious(); // si esta al inicio pasa al podcast anterior de la lista
    }
  }

  // actualiza de forma asincrona la posicion actual de reproduccion en firestore
  Future<void> _guardarProgresoActual(Duration p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _total == Duration.zero || _cargando) return;

    final audio = widget.listaAudios[_indiceActual];
    final tituloDoc = audio['titulo'].toString().replaceAll(' ', '_');
    // si faltan menos de 3 segundos para el final lo marcamos como completado de forma automatica
    bool terminado = (_total.inSeconds - p.inSeconds) <= 3;

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('progreso')
          .doc(tituloDoc)
          .set(
            {
              'titulo': audio['titulo'],
              'url_id': audio['url'],
              'segundos_actuales': p.inSeconds,
              'terminado': terminado,
              'ultimo_acceso': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          ); // el merge es critico para no romper otros campos del perfil
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // fuerza el marcado de terminado al saltar la excepcion de finalizacion del reproductor
  Future<void> _registrarProgresoTerminado(bool terminado) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cargando) return;

    final audio = widget.listaAudios[_indiceActual];
    final String tituloDoc = audio['titulo'].toString().replaceAll(' ', '_');

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('progreso')
          .doc(tituloDoc)
          .set({
            'titulo': audio['titulo'],
            'url_id': audio['url'],
            'terminado': terminado,
            'fecha': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // funcion auxiliar para formatear los milisegundos crudos en texto legible mm:ss
  String _formatearTiempo(Duration duration) {
    String dosDigitos(int n) => n.toString().padLeft(2, "0");
    String minutos = dosDigitos(duration.inMinutes.remainder(60));
    String segundos = dosDigitos(duration.inSeconds.remainder(60));
    return "$minutos:$segundos";
  }

  @override
  void dispose() {
    _player
        .dispose(); // obligatorio apagar el reproductor al salir para liberar la ram del dispositivo
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange[800]),
        ),
      );
    }

    final audio = widget.listaAudios[_indiceActual];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        centerTitle: true,
        title: Text(
          "Reproduciendo",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // caja contenedora con sombreado difuminado para la caratula del programa
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  audio['imagen'],
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey[300],
                    child: Icon(Icons.music_note, size: 100),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
            Text(
              audio['titulo'],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              (audio['colaboradores'] != null &&
                      audio['colaboradores'].toString().isNotEmpty)
                  ? audio['colaboradores']
                  : "Onda Urbanita",
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 30),
            // barra deslizante (slider) estilizada conectada al estado del reproductor
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.orange[700],
                inactiveTrackColor: Colors.orange[100],
                thumbColor: Colors.orange[800],
                trackHeight: 4,
              ),
              child: Slider(
                value: _posicion.inSeconds.toDouble(),
                max: _total.inSeconds.toDouble() > 0
                    ? _total.inSeconds.toDouble()
                    : 1.0,
                onChanged: (v) => _player.seek(
                  Duration(seconds: v.toInt()),
                ), // seek inmediato si el usuario arrastra la barra
              ),
            ),
            // textos informativos para los minutos de reproduccion transcurridos y totales
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatearTiempo(_posicion)),
                  Text(_formatearTiempo(_total)),
                ],
              ),
            ),
            SizedBox(height: 20),
            // botonera de control central con botones redondeados grandes para primaria
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded, size: 45),
                  onPressed:
                      _player.hasPrevious || _player.position.inSeconds >= 2
                      ? () => _irAAnterior()
                      : null, // se desactiva visualmente si no hay pista anterior
                ),
                GestureDetector(
                  onTap: () async {
                    final processingState = _player.processingState;

                    // control de re-reproduccion limpia si el podcast ya habia finalizado
                    if (processingState == ProcessingState.completed) {
                      await _player.stop();
                      await _player.seek(Duration.zero, index: _indiceActual);
                      _player.play();
                    } else {
                      // alterna de forma clasica entre pausar y reproducir
                      if (_player.playing) {
                        await _player.pause();
                      } else {
                        _player.play();
                      }
                    }
                  },
                  // boton de play/pause reactivo conectado directamente al flujo de estado del motor de audio
                  child: StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;
                      final processingState = playerState?.processingState;

                      bool mostrarPlay =
                          !playing ||
                          processingState == ProcessingState.completed;

                      return Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.orange[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          mostrarPlay
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded, size: 45),
                  onPressed: _player.hasNext ? () => _irASiguiente() : null,
                ),
              ],
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}