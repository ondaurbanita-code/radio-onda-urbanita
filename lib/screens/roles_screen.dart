import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionRolesScreen extends StatefulWidget {
  const GestionRolesScreen({super.key});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  // función asíncrona para activar o desactivar el rol de administrador en firestore
  void toggleAdmin(String userId, String? currentRol) async {
    // si el rol actual es admin lo quitamos pasándolo a null, si no le asignamos admin
    String? nuevoRol = (currentRol == 'admin') ? null : 'admin';

    try {
      // actualizamos de forma directa el campo rol en el documento del usuario
      await FirebaseFirestore.instance.collection('usuarios').doc(userId).set(
        {'rol': nuevoRol},
        SetOptions(merge: true),
      ); // usamos merge para sobreescribir solo el campo rol sin romper el resto
    } catch (e) {
      print("error al cambiar rol: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Gestionar Admins", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      // usamos streambuilder para escuchar la coleccion en tiempo real sin recargar la pantalla
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          // pintamos el spinner de carga si firebase todavia esta descargando los datos
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          var docs = snapshot.data!.docs;

          // ordenamos la lista de documentos en local antes de pintar las celdas
          docs.sort((a, b) {
            String? rolA = a.data()['rol'];
            String? rolB = b.data()['rol'];

            // si a es superadmin, va primero (-1)
            if (rolA == 'superadmin') return -1;
            // si b es superadmin, a va después (1)
            if (rolB == 'superadmin') return 1;
            // si ninguno lo es, se quedan como están (0)
            return 0;
          });

          return ListView.separated(
            padding: EdgeInsets.all(10),
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey[200]),
            // linea divisoria fina entre usuarios
            itemBuilder: (context, i) {
              var data = docs[i].data();
              String nombre = data['nombre'] ?? "Sin nombre";
              String email = data['email'] ?? "Sin email";
              String? rol = data['rol'];
              bool esAdmin = rol == 'admin' || rol == 'superadmin';
              bool esSuperAdmin = rol == 'superadmin';

              return ListTile(
                leading: CircleAvatar(
                  // cambiamos el color del avatar de forma condicional segun los permisos
                  backgroundColor: esAdmin
                      ? Colors.orange[100]
                      : Colors.grey[200],
                  child: Icon(
                    esAdmin ? Icons.verified_user : Icons.person,
                    color: esAdmin ? Colors.orange[800] : Colors.grey[600],
                  ),
                ),
                title: Text(
                  nombre,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(email),
                // si es superadmin le pintamos un badge azul fijo, si no le ponemos el switch editable
                trailing: esSuperAdmin
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "SUPERADMIN",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Switch(
                        activeColor: Colors.orange,
                        value: esAdmin,
                        // disparamos la funcion toggle pasando la id del documento y el rol de esa celda
                        onChanged: (value) => toggleAdmin(docs[i].id, rol),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}