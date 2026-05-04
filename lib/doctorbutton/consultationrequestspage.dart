import 'package:flutter/material.dart';
import 'package:medi_tracker/supabase_config.dart';

class ConsultationRequestsPage extends StatefulWidget {
  const ConsultationRequestsPage({super.key});

  @override
  State<ConsultationRequestsPage> createState() =>
      _ConsultationRequestsPageState();
}

class _ConsultationRequestsPageState extends State<ConsultationRequestsPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('Doctor is not logged in');
      }

      final data = await supabase
          .from('consultation_requests')
          .select('''
            id,
            patient_user_id,
            doctor_user_id,
            status,
            zoom_meeting_link,
            created_at,
            user_profiles!consultation_requests_patient_user_id_fkey(full_name, email)
          ''')
          .eq('doctor_user_id', currentUser.id)
          .order('created_at', ascending: false);

      setState(() {
        requests = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      showMessage('Failed to load requests: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> request) async {
    try {
      await supabase.from('consultation_requests').update({
        'status': 'accepted',
      }).eq('id', request['id']);

      await fetchRequests();
      showMessage('Request accepted. Patient will join the meeting.');
    } catch (e) {
      showMessage('Failed to accept request: $e');
    }
  }

  Future<void> rejectRequest(Map<String, dynamic> request) async {
    try {
      await supabase.from('consultation_requests').update({
        'status': 'rejected',
      }).eq('id', request['id']);

      await fetchRequests();
      showMessage('Request rejected');
    } catch (e) {
      showMessage('Failed to reject request: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color statusColor(String status) {
    if (status == 'accepted') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text(
          'Consultation Requests',
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
          : requests.isEmpty
          ? const Center(
        child: Text(
          'No consultation request yet',
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          final patient = request['user_profiles'];
          final status = request['status'] ?? 'pending';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient?['full_name'] ?? 'Unknown Patient',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Email: ${patient?['email'] ?? 'Not found'}'),
                const SizedBox(height: 8),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    color: statusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            acceptRequest(request);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F80ED),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            rejectRequest(request);
                          },
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}