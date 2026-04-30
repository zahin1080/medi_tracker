import 'package:flutter/material.dart';
import 'package:medi_tracker/basicloginpage.dart';
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
      );

      final user = authResponse.user;

      if (user == null) {
        throw Exception('Doctor account could not be created');
      }

      await supabase.from('user_profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        'role': 'doctor',
        'account_status': 'active',
        'profile_completion_status': false,
        'is_active': true,
      });

      await supabase.from('doctor_profiles').insert({
        'user_id': user.id,
        'phone': null, // explicitly null
        'bmdc_code': bmdcCode,
        'mbbs_completion_campus': null,
        'specialization': null,
        'additional_degrees': <String>[],
        'chamber_information': null,
        'availability_status': 'not_available',
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Doctor registration completed successfully.'),
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
        borderSide: BorderSide(color: Color(0xFF8E6FF7), width: 2),
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
                color: Color(0xFF8E6FF7),
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
                color: Color(0xFF9B82F7),
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
                color: const Color(0xFF7B5EF2).withOpacity(0.65),
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
                color: Color(0xFF7B5EF2),
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 25),

                    topDecorationLogo(),

                    const SizedBox(height: 28),

                    const Text(
                      'Doctor Register',
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 30),

                    TextFormField(
                      controller: nameController,
                      decoration: underlineDecoration('DOCTOR NAME'),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: emailController,
                      decoration: underlineDecoration('EMAIL'),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: underlineDecoration(
                        'PASSWORD',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      '8 characters minimum, with at least 1 special character and 1 number',
                      style: TextStyle(fontSize: 12),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: underlineDecoration('CONFIRM PASSWORD'),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: bmdcController,
                      decoration: underlineDecoration('BMDC CODE'),
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: isLoading ? null : registerDoctor,
                      child: const Text('REGISTER'),
                    ),

                    const SizedBox(height: 20),
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
