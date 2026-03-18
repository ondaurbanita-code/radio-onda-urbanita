import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  final String urlAudio;
  final String titulo;

  const PlayerScreen({super.key, required this.urlAudio, required this.titulo});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _cargando = false;
  Duration _posicion = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
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
      final prefs = await SharedPreferences.getInstance();
      int segs = prefs.getInt('posicion_${widget.titulo}') ?? 0;
      bool term = prefs.getBool('terminado_${widget.titulo}') ?? false;
      await _player.setUrl(widget.urlAudio);
      if (!term && segs > 0) await _player.seek(Duration(seconds: segs));
    } catch (e) {
      debugPrint("error: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarProgreso(Duration p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('posicion_${widget.titulo}', p.inSeconds);
    if (_total.inSeconds > 0 && (_total.inSeconds - p.inSeconds) < 2) {
      await prefs.setBool('terminado_${widget.titulo}', true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'LOGO_ONDA_URBANITA.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Text(
                widget.titulo,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                "Onda Urbanita - En directo",
                style: TextStyle(color: Colors.grey),
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
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
                ),
              ],
            ),
          ),
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
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
