import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://yiapxwszpmqvdqoyrghc.supabase.co',
    anonKey: 'sb_publishable_54a6TflaEl6_EprpmQx--Q_b9Thtnq5',
  );

  runApp(const LUAccessApp());
}

class LUAccessApp extends StatelessWidget {
  const LUAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LU Access',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}
