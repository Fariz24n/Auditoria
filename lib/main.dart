import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'service/app_router.dart'; // memuat appRouter

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // 👈 lebih eksplisit

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Auditoria',
      theme: ThemeData.dark(),
      routerConfig: appRouter, 
      debugShowCheckedModeBanner: false,
    );
  }
}
