import 'package:flutter/material.dart';
import 'package:medi_tracker/basicloginpage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:medi_tracker/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://crgbovkwcmzzwuykaayh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNyZ2Jvdmt3Y216end1eWthYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NTY1MDgsImV4cCI6MjA5MjEzMjUwOH0.87k-s9478tiaUj0-hxPMcvTIqeUo3c0lDmAwCN0Wt3Q',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
