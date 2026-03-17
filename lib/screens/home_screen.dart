import 'package:flutter/material.dart';
import 'player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Icon(Icons.menu, color: Colors.black),
        title: Icon(Icons.star, color: Colors.yellow),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text("Mi cuenta", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Column(
          children: [
            sectionButton("Quiénes somos", context),
            SizedBox(height: 20),
            sectionButton("Programas de radio", context),
            SizedBox(height: 20),
            sectionButton("Contacto", context),
          ],
        ),
      ),
    );
  }

  Widget sectionButton(String text, BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (text == "Programas de radio") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PlayerScreen()),
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}