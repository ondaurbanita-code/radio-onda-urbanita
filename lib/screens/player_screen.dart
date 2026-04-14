import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
    _player.positionStream.listen((p) => setState(() => _posicion = p));
    _player.durationStream.listen(
      (d) => setState(() => _total = d ?? Duration.zero),
    );
    _prepararAudio();
  }

  Future<void> _prepararAudio() async {
    setState(() => _cargando = true);
    final audio = widget.listaAudios[_indiceActual];
    await _player.setUrl(audio['url']);
    _player.play();
    setState(() => _cargando = false);
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
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Image.network(
            audio['imagen'],
            width: 250,
            height: 250,
            fit: BoxFit.cover,
          ),
          Column(
            children: [
              Text(
                audio['titulo'],
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (audio['descripcion'] != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Text(
                    audio['descripcion'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          Slider(
            value: _posicion.inSeconds.toDouble(),
            max: _total.inSeconds.toDouble() > 0
                ? _total.inSeconds.toDouble()
                : 1.0,
            onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous, size: 40),
                onPressed: () => setState(() {
                  if (_indiceActual > 0) _indiceActual--;
                  _prepararAudio();
                }),
              ),
              IconButton(
                icon: Icon(
                  _player.playing ? Icons.pause_circle : Icons.play_circle,
                  size: 60,
                ),
                onPressed: () => setState(
                  () => _player.playing ? _player.pause() : _player.play(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_next, size: 40),
                onPressed: () => setState(() {
                  if (_indiceActual < widget.listaAudios.length - 1) {
                    _indiceActual++;
                  }
                  _prepararAudio();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
