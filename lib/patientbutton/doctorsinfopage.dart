import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medi_tracker/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorsInfoPage extends StatefulWidget {
  const DoctorsInfoPage({super.key});

  @override
  State<DoctorsInfoPage> createState() => _DoctorsInfoPageState();
}

class _DoctorsInfoPageState extends State<DoctorsInfoPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> doctors = [];

  StreamSubscription? requestSubscription;

  @override
  void initState() {
    super.initState();
    fetchDoctors();
    listenForAcceptedRequests();
  }

  @override
  void dispose() {
    requestSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchDoctors() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await supabase.rpc('get_doctors_for_patient');

      final mergedDoctors =
      List<Map<String, dynamic>>.from(data).map((doctor) {
        doctor['doctor_name'] = doctor['full_name'] ?? 'Unknown Doctor';
        doctor['doctor_email'] = doctor['email'] ?? 'Not added';

        return doctor;
      }).toList();

      setState(() {
        doctors = mergedDoctors;
      });
    } catch (e) {
      showMessage('Failed to load doctors: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void listenForAcceptedRequests() {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    requestSubscription = supabase
        .from('consultation_requests')
        .stream(primaryKey: ['id'])
        .eq('patient_user_id', currentUser.id)
        .listen((requests) {
      for (final request in requests) {
        if (request['status'] == 'accepted' &&
            request['zoom_meeting_link'] != null &&
            request['zoom_meeting_link'].toString().isNotEmpty) {
          openZoomLink(request['zoom_meeting_link']);
        }
      }
    });
  }

  Future<void> sendConsultationRequest(Map<String, dynamic> doctor) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        showMessage('User is not logged in');
        return;
      }

      await supabase.from('consultation_requests').insert({
        'patient_user_id': currentUser.id,
        'doctor_user_id': doctor['user_id'],
        'status': 'pending',
        'zoom_meeting_link': doctor['zoom_meeting_link'],
      });

      showMessage('Consultation request sent to doctor');
    } catch (e) {
      showMessage('Failed to send request: $e');
    }
  }

  Future<void> openZoomLink(String link) async {
    final uri = Uri.parse(link);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      showMessage('Could not open Zoom meeting link');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String listToText(dynamic value) {
    if (value == null) return 'Not added';

    if (value is List && value.isNotEmpty) {
      return value.join(', ');
    }

    return 'Not added';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          'Doctors Information',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF8E6FF7),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctors.isEmpty
          ? const Center(
        child: Text(
          'No doctor found',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          final doctorName =
              doctor['doctor_name'] ?? 'Unknown Doctor';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDE8FF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                      const Color(0xFF8E6FF7).withOpacity(0.12),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF7B5EF2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        doctorName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Specialization: ${doctor['specialization'] ?? 'Not added'}',
                ),
                Text(
                  'MBBS Institution: ${doctor['mbbs_completion_campus'] ?? 'Not added'}',
                ),
                Text(
                  'Degrees: ${listToText(doctor['additional_degrees'])}',
                ),
                Text(
                  'Appointment Number: ${doctor['phone'] ?? 'Not added'}',
                ),
                Text(
                  'Chamber Address: ${listToText(doctor['chamber_addresses'])}',
                ),
                Text(
                  'Available Days: ${listToText(doctor['available_days'])}',
                ),
                Text(
                  'Time: ${doctor['availability_start_time'] ?? 'Not set'} - ${doctor['availability_end_time'] ?? 'Not set'}',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      sendConsultationRequest(doctor);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E6FF7),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.video_call),
                    label: const Text('Book Consultant'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}