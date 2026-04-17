import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class QuienesSomosScreen extends StatelessWidget {
  const QuienesSomosScreen({super.key});

  Future<void> _abrirYoutube() async {
    final uri = Uri.parse("https://www.youtube.com/@OndaUrbanita");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error al abrir canal: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Quiénes somos",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange[700],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/logo.png', height: 80),
                        SizedBox(height: 10),
                        Text(
                          "Onda Urbanita",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "\"La voz de nuestra escuela\"",
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bienvenidos a Onda Urbanita, el corazón sonoro del CEIP Sebastián Urbano Vázquez en Isla Cristina (Huelva). Este proyecto no es solo una radio; es el lugar donde nuestras ideas, aprendizajes y emociones cobran vida a través de las ondas.",
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 30),

                  _infoSection(
                    Icons.history,
                    "Nuestra Historia",
                    "Nacimos en el curso 2022/23 con la ilusión de transformar el colegio en un gran estudio de comunicación. Desde entonces, no hemos parado de crecer.",
                  ),

                  _infoSection(
                    Icons.track_changes,
                    "Nuestro Objetivo",
                    "Queremos que todos los alumnos y alumnas sean protagonistas. Buscamos que cada niño y niña del centro tenga la oportunidad de ponerse frente al micrófono.",
                  ),

                  SizedBox(height: 20),
                  Text(
                    "¿Qué puedes escuchar aquí?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: 15),
                  _buildListTile(
                    Icons.info,
                    "Informativos",
                    "Noticias frescas de la escuela.",
                  ),
                  _buildListTile(
                    Icons.star,
                    "Especiales",
                    "Cobertura de celebraciones importantes.",
                  ),
                  _buildListTile(
                    Icons.school,
                    "Aula",
                    "Contenidos de clase en radio.",
                  ),
                  _buildListTile(
                    Icons.record_voice_over,
                    "Podcast",
                    "Entrevistas de nuestra directora.",
                  ),

                  SizedBox(height: 30),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            "¡También nos puedes ver!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Contamos con un canal de YouTube donde subimos cada una de nuestras producciones.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: _abrirYoutube,
                            icon: Icon(
                              FontAwesomeIcons.youtube,
                              color: Colors.white,
                            ),
                            label: Text(
                              "Visitar Canal de YouTube",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Coordinación del Proyecto",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Elizabeth R. Vázquez Díaz",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(IconData icon, String title, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 28),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String desc) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orange[300]),
          SizedBox(width: 10),
          Text("$title: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(desc, style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}
