import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PlayerScreen extends StatefulWidget {
  final List listaAudios;
  final int indiceInicial;

  PlayerScreen({
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
    final audio = widget.listaAudios[_indiceActual];
    try {
      await _player.setUrl(audio['url']);
      _player.play();
    } catch (e) {
      print("error: $e");
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
              "Onda Urbanita",
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
                  Text(
                    _formatearTiempo(_posicion),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    _formatearTiempo(_total),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded, size: 45),
                  onPressed: _indiceActual > 0
                      ? () {
                          setState(() {
                            _indiceActual--;
                            _prepararAudio();
                          });
                        }
                      : null,
                ),
                GestureDetector(
                  onTap: () => setState(
                    () => _player.playing ? _player.pause() : _player.play(),
                  ),
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange[800],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _player.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded, size: 45),
                  onPressed: _indiceActual < widget.listaAudios.length - 1
                      ? () {
                          setState(() {
                            _indiceActual++;
                            _prepararAudio();
                          });
                        }
                      : null,
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
