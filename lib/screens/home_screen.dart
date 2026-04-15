import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_ondaurbanita/screens/quienes_somos_screen.dart';
import 'package:proyecto_ondaurbanita/screens/roles_screen.dart';
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
  String? _rol;

  @override
  void initState() {
    super.initState();
    _comprobarRol();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _comprobarRol();
        setState(() {});
      }
    });
  }

  void _comprobarRol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        setState(() => _rol = doc.data()?['rol']);
      } else {
        setState(() => _rol = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool tienePermisos = _rol == 'admin' || _rol == 'superadmin';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[700]!, Colors.orange[400]!],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/logo.png', height: 60),
                  SizedBox(height: 10),
                  Text(
                    "Onda Urbanita",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text("Quiénes somos"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => QuienesSomosScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.send),
              title: Text("Contacto"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => ContactoScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.radio),
              title: Text("Programas"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => ListadoScreen()),
                );
              },
            ),
            if (_rol == 'superadmin') ...[
              Divider(),
              ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: Text("Gestionar Roles"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => GestionRolesScreen()),
                  );
                },
              ),
            ],
            Divider(),
            if (user != null)
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text("Cerrar sesión"),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.black),
        title: Image.asset('assets/logo.png', height: 45),
        centerTitle: true,
        actions: [
          if (tienePermisos)
            IconButton(
              icon: Icon(Icons.add_box_outlined, color: Colors.orange),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => AdminUploadScreen()),
              ),
            ),
          if (user == null)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => LoginScreen()),
              ),
              child: Text(
                "¿A qué esperas? Inicia sesión",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    user?.displayName ?? "Usuario",
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

  Widget sectionButton(
    String text,
    String subtext,
    IconData icon,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () {
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
