import 'package:flutter/material.dart';
import 'package:medi_tracker/authentications/basicloginpage.dart';
import 'package:medi_tracker/patientbutton/medicineinventorypage.dart';
import 'package:medi_tracker/patientbutton/uploadprescriptionpage.dart';
import 'package:medi_tracker/patientbutton/medicinereminderpage.dart';
import 'package:medi_tracker/patientbutton/doctorsinfopage.dart';
import 'package:medi_tracker/supabase_config.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  bool _isDialogOpen = false;

  Future<void> logout(BuildContext context) async {
    await supabase.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  void confirmLogout(BuildContext context) {
    if (_isDialogOpen) return;

    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Do you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                _isDialogOpen = false;
                Navigator.pop(dialogContext);
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                _isDialogOpen = false;
                Navigator.pop(dialogContext);
                await logout(context);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_DashboardItem> items = [
      _DashboardItem(
        title: 'Track Medicine',
        subtitle: 'Monitor stock',
        icon: Icons.inventory_2_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MedicineInventoryPage(),
            ),
          );
        },
      ),
      _DashboardItem(
        title: 'Medicine Reminder',
        subtitle: 'Set alerts',
        icon: Icons.alarm,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MedicineReminderPage(),
            ),
          );
        },
      ),
      _DashboardItem(
        title: 'Upload Prescription',
        subtitle: 'Store records',
        icon: Icons.upload_file_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadPrescriptionPage(),
            ),
          );
        },
      ),
      _DashboardItem(
        title: 'Doctors Info',
        subtitle: 'View doctors',
        icon: Icons.medical_information_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorsInfoPage(),
            ),
          );
        },
      ),

    ];

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        return;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F7FF),

        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              expandedHeight: 200,
              elevation: 0,
              backgroundColor: const Color(0xFF8E6FF7),
              title: const Text(
                'Medi-Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,

              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.account_circle,
                      color: Colors.green,
                      size: 30,
                    ),
                    onSelected: (value) {
                      if (value == 'logout') {
                        confirmLogout(context);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8E6FF7), Color(0xFF7B5EF2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Patient Home',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Manage your medicines, prescriptions, and consultations from one place.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final item = items[index];

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: item.onTap,
                      child: Container(
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
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                const Color(0xFF8E6FF7).withOpacity(0.12),
                                child: Icon(
                                  item.icon,
                                  size: 30,
                                  color: const Color(0xFF7B5EF2),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}