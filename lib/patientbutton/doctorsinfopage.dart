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

  final Set<String> sentDoctorIds = {};
  final Set<String> acceptedDoctorIds = {};
  final Set<String> openedAcceptedRequestIds = {};
  final Set<String> openedAcceptedDoctorIds = {};

  final Map<String, String> previousRequestStatus = {};

  bool isInitialRequestSnapshot = true;

  @override
  void initState() {
    super.initState();
    initializePage();
  }

  Future<void> initializePage() async {
    await fetchDoctors();
    listenForConsultationRequests();
  }

  @override
  void dispose() {
    requestSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchDoctors() async {
    if (!mounted) return;

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

      if (!mounted) return;

      setState(() {
        doctors = mergedDoctors;
      });
    } catch (e) {
      showMessage('Failed to load doctors: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void listenForConsultationRequests() {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    requestSubscription?.cancel();

    requestSubscription = supabase
        .from('consultation_requests')
        .stream(primaryKey: ['id'])
        .eq('patient_user_id', currentUser.id)
        .listen(
          (requests) {
        bool needRefresh = false;

        for (final request in requests) {
          final requestId = request['id']?.toString();
          final doctorId = request['doctor_user_id']?.toString();
          final status = request['status']?.toString();

          if (requestId == null || doctorId == null || status == null) {
            continue;
          }

          final oldStatus = previousRequestStatus[requestId];

          if (status == 'pending') {
            sentDoctorIds.add(doctorId);
            needRefresh = true;
          }

          if (status == 'accepted') {
            sentDoctorIds.add(doctorId);
            acceptedDoctorIds.add(doctorId);
            needRefresh = true;

            final bool becameAccepted =
                !isInitialRequestSnapshot && oldStatus != 'accepted';

            final bool notOpenedBefore =
                !openedAcceptedRequestIds.contains(requestId) &&
                    !openedAcceptedDoctorIds.contains(doctorId);

            if (becameAccepted && notOpenedBefore) {
              openedAcceptedRequestIds.add(requestId);
              openedAcceptedDoctorIds.add(doctorId);

              final doctor = findDoctorById(doctorId);
              final calendlyLink = doctor?['calendly_link'];

              if (calendlyLink != null &&
                  calendlyLink.toString().trim().isNotEmpty) {
                openCalendlyLink(calendlyLink.toString());
              } else {
                showMessage('Calendly link is not available for this doctor');
              }
            }
          }

          previousRequestStatus[requestId] = status;
        }

        isInitialRequestSnapshot = false;

        if (mounted && needRefresh) {
          setState(() {});
        }
      },
      onError: (error) {
        showMessage('Request listener error: $error');
      },
    );
  }

  Map<String, dynamic>? findDoctorById(String doctorId) {
    try {
      return doctors.firstWhere(
            (doctor) => doctor['user_id'].toString() == doctorId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> sendConsultationRequest(Map<String, dynamic> doctor) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        showMessage('User is not logged in');
        return;
      }

      final doctorUserId = doctor['user_id']?.toString();

      if (doctorUserId == null || doctorUserId.isEmpty) {
        showMessage('Doctor ID not found');
        return;
      }

      if (acceptedDoctorIds.contains(doctorUserId)) {
        final calendlyLink = doctor['calendly_link'];

        if (calendlyLink != null &&
            calendlyLink.toString().trim().isNotEmpty) {
          await openCalendlyLink(calendlyLink.toString());
        } else {
          showMessage('Calendly link is not available');
        }

        return;
      }

      if (sentDoctorIds.contains(doctorUserId)) {
        showMessage('Consultation request already sent. Please wait for doctor approval.');
        return;
      }

      final existingData = await supabase
          .from('consultation_requests')
          .select('id, status, doctor_user_id')
          .eq('patient_user_id', currentUser.id)
          .eq('doctor_user_id', doctorUserId)
          .limit(1);

      final existingRequests = List<Map<String, dynamic>>.from(existingData);

      if (existingRequests.isNotEmpty) {
        final existingStatus = existingRequests.first['status']?.toString();

        sentDoctorIds.add(doctorUserId);

        if (existingStatus == 'accepted') {
          acceptedDoctorIds.add(doctorUserId);

          if (mounted) {
            setState(() {});
          }

          final calendlyLink = doctor['calendly_link'];

          if (calendlyLink != null &&
              calendlyLink.toString().trim().isNotEmpty) {
            await openCalendlyLink(calendlyLink.toString());
          } else {
            showMessage('Calendly link is not available');
          }

          return;
        }

        if (mounted) {
          setState(() {});
        }

        showMessage('Consultation request already sent. Please wait for doctor approval.');
        return;
      }

      final doctorName = doctor['doctor_name'] ?? 'Unknown Doctor';

      await supabase.from('consultation_requests').insert({
        'patient_user_id': currentUser.id,
        'doctor_user_id': doctorUserId,
        'status': 'pending',
        'zoom_meeting_link': doctor['zoom_meeting_link'],
      });

      if (!mounted) return;

      setState(() {
        sentDoctorIds.add(doctorUserId);
      });

      showMessage(
        'Consultation request sent to $doctorName. Calendly link will open after doctor accepts.',
      );
    } catch (e) {
      showMessage('Failed to send request: $e');
    }
  }

  Future<void> openCalendlyLink(dynamic link) async {
    try {
      if (link == null || link.toString().trim().isEmpty) {
        showMessage('Calendly link is not available');
        return;
      }

      String fixedLink = link.toString().trim();

      if (!fixedLink.startsWith('http://') &&
          !fixedLink.startsWith('https://')) {
        fixedLink = 'https://$fixedLink';
      }

      final Uri uri = Uri.parse(fixedLink);

      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        showMessage('Could not open Calendly link');
      }
    } catch (e) {
      showMessage('Could not open Calendly link: $e');
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

          final doctorUserId = doctor['user_id'].toString();

          final bool isSent =
          sentDoctorIds.contains(doctorUserId);

          final bool isAccepted =
          acceptedDoctorIds.contains(doctorUserId);

          final bool canOpenCalendly = isAccepted;

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
                      backgroundColor: const Color(0xFF8E6FF7)
                          .withOpacity(0.12),
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
                    onPressed: isSent || isAccepted
                        ? null
                        : () {
                      sendConsultationRequest(doctor);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSent || isAccepted
                          ? Colors.grey
                          : const Color(0xFF8E6FF7),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.video_call),
                    label: Text(
                      isAccepted
                          ? 'Request Accepted'
                          : isSent
                          ? 'Request Sent'
                          : 'Book Consultant',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canOpenCalendly
                        ? () {
                      openCalendlyLink(
                        doctor['calendly_link'],
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canOpenCalendly
                          ? const Color(0xFF8E6FF7)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Calendly Link'),
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