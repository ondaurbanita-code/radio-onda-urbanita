import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:proyecto_ondaurbanita/screens/quienes_somos_screen.dart';
import 'package:proyecto_ondaurbanita/screens/roles_screen.dart';
import '../widgets/custom_drawer.dart';
import 'admin_upload_screen.dart';
import 'contact_screen.dart';
import 'listado_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // variables para guardar los datos de sesion del usuario activo
  String? _rol;
  String? _nombreFirestore;
  bool _cargandoDatos =
      true; // controla si pintamos el circulo de carga al arrancar

  @override
  void initState() {
    super.initState();
    _inicializarApp();
    _configurarNotificaciones();
  }

  // configuracion de los permisos y la suscripcion a temas de firebase cloud messaging
  Future<void> _configurarNotificaciones() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Pedir permiso explícito (Android 13+ lo necesita sí o sí)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. SACAR EL TOKEN (Esto es lo que te falta para la captura que mandaste)
      String? token = await messaging.getToken();
      print("ESTE ES TU TOKEN: $token"); // Cópialo de la consola de VS Code

      // 3. Suscribirse
      await messaging.subscribeToTopic("anuncios_radio");
      print("Suscrito a anuncios_radio con éxito");
    } else {
      print("El usuario rechazó los permisos de notificación");
    }
  }

  // controla el estado de la sesion del usuario y escucha si se desloguea o entra
  Future<void> _inicializarApp() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _cargarDatosUsuario(user);
    } else {
      // si no hay nadie logueado quitamos el estado de carga para mostrar el modo invitado
      if (mounted) setState(() => _cargandoDatos = false);
    }

    // listener en tiempo real que reacciona de forma automatica a los cambios de auth
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        if (user != null) {
          _cargarDatosUsuario(user);
        } else {
          // limpiamos variables si el usuario decide cerrar sesion
          setState(() {
            _rol = null;
            _nombreFirestore = null;
            _cargandoDatos = false;
          });
        }
      }
    });
  }

  // recupera el rol y el nombre real del usuario de la coleccion de firestore usando su uid
  Future<void> _cargarDatosUsuario(User user) async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _rol = doc.data()?['rol'];
          _nombreFirestore = doc.data()?['nombre'];
          _cargandoDatos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // si el stream o el future estan leyendo de la nube montamos una pantalla blanca con el spinner
    if (_cargandoDatos) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    // booleano clave para alternar que se pinten o no las opciones administrativas
    bool tienePermisos = _rol == 'admin' || _rol == 'superadmin';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // inyectamos el widget personalizado del drawer pasandole los datos del usuario logueado
      drawer: CustomDrawer(rol: _rol, nombre: _nombreFirestore),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.black),
        title: Image.asset('assets/logo.png', height: 45),
        centerTitle: true,
        actions: [
          // mostramos de forma condicional el boton de subir audios si es administrador
          if (tienePermisos)
            IconButton(
              icon: Icon(Icons.add_box_outlined, color: Colors.orange),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => AdminUploadScreen()),
              ),
            ),
          // si entra como anonimo, le pintamos el atajo rapido para ir a la vista de login
          if (user == null)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => LoginScreen()),
              ),
              child: Text(
                "Inicie sesión",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // cabecera de bienvenida curvada en la parte inferior usando decoration
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hola,",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  Text(
                    _nombreFirestore ?? "Usuario",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Bienvenido a tu Radio",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            // menu de accesos directos principal construido usando nuestra funcion reutilizable
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  sectionButton(
                    "Programas de radio",
                    "Escucha nuestros últimos podcasts",
                    Icons.play_circle_fill,
                    context,
                  ),
                  SizedBox(height: 20),
                  sectionButton(
                    "Quiénes somos",
                    "Conoce al equipo de la radio",
                    Icons.people,
                    context,
                  ),
                  SizedBox(height: 20),
                  sectionButton(
                    "Contacto",
                    "Escríbenos tus sugerencias",
                    Icons.send,
                    context,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // widget personalizado reutilizable para no repetir codigo en los botones del menu principal
  Widget sectionButton(
    String text,
    String subtext,
    IconData icon,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () {
        // enrutamiento condicional segun el texto identificativo del boton pulsado
        if (text == "Programas de radio") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => ListadoScreen()),
          );
        } else if (text == "Quiénes somos") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => QuienesSomosScreen()),
          );
        } else if (text == "Contacto") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => ContactoScreen()),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange[50],
              child: Icon(icon, color: Colors.orange[800]),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtext,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}