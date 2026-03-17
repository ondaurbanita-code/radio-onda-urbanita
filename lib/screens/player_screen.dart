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
      int segundosGuardados = prefs.getInt('posicion_${widget.titulo}') ?? 0;
      bool terminado = prefs.getBool('terminado_${widget.titulo}') ?? false;

      await _player.setUrl(widget.urlAudio);

      if (!terminado && segundosGuardados > 0) {
        await _player.seek(Duration(seconds: segundosGuardados));
      }
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        title: Image.asset('LOGO_ONDA_URBANITA.png', height: 60),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Slider(
                    activeColor: Colors.orange,
                    inactiveColor: Colors.orange[100],
                    value: _posicion.inSeconds.toDouble(),
                    max: (_total.inSeconds > 0)
                        ? _total.inSeconds.toDouble()
                        : (_posicion.inSeconds.toDouble() + 1),
                    onChanged: (value) =>
                        _player.seek(Duration(seconds: value.toInt())),
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
                  SizedBox(height: 20),
                  if (_cargando)
                    const CircularProgressIndicator(color: Colors.orange)
                  else
                    IconButton(
                      icon: Icon(
                        _player.playing ? Icons.pause : Icons.play_arrow,
                        size: 50,
                      ),
                      onPressed: () =>
                          _player.playing ? _player.pause() : _player.play(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
