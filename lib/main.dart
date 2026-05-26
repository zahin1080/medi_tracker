import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:entrig/entrig.dart';
import 'package:flutter/material.dart';
import 'package:medi_tracker/authentications/basicloginpage.dart';
import 'package:medi_tracker/doctorpage/doctorhomepage.dart';
import 'package:medi_tracker/patientpage/patienthomepage.dart';
import 'package:medi_tracker/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medi_tracker/authentications/resetpasswordpage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://crgbovkwcmzzwuykaayh.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNyZ2Jvdmt3Y216end1eWthYXloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NTY1MDgsImV4cCI6MjA5MjEzMjUwOH0.87k-s9478tiaUj0-hxPMcvTIqeUo3c0lDmAwCN0Wt3Q',
  );
  await Entrig.init(apiKey: 'sk-proj-3d259f22-4c284b2926b3a263d6b8c0ad6711a57897bb4f441e646715dfbbca6c3bfaab5b');
  await registerCurrentUserForEntrig();
  listenForEntrigAuthChanges();
  listenForEntrigNotificationOpen();
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool isResetPasswordFlow = false;
StreamSubscription<dynamic>? entrigAuthSubscription;
StreamSubscription<dynamic>? entrigNotificationOpenSubscription;
Future<void> registerCurrentUserForEntrig() async {
  try {
    if (isResetPasswordFlow) {
      debugPrint('Entrig registration skipped during reset password flow');
      return;
    }
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    await Entrig.register(
      userId: currentUser.id,
    );

    debugPrint('Entrig device registered for user: ${currentUser.id}');
  } catch (e) {
    debugPrint('Entrig registration error: $e');
  }
}

void listenForEntrigAuthChanges() {
  entrigAuthSubscription = supabase.auth.onAuthStateChange.listen((data) async {
    try {
      if (isResetPasswordFlow) {
        debugPrint('Entrig auth change skipped during reset password flow');
        return;
      }
      final session = data.session;
      final user = session?.user;

      if (user != null) {
        await Entrig.register(
          userId: user.id,
        );

        debugPrint('Entrig device registered after auth change: ${user.id}');
      } else {
        await Entrig.unregister();

        debugPrint('Entrig device unregistered after logout');
      }
    } catch (e) {
      debugPrint('Entrig auth listener error: $e');
    }
  });
}

void listenForEntrigNotificationOpen() {
  entrigNotificationOpenSubscription =
      Entrig.onNotificationOpened.listen((event) {
        try {
          debugPrint('Entrig notification opened: ${event.type}');
          debugPrint('Entrig notification data: ${event.data}');

          final notificationType = event.type;

          if (notificationType == 'medicine_reminder') {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const PatientHomePage(),
              ),
                  (route) => false,
            );

            return;
          }

          if (notificationType == 'appointment_accepted' ||
              notificationType == 'zoom_link_added') {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const PatientHomePage(),
              ),
                  (route) => false,
            );

            return;
          }

          if (notificationType == 'new_consultation_request') {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const DoctorHomePage(),
              ),
                  (route) => false,
            );

            return;
          }
        } catch (e) {
          debugPrint('Entrig notification open error: $e');
        }
      });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks appLinks = AppLinks();
  StreamSubscription<Uri>? linkSubscription;

  @override
  void initState() {
    super.initState();
    listenForDeepLinks();
  }

  void listenForDeepLinks() {
    linkSubscription = appLinks.uriLinkStream.listen(
          (Uri uri) async {
        await handleRecoveryLink(uri);
      },
      onError: (error) {
        debugPrint('Deep link error: $error');
      },
    );
  }

  Future<void> handleRecoveryLink(Uri uri) async {
    debugPrint('Received URI: $uri');

    if (uri.scheme == 'com.example.meditracker' &&
        uri.host == 'login-callback') {
      try {
        isResetPasswordFlow = true;
        await Future.delayed(const Duration(milliseconds: 200));
        await supabase.auth.getSessionFromUrl(uri);
        debugPrint('Recovery session created successfully');
      }catch (e) {
        debugPrint('Recovery session error: $e');
      }
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ResetPasswordPage(),
          ),
              (route) => false,
        );
      }
    }

  @override
  void dispose() {
    linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const AppStartPage(),
    );
  }
}

class AppStartPage extends StatefulWidget {
  const AppStartPage({super.key});

  @override
  State<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends State<AppStartPage> {
  final AppLinks appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    startApp();
  }

  Future<void> startApp() async {
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final Uri? initialUri = await appLinks.getInitialLink();
      debugPrint('Initial URI: $initialUri');

      if (initialUri != null &&
          initialUri.scheme == 'com.example.meditracker' &&
          initialUri.host == 'login-callback') {
        isResetPasswordFlow = true;

        try {
          await supabase.auth.getSessionFromUrl(initialUri);
          debugPrint('Initial recovery session created successfully');
        } catch (e) {
          debugPrint('Initial recovery link error: $e');
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ResetPasswordPage(),
          ),
        );

        return;
      }
    } catch (e) {
      debugPrint('Initial link read error: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthSessionChecker(),
      ),
    );
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
    if (isResetPasswordFlow) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ResetPasswordPage(),
        ),
      );

      return;
    }

    await Future.delayed(const Duration(milliseconds: 200));

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
      if(!isResetPasswordFlow){
      await Entrig.register(
        userId: currentUser.id,
      );
    }
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
          MaterialPageRoute(
            builder: (context) => const PatientHomePage(),
          ),
        );
      } else if (role == 'doctor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DoctorHomePage(),
          ),
        );
      } else {
        await Entrig.unregister();
        await supabase.auth.signOut();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      await Entrig.unregister();
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