import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const OndaUrbanitaApp());
}

class OndaUrbanitaApp extends StatelessWidget {
  const OndaUrbanitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Onda Urbanita",
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor:
            Colors.white,
      ),
      home: HomeScreen(),
    );
  }
}
