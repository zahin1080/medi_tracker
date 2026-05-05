import 'package:flutter/material.dart';
import 'package:medi_tracker/basicloginpage.dart';
import 'package:medi_tracker/patienthomepage.dart';
import 'package:medi_tracker/doctorhomepage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medi_tracker/supabase_config.dart';

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
      home: AuthSessionChecker(),
    );
  }
}

class AuthSessionChecker extends StatefulWidget {
  const AuthSessionChecker({super.key});

  @override
  State<AuthSessionChecker> createState() => _AuthSessionCheckerState();
}

class _AuthSessionCheckerState extends State<AuthSessionChecker> {
  @override
  void initState() {
    super.initState();
    checkLoginSession();
  }

  Future<void> checkLoginSession() async {
    await Future.delayed(const Duration(milliseconds: 600));

    final session = supabase.auth.currentSession;

    if (!mounted) return;

    if (session == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('role')
          .eq('id', currentUser.id)
          .single();

      final role = profile['role'];

      if (!mounted) return;

      if (role == 'patient') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PatientHomePage()),
        );
      } else if (role == 'doctor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DoctorHomePage()),
        );
      } else {
        await supabase.auth.signOut();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8E6FF7),
        ),
      ),
    );
  }
}
