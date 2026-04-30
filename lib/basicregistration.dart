import 'package:flutter/material.dart';
import 'basicloginpage.dart';
import 'patientregpage.dart';
import 'doctorregpage.dart';

class RSelectionPage extends StatefulWidget {
  const RSelectionPage({super.key});

  @override
  State<RSelectionPage> createState() => _RSelectionPageState();
}

class _RSelectionPageState extends State<RSelectionPage> {
  int selectedValue = 1;

  void _continueRegistration() {
    if (selectedValue == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PatientRegPage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DoctorRegPage()),
      );
    }
  }

  Widget roleCard({
    required int value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = selectedValue == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedValue = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8E6FF7) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8E6FF7)
                : const Color(0xFFE7E2FF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF8E6FF7).withOpacity(0.25)
                  : Colors.black12.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isSelected
                  ? Colors.white.withOpacity(0.22)
                  : const Color(0xFF8E6FF7).withOpacity(0.12),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF8E6FF7),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white70 : Colors.grey,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.white : const Color(0xFF8E6FF7),
            ),
          ],
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
          Positioned(
            top: -40,
            left: -40,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDEBE4).withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            top: -30,
            right: 45,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 115,
                height: 115,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFF).withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            top: 55,
            right: 30,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9EDE5).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          Positioned(
            top: 82,
            left: 175,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6C7FF).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          Positioned(
            top: 105,
            right: 70,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD7D2).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 95),

                  SizedBox(
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
                              borderRadius: const BorderRadius.all(
                                Radius.circular(30),
                              ),
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
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select your role to continue',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 40),

                  roleCard(
                    value: 1,
                    title: 'Patient',
                    subtitle:
                        'Register to manage medicines, prescriptions, and consultations.',
                    icon: Icons.person_outline,
                  ),

                  roleCard(
                    value: 2,
                    title: 'Doctor',
                    subtitle:
                        'Register to manage profile, availability, and patient requests.',
                    icon: Icons.medical_services_outlined,
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _continueRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E6FF7),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF8E6FF7).withOpacity(0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
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
                          color: Color(0xFF7B5EF2),
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
        ],
      ),
    );
  }
}
