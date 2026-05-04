import 'package:flutter/material.dart';
import 'package:medi_tracker/basicloginpage.dart';
import 'package:medi_tracker/doctorbutton/doctorprofilepage.dart';

class DoctorHomePage extends StatelessWidget {
  const DoctorHomePage({super.key});

  void logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  void confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              logout(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_DoctorDashboardItem> items = [
      _DoctorDashboardItem(
        title: 'Update Profile',
        subtitle: 'Edit details',
        icon: Icons.person_outline,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DoctorProfilePage()),
          );
        },
      ),
      _DoctorDashboardItem(
        title: 'Consultation Requests',
        subtitle: 'View requests',
        icon: Icons.assignment_outlined,
        onTap: () {},
      ),
      _DoctorDashboardItem(
        title: 'Patient Prescriptions',
        subtitle: 'Review records',
        icon: Icons.description_outlined,
        onTap: () {},
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        confirmLogout(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              expandedHeight: 200,
              elevation: 0,
              backgroundColor: const Color(0xFF2F80ED),
              title: const Text(
                'Medi-Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,

              // 🔥 UPDATED LOGOUT UI HERE
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => confirmLogout(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2F80ED), Color(0xFF1C5FD4)],
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
                            'Doctor Home',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Manage your profile, consultation flow, and patient interactions from one place.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.3,
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: item.onTap,
                    child: Container(
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
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                              const Color(0xFF2F80ED).withOpacity(0.12),
                              child: Icon(
                                item.icon,
                                size: 30,
                                color: const Color(0xFF1C5FD4),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111111),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: items.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

class _DoctorDashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _DoctorDashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}