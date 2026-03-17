import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        scaffoldBackgroundColor: Colors.orange[400],
      ),
      home: HomeScreen(),
    );
  }
}