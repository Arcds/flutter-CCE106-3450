import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
 
import 'firebase_options.dart';
import 'login_screen.dart';
 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 
  runApp(const StudentApp());
}
 
class StudentApp extends StatelessWidget {
  const StudentApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Application',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
 