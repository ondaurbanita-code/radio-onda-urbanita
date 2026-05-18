import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // controladores para capturar el texto introducido en el formulario de alta
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool mostrarPass = false;

  // variables de estado para pintar los errores debajo de cada textfield
  String? errorNombre;
  String? errorEmail;
  String? errorPass;

  // funcion de test que usa una expresion regular para obligar a meter claves robustas
  bool validarPassword(String password) {
    final regExp = RegExp(r'^(?=.*[!@#\$&*~\.])(?=.{6,12}$)');
    return regExp.hasMatch(password);
  }

  // metodo asincrono para dar de alta en auth y meter los metadatos en firestore
  Future<void> registrarUsuario() async {
    // reseteamos los textos de error antes de lanzar una nueva validacion
    setState(() {
      errorNombre = null;
      errorEmail = null;
      errorPass = null;
    });

    // bloque de validacion manual preventiva para evitar peticiones vacias a firebase
    if (nombreController.text.isEmpty) {
      setState(() => errorNombre = "Introduce un nombre de usuario");
      return;
    }
    if (emailController.text.isEmpty) {
      setState(() => errorEmail = "Introduzca un correo electrónico");
      return;
    }
    if (!validarPassword(passController.text.trim())) {
      setState(
        () => errorPass = "Usa 6-12 caracteres y un símbolo (!@#\$&*~.)",
      );
      return;
    }

    try {
      // paso 1: creamos el usuario en el modulo de firebase authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passController.text.trim(),
          );

      // paso 2: actualizamos el perfil nativo de auth para asignarle su nombre
      await userCredential.user?.updateDisplayName(
        nombreController.text.trim(),
      );

      // paso 3: creamos su documento de base de datos en firestore mapeado con su uid
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCredential.user?.uid)
          .set({
            'nombre': nombreController.text.trim(),
            'email': emailController.text.trim(),
            'rol':
                'user', // rol por defecto para los nuevos oyentes de la radio
            'fechaRegistro': DateTime.now(),
          });

      // si todo el proceso en la nube termina bien, saltamos al home limpiando el arbol de vistas
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // capturamos excepciones especificas del backend de firebase para dar feedback
      setState(() {
        String err = e.toString().toLowerCase();
        if (err.contains('email-already-in-use')) {
          errorEmail = "Este correo ya está registrado";
        } else if (err.contains('invalid-email')) {
          errorEmail = "El formato del correo no es válido";
        } else {
          errorEmail = "Error al registrar. Revisa la conexión.";
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
      // usamos un singlechildscrollview para evitar desbordamientos si sale el teclado en pantalla
      body: SingleChildScrollView(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 100,
              errorBuilder: (c, e, s) => Icon(Icons.radio, size: 50),
            ),
            SizedBox(height: 40),
            Text(
              "Crear Cuenta",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: "Nombre de usuario",
                border: OutlineInputBorder(),
                errorText: errorNombre,
              ),
            ),
            SizedBox(height: 20),
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
              onPressed: registrarUsuario,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text("Registrarse", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}