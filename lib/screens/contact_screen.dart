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
  // controlador para capturar la sugerencia o mensaje que redacte el usuario
  final TextEditingController _mensajeController = TextEditingController();
  bool _enviando =
      false; // booleano para controlar el spinner de carga en el boton

  // metodo asincrono que usa el paquete mailer para mandar un correo por smtp
  Future<void> _enviarDirecto() async {
    String mensaje = _mensajeController.text.trim();

    // validacion preventiva para no mandar correos totalmente vacios
    if (mensaje.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe algo antes de enviar")),
      );
      return;
    }

    setState(() => _enviando = true);

    // configuramos las credenciales trayendo la clave de aplicacion desde el secrets
    String username = 'ondaurbanita@gmail.com';
    String password = Secrets.gmailPassword;

    // configuramos el servidor smtp de google usando el puerto ssl seguro
    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 465,
      ssl: true,
      username: username,
      password: password,
    );

    // construimos la estructura del mensaje asignando emisor, receptor y el cuerpo del texto
    final message = Message()
      ..from = Address(username, 'App Onda Urbanita')
      ..recipients.add(
        'ondaurbanita@gmail.com',
      ) // el correo se manda al propio administrador
      ..subject = 'Nueva sugerencia de usuario'
      ..text = mensaje;

    try {
      // realizamos el envio asincrono conectando con el servidor de correo
      await send(message, smtpServer);
      // si todo va bien y la pantalla sigue montada, avisamos y limpiamos el formulario
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
      // liberamos el estado de enviando para reactivar el boton en la ui
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
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
            // caja de texto multilineal para redactar el mensaje de soporte
            TextField(
              controller: _mensajeController,
              maxLines: 8,
              // definimos un tamaño alto para que quepan varias lineas de texto
              enabled: !_enviando,
              // bloqueamos la edicion mientras se procesa el envio del correo
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
            // boton de envio que alterna su contenido de forma condicional segun el booleano
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviarDirecto,
                // se desactiva si esta enviando
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _enviando
                    ? CircularProgressIndicator(
                        color: Colors.white,
                      ) // spinner blanco de carga
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