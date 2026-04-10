import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _cargando = false;
  Duration _posicion = Duration.zero;
  Duration _total = Duration.zero;
  int _ultimoSegundoGuardado = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _indiceActual = widget.indiceInicial;

    _player.positionStream.listen((p) {
      if (mounted) {
        setState(() => _posicion = p);

        if ((p.inSeconds - _ultimoSegundoGuardado).abs() >= 10) {
          _ultimoSegundoGuardado = p.inSeconds;
          _guardarPosicionActual();
        }

        _comprobarYGuardarFin(p);
      }
    });

    _player.durationStream.listen((d) {
      if (mounted) setState(() => _total = d ?? Duration.zero);
    });

    _prepararAudio();
  }

  Future<void> _prepararAudio() async {
    setState(() => _cargando = true);
    try {
      final audio = widget.listaAudios[_indiceActual];
      final user = FirebaseAuth.instance.currentUser;
      final urlActual = audio['url'];

      await _player.setUrl(urlActual);

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('progreso')
            .doc(audio['titulo'])
            .get();

        if (doc.exists) {
          bool term = doc.data()?['terminado'] ?? false;
          int segs = doc.data()?['posicion'] ?? 0;

          if (!term && segs > 0) {
            await _player.seek(Duration(seconds: segs));
            _ultimoSegundoGuardado = segs;
          } else if (term) {
            await _player.seek(Duration.zero);
          }
        }
      }

      _player.play();
    } catch (e) {
      debugPrint("error: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPosicionActual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final audio = widget.listaAudios[_indiceActual];
    final urlActual = audio['url'];
    final bool terminado =
        _total.inSeconds > 0 && (_total.inSeconds - _posicion.inSeconds) <= 3;

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('progreso')
        .doc(audio['titulo'])
        .set({
          'posicion': _posicion.inSeconds,
          'terminado': terminado,
          'url_id': urlActual,
          'ultimoAcceso': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (terminado) {
      final prefs = await SharedPreferences.getInstance();
      List<String> vistos = prefs.getStringList('podcasts_vistos') ?? [];
      if (!vistos.contains(urlActual)) {
        vistos.add(urlActual);
        await prefs.setStringList('podcasts_vistos', vistos);
      }
    }
  }

  Future<void> _comprobarYGuardarFin(Duration p) async {
    if (_total.inSeconds > 0 && (_total.inSeconds - p.inSeconds) <= 2) {
      _guardarPosicionActual();
    }
  }

  void _anterior() async {
    await _guardarPosicionActual();
    if (_posicion.inSeconds > 1 || _indiceActual == 0) {
      _player.seek(Duration.zero);
    } else if (_indiceActual > 0) {
      setState(() => _indiceActual--);
      _prepararAudio();
    }
  }

  void _siguiente() async {
    await _guardarPosicionActual();
    if (_indiceActual < widget.listaAudios.length - 1) {
      setState(() => _indiceActual++);
      _prepararAudio();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.listaAudios[_indiceActual];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _guardarPosicionActual();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.network(
                    audio['imagen'],
                    fit: BoxFit.fill,
                    errorBuilder: (c, e, s) => Image.asset('assets/logo.png'),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  audio['titulo'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Onda Urbanita",
                  style: TextStyle(color: Colors.grey, letterSpacing: 1.2),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Slider(
                    activeColor: Colors.orange[800],
                    inactiveColor: Colors.orange[100],
                    value: _posicion.inSeconds.toDouble(),
                    max: (_total.inSeconds > 0)
                        ? _total.inSeconds.toDouble()
                        : (_posicion.inSeconds.toDouble() + 1),
                    onChanged: (v) =>
                        _player.seek(Duration(seconds: v.toInt())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_posicion.inMinutes}:${(_posicion.inSeconds % 60).toString().padLeft(2, '0')}",
                      ),
                      Text(
                        "${_total.inMinutes}:${(_total.inSeconds % 60).toString().padLeft(2, '0')}",
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.skip_previous,
                    size: 45,
                    color: Colors.orange,
                  ),
                  onPressed: _anterior,
                ),
                SizedBox(width: 20),
                if (_cargando)
                  CircularProgressIndicator(color: Colors.orange)
                else
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.orange[800],
                    child: IconButton(
                      icon: Icon(
                        _player.playing ? Icons.pause : Icons.play_arrow,
                        size: 45,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        if (_player.playing) {
                          await _player.pause();
                          await _guardarPosicionActual();
                        } else {
                          await _player.play();
                        }
                        setState(() {});
                      },
                    ),
                  ),
                SizedBox(width: 20),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 45, color: Colors.orange),
                  onPressed: _siguiente,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}