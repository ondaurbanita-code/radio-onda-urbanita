import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _indiceActual = widget.indiceInicial;
    _player.positionStream.listen((p) {
      if (mounted) {
        setState(() => _posicion = p);
        _guardarProgreso(p);
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
      final prefs = await SharedPreferences.getInstance();
      int segs = prefs.getInt('posicion_${audio['titulo']}') ?? 0;
      bool term = prefs.getBool('terminado_${audio['titulo']}') ?? false;
      await _player.setUrl(audio['url']);
      if (!term && segs > 0) await _player.seek(Duration(seconds: segs));
      _player.play();
    } catch (e) {
      debugPrint("error: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _anterior() {
    if (_posicion.inSeconds > 1 || _indiceActual == 0) {
      _player.seek(Duration.zero);
    } else if (_indiceActual > 0) {
      setState(() => _indiceActual--);
      _prepararAudio();
    }
  }

  void _siguiente() {
    if (_indiceActual < widget.listaAudios.length - 1) {
      setState(() => _indiceActual++);
      _prepararAudio();
    }
  }

  Future<void> _guardarProgreso(Duration p) async {
    final audio = widget.listaAudios[_indiceActual];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('posicion_${audio['titulo']}', p.inSeconds);
    if (_total.inSeconds > 0 && (_total.inSeconds - p.inSeconds) < 2) {
      await prefs.setBool('terminado_${audio['titulo']}', true);
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
    return Scaffold(
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
                  errorBuilder: (c, e, s) =>
                      Image.asset('logo.png'),
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
                  onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
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
                icon: Icon(Icons.skip_previous, size: 45, color: Colors.orange),
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
                    onPressed: () =>
                        _player.playing ? _player.pause() : _player.play(),
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
    );
  }
}
