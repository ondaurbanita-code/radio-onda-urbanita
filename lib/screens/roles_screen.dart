import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionRolesScreen extends StatefulWidget {
  const GestionRolesScreen({super.key});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  final emailCtrl = TextEditingController();

  void asignarRol(String email, String rol) async {
    if (email.isEmpty) return;
    await FirebaseFirestore.instance.collection('roles').doc(email).set({
      'rol': rol,
    });
    emailCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestión de Permisos"),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      hintText: "Email del nuevo admin",
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_moderator),
                  onPressed: () => asignarRol(emailCtrl.text, "admin"),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('roles')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return LinearProgressIndicator();
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(docs[i].id),
                    subtitle: Text(docs[i]['rol']),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('roles')
                          .doc(docs[i].id)
                          .delete(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
