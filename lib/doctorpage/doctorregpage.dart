import 'package:flutter/material.dart';
import 'package:medi_tracker/authentications/basicloginpage.dart';
import 'package:medi_tracker/supabase_config.dart';

class DoctorRegPage extends StatefulWidget {
  const DoctorRegPage({super.key});

  @override
  State<DoctorRegPage> createState() => _DoctorRegPageState();
}

class _DoctorRegPageState extends State<DoctorRegPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final bmdcController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  final RegExp passwordRegex = RegExp(
    r'^(?=.*[0-9])(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$',
  );

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    bmdcController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> registerDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final fullName = nameController.text.trim();
      final email = emailController.text.trim();
      final bmdcCode = bmdcController.text.trim();
      final password = passwordController.text.trim();

      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo:
        'com.example.meditracker://login-callback/',
        data: {
          'full_name': fullName,
          'role': 'doctor',
          'bmdc_code': bmdcCode,
        },
      );

      final currentUser = authResponse.user;

      if (currentUser == null) {
        throw Exception('Doctor registration failed.');
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Verify Email'),
          content: const Text(
            'A verification email has been sent to your email address.\n\nPlease verify your email before login.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration underlineDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: Colors.grey,
        letterSpacing: 0.8,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF2F80ED), width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget topDecorationLogo() {
    return SizedBox(
      width: 95,
      height: 75,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF2F80ED),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF5DA2FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 0,
            child: Container(
              width: 36,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1C5FD4).withOpacity(0.65),
                borderRadius: const BorderRadius.all(Radius.circular(30)),
              ),
            ),
          ),
          Positioned(
            left: 34,
            top: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1C5FD4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget backgroundShape({
    required double top,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: 0.78,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          backgroundShape(
            top: -40,
            left: -40,
            size: 130,
            color: const Color(0xFFBDEBE4).withOpacity(0.55),
          ),
          backgroundShape(
            top: -30,
            right: 45,
            size: 115,
            color: const Color(0xFFDCEBFF).withOpacity(0.65),
          ),
          backgroundShape(
            top: 55,
            right: 30,
            size: 22,
            color: const Color(0xFFC9EDE5).withOpacity(0.75),
          ),
          backgroundShape(
            top: 82,
            left: 175,
            size: 48,
            color: const Color(0xFFD6C7FF).withOpacity(0.7),
          ),
          backgroundShape(
            top: 105,
            right: 70,
            size: 72,
            color: const Color(0xFFFFD7D2).withOpacity(0.6),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF2F80ED),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 35),
                    topDecorationLogo(),
                    const SizedBox(height: 28),
                    const Text(
                      'Doctor Register',
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create your doctor account',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: nameController,
                      decoration: underlineDecoration('DOCTOR NAME'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: underlineDecoration('EMAIL'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter email';
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: bmdcController,
                      decoration: underlineDecoration('BMDC CODE'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter BMDC code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: underlineDecoration(
                        'PASSWORD',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter password';
                        }
                        if (!passwordRegex.hasMatch(value)) {
                          return 'Password must meet the required format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '8 characters minimum, with at least 1 special character and 1 number',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: underlineDecoration(
                        'CONFIRM PASSWORD',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm password';
                        }
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : registerDoctor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F80ED),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor:
                          const Color(0xFF2F80ED).withOpacity(0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          isLoading ? 'PLEASE WAIT...' : 'REGISTER',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Already have an account? Sign in',
                          style: TextStyle(
                            color: Color(0xFF2F80ED),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}