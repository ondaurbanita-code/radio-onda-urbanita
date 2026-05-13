import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/custom_drawer.dart';

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
  late AudioPlayer _player;
  late int _indiceActual;
  Duration _posicion = Duration.zero;
  Duration _total = Duration.zero;
  bool _cargando = true;
  String? _rol;
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _indiceActual = widget.indiceInicial;
    _cargarInfoUsuario();

    _player.positionStream.listen((p) {
      if (mounted) {
        setState(() => _posicion = p);
        _guardarProgresoActual(p);
      }
    });

    _player.durationStream.listen((d) {
      if (mounted) setState(() => _total = d ?? Duration.zero);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _registrarProgresoTerminado(true);
      }
    });

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
            artUri: Uri.parse(audio['imagen']),
          ),
        );
      }).toList(),
    );

    try {
      await _player.setAudioSource(playlist, initialIndex: _indiceActual);
      await _player.setLoopMode(LoopMode.off);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final audio = widget.listaAudios[_indiceActual];
        final tituloDoc = audio['titulo'].toString().replaceAll(' ', '_');
        var doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('progreso')
            .doc(tituloDoc)
            .get();

        if (doc.exists && doc.data()?['segundos_actuales'] != null) {
          int seg = doc.data()!['segundos_actuales'];
          await _player.seek(Duration(seconds: seg), index: _indiceActual);
        }
      }

      if (mounted) {
        setState(() => _cargando = false);
        _player.play();
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

  void _irAAnterior() {
    if (_player.position.inSeconds >= 2) {
      _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      _player.seekToPrevious();
    }
  }

  Future<void> _guardarProgresoActual(Duration p) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _total == Duration.zero || _cargando) return;

    final audio = widget.listaAudios[_indiceActual];
    final tituloDoc = audio['titulo'].toString().replaceAll(' ', '_');
    bool terminado = (_total.inSeconds - p.inSeconds) <= 3;

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('progreso')
          .doc(tituloDoc)
          .set({
            'titulo': audio['titulo'],
            'url_id': audio['url'],
            'segundos_actuales': p.inSeconds,
            'terminado': terminado,
            'ultimo_acceso': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

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

  String _formatearTiempo(Duration duration) {
    String dosDigitos(int n) => n.toString().padLeft(2, "0");
    String minutos = dosDigitos(duration.inMinutes.remainder(60));
    String segundos = dosDigitos(duration.inSeconds.remainder(60));
    return "$minutos:$segundos";
  }

  @override
  void dispose() {
    _player.dispose();
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
                onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
              ),
            ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded, size: 45),
                  onPressed:
                      _player.hasPrevious || _player.position.inSeconds >= 2
                      ? () => _irAAnterior()
                      : null,
                ),
                GestureDetector(
                  onTap: () async {
                    final processingState = _player.processingState;

                    if (processingState == ProcessingState.completed) {
                      await _player.stop();
                      await _player.seek(Duration.zero, index: _indiceActual);
                      _player.play();
                    } else {
                      if (_player.playing) {
                        await _player.pause();
                      } else {
                        _player.play();
                      }
                    }
                  },
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