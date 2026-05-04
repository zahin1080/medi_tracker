import 'package:flutter/material.dart';
import 'package:medi_tracker/supabase_config.dart';

class PatientPrescriptionsPage extends StatefulWidget {
  const PatientPrescriptionsPage({super.key});

  @override
  State<PatientPrescriptionsPage> createState() =>
      _PatientPrescriptionsPageState();
}

class _PatientPrescriptionsPageState extends State<PatientPrescriptionsPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> patients = [];

  @override
  void initState() {
    super.initState();
    fetchAcceptedPatients();
  }

  Future<void> fetchAcceptedPatients() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await supabase.rpc('get_accepted_patients_for_doctor');

      setState(() {
        patients = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      showMessage('Failed to load patients: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openPatientPrescriptions(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientPrescriptionImagesPage(
          patientUserId: patient['patient_user_id'],
          patientName: patient['patient_name'] ?? 'Unknown Patient',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text(
          'Patient Prescriptions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2F80ED),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : patients.isEmpty
          ? const Center(
        child: Text(
          'No accepted consultation patients yet',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: patients.length,
        itemBuilder: (context, index) {
          final patient = patients[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2ECFF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor:
                const Color(0xFF2F80ED).withOpacity(0.12),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF1C5FD4),
                ),
              ),
              title: Text(
                patient['patient_name'] ?? 'Unknown Patient',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                patient['patient_email'] ?? 'Email not found',
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Color(0xFF1C5FD4),
              ),
              onTap: () {
                openPatientPrescriptions(patient);
              },
            ),
          );
        },
      ),
    );
  }
}

class PatientPrescriptionImagesPage extends StatefulWidget {
  final String patientUserId;
  final String patientName;

  const PatientPrescriptionImagesPage({
    super.key,
    required this.patientUserId,
    required this.patientName,
  });

  @override
  State<PatientPrescriptionImagesPage> createState() =>
      _PatientPrescriptionImagesPageState();
}

class _PatientPrescriptionImagesPageState
    extends State<PatientPrescriptionImagesPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> prescriptions = [];

  @override
  void initState() {
    super.initState();
    fetchPrescriptions();
  }

  Future<void> fetchPrescriptions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await supabase.rpc(
        'get_patient_prescriptions_for_doctor',
        params: {
          'target_patient_id': widget.patientUserId,
        },
      );

      setState(() {
        prescriptions = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      showMessage('Failed to load prescriptions: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenPrescriptionImage(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: Text(
          widget.patientName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2F80ED),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : prescriptions.isEmpty
          ? const Center(
        child: Text(
          'No prescriptions uploaded by this patient',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prescriptions.length,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final prescription = prescriptions[index];
          final imageUrl = prescription['image_url'] ?? '';

          return GestureDetector(
            onTap: () {
              openFullScreenImage(imageUrl);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border:
                Border.all(color: const Color(0xFFE2ECFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 45,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FullScreenPrescriptionImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenPrescriptionImage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'Unable to load image',
                style: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}