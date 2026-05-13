import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/secrets.dart';

class ContactoScreen extends StatefulWidget {
  const ContactoScreen({super.key});

  @override
  State<ContactoScreen> createState() => _ContactoScreenState();
}

class _ContactoScreenState extends State<ContactoScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  bool _enviando = false;

  Future<void> _enviarDirecto() async {
    String mensaje = _mensajeController.text.trim();

    if (mensaje.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe algo antes de enviar")),
      );
      return;
    }

    setState(() => _enviando = true);


    String username = 'ondaurbanita@gmail.com';
    String password = Secrets.gmailPassword;

    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 465,
      ssl: true,
      username: username,
      password: password,
    );

    final message = Message()
      ..from = Address(username, 'App Onda Urbanita')
      ..recipients.add('ondaurbanita@gmail.com')
      ..subject = 'Nueva sugerencia de usuario'
      ..text = mensaje;

    try {
      await send(message, smtpServer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Mensaje enviado correctamente!")),
        );
        _mensajeController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al enviar: $e")));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(centerTitle: true,
        title: Text(
          "Contacto",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Tienes alguna sugerencia?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Escríbenos directamente y te leeremos lo antes posible.",
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            TextField(
              controller: _mensajeController,
              maxLines: 8,
              enabled: !_enviando,
              decoration: InputDecoration(
                hintText: "Escribe tu sugerencia...",
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarDirecto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _enviando
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Enviar ahora",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
