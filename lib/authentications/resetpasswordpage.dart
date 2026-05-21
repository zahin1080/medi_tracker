import 'package:flutter/material.dart';
import 'package:medi_tracker/authentications/basicloginpage.dart';
import 'package:medi_tracker/main.dart';
import 'package:medi_tracker/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (newPasswordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      showMessage('Passwords do not match');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: newPasswordController.text.trim(),
        ),
      );

      isResetPasswordFlow = false;

      await supabase.auth.signOut();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Password updated successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                      (route) => false,
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showMessage('Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration inputDecoration(
      String label,
      bool obscure,
      VoidCallback toggle,
      ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
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
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
        ),
      ),
    );
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter new password';
    }

    final passwordRegex = RegExp(
      r'^(?=.*[0-9])(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$',
    );

    if (!passwordRegex.hasMatch(value)) {
      return 'Minimum 8 characters, 1 number, 1 special character';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8E6FF7),
        foregroundColor: Colors.white,
        title: const Text('Reset Password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFEDE8FF),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Color(0xFF8E6FF7),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Create New Password',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: inputDecoration(
                      'NEW PASSWORD',
                      obscureNewPassword,
                          () {
                        setState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '8 characters minimum, with at least 1 special character and 1 number',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: inputDecoration(
                      'CONFIRM PASSWORD',
                      obscureConfirmPassword,
                          () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      }

                      if (value != newPasswordController.text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E6FF7),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isLoading ? 'PLEASE WAIT...' : 'UPDATE PASSWORD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}