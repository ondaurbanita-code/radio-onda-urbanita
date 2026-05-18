import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_ondaurbanita/screens/admin_upload_screen.dart';
import 'package:proyecto_ondaurbanita/screens/home_screen.dart';
import 'package:proyecto_ondaurbanita/screens/roles_screen.dart';

import '../screens/contact_screen.dart';
import '../screens/quienes_somos_screen.dart';

// al ser un widget sin estado (stateless), recibe los datos de perfil directos por el constructor
class CustomDrawer extends StatelessWidget {
  final String? rol;
  final String? nombre;

  const CustomDrawer({super.key, this.rol, this.nombre});

  // proceso asincrono definitivo para borrar el rastro del usuario en auth y base de datos
  Future<void> _procesoBorrado(BuildContext context, String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      // creamos la credencial por email obligatoria para poder hacer la re-autenticacion de seguridad
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // firebase exige volver a loguear implicitamente antes de dejar borrar una cuenta activa
      await user.reauthenticateWithCredential(credential);

      // paso 1: borramos su documento de metadatos en la coleccion usuarios de firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .delete();

      // paso 2: borramos de forma definitiva el registro del usuario en firebase authentication
      await user.delete();

      // si todo sale bien y la vista sigue montada, avisamos y redirigimos al login/inicio
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Tu cuenta ha sido eliminada correctamente. ¡Gracias por escucharnos!",
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // limpiamos el arbol de rutas para mandar al usuario al principio de la app sin poder volver atras
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "La contraseña no es correcta o hubo un problema al borrar",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // envia un enlace cifrado al correo usando la referencia del messenger para evitar fallos de contexto
  Future<void> _reestablecerPasswordConMessenger(
    ScaffoldMessengerState messenger,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "Te hemos mandado un correo para cambiar la clave. ¡Revisa el spam!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Vaya, parece que hubo un error al enviar el correo"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // dibuja un cuadro de dialogo flotante para pedir la clave antes de confirmar el borrado total
  void _mostrarDialogoConfirmacion(BuildContext context) {
    final TextEditingController passController = TextEditingController();
    bool oscurecer = true;

    showDialog(
      context: context,
      builder: (c) {
        // usamos statefulbuilder para poder refrescar el ojo de la contraseña dentro del cuadro de dialogo
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Confirmar borrado"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Escribe tu contraseña para eliminar la cuenta definitivamente:",
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: passController,
                    obscureText: oscurecer,
                    decoration: InputDecoration(
                      hintText: "Tu contraseña",
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          oscurecer ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            oscurecer = !oscurecer;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text("Cancelar"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    if (passController.text.isNotEmpty) {
                      Navigator.pop(c); // cerramos el cuadro flotante
                      _procesoBorrado(
                        context,
                        passController.text,
                      ); // lanzamos el borrado
                    }
                  },
                  child: Text(
                    "Eliminar todo",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // cabecera visual del menu lateral con un degradado naranja corporativo
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
                  nombre ?? "Usuario",
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
            leading: Icon(Icons.home, color: Colors.orange),
            title: Text("Inicio"),
            onTap: () {
              Navigator.pop(
                context,
              ); // cerramos el drawer siempre antes de navegar para liberar la ui
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => HomeScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.radio, color: Colors.orange),
            title: Text("Programas"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.people, color: Colors.orange),
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
            leading: Icon(Icons.send, color: Colors.orange),
            title: Text("Contacto"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => ContactoScreen()),
              );
            },
          ),
          Divider(),
          // filtro condicional para que solo el superadmin vea el boton de configuracion de usuarios
          if (rol == 'superadmin')
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
          // los usuarios normales ven el boton de borrar, pero ocultamos este peligro al superadmin principal
          if (user != null && rol != 'superadmin')
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Colors.redAccent,
              ),
              title: Text("Eliminar cuenta"),
              onTap: () => _mostrarDialogoConfirmacion(context),
            ),
          if (user != null)
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text("Cerrar sesión"),
              onTap: () => FirebaseAuth.instance
                  .signOut(), // rompe la sesion activa de auth de forma directa
            ),
          Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: () {
                // truco técnico: guardamos la referencia antes de cerrar para que la snackbar no de error de contexto
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // cerramos el menu lateral
                _reestablecerPasswordConMessenger(
                  messenger,
                ); // lanzamos la peticion asincrona
              },
              icon: Icon(Icons.lock_reset, color: Colors.blueGrey),
              label: Text(
                "Restablecer Contraseña",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}