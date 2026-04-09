import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool mostrarPass = false;

  String? errorEmail;
  String? errorPass;

  Future<void> iniciarSesion() async {
    setState(() {
      errorEmail = null;
      errorPass = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
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
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                errorText: errorEmail,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: !mostrarPass,
              decoration: InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                errorText: errorPass,
                suffixIcon: IconButton(
                  icon: Icon(
                    mostrarPass ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => mostrarPass = !mostrarPass),
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Entrar", style: TextStyle(color: Colors.white)),
            ),
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