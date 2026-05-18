import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'home_screen.dart';

// widget con estado porque necesitamos controlar los textos introducidos y los errores
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // controladores para capturar lo que el usuario escribe en las cajas de texto
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool mostrarPass = false;

  // variables para guardar el texto del error si la validacion falla
  String? errorEmail;
  String? errorPass;

  // metodo asincrono para conectar con firebase auth y loguear al usuario
  Future<void> iniciarSesion() async {
    // limpiamos los errores anteriores antes de volver a intentarlo
    setState(() {
      errorEmail = null;
      errorPass = null;
    });

    try {
      // le pasamos las credenciales limpiando los espacios en blanco con trim
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );
      // si todo va bien y la pantalla sigue activa, navegamos al home borrando el historico
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // si firebase devuelve un error, controlamos el tipo para avisar en la caja correcta
      setState(() {
        String err = e.toString().toLowerCase();
        if (err.contains('user-not-found') || err.contains('invalid-email')) {
          errorEmail = "El correo es incorrecto o no existe";
        } else if (err.contains('wrong-password') ||
            err.contains('invalid-credential')) {
          errorPass = "La contraseña es incorrecta";
        } else {
          errorEmail = "Error al entrar. Revisa los datos.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // cargamos el logo del centro escolar y ponemos un icono de radio por si falla la ruta
            Image.asset(
              'assets/logo.png',
              height: 100,
              errorBuilder: (c, e, s) => Icon(Icons.radio, size: 50),
            ),
            SizedBox(height: 40),
            Text(
              "Iniciar sesión",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            // campo de texto para el correo electronico conectado a su controlador
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                errorText: errorEmail,
              ),
            ),
            SizedBox(height: 20),
            // campo de la contraseña usando el booleano para ocultar o mostrar los caracteres
            TextField(
              controller: passController,
              obscureText: !mostrarPass,
              decoration: InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                errorText: errorPass,
                // boton del ojo para cambiar el estado de visibilidad de la clave
                suffixIcon: IconButton(
                  icon: Icon(
                    mostrarPass ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => mostrarPass = !mostrarPass),
                ),
              ),
            ),
            SizedBox(height: 30),
            // boton principal que dispara el proceso de inicio de sesion asincrono
            ElevatedButton(
              onPressed: iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Entrar", style: TextStyle(color: Colors.white)),
            ),
            // boton secundario para alternar hacia la vista de registro
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RegisterScreen()),
              ),
              child: Text("¿No tienes cuenta? Regístrate"),
            ),
          ],
        ),
      ),
    );
  }
}