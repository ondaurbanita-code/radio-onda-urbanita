import 'package:flutter/material.dart';
import 'listado_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Image.asset('LOGO_ONDA_URBANITA.png', height: 50),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange[400]!, Colors.orange[800]!],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              sectionButton("Quiénes somos", Icons.info_outline, context),
              SizedBox(height: 25),
              sectionButton("Programas de radio", Icons.radio, context),
              SizedBox(height: 25),
              sectionButton("Contacto", Icons.alternate_email, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionButton(String text, IconData icon, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (text == "Programas de radio") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ListadoScreen()),
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: Colors.orange[800]),
            SizedBox(width: 15),
            Text(
              text,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
