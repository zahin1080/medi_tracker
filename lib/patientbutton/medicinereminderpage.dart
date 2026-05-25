import 'dart:async';

import 'package:entrig/entrig.dart';
import 'package:flutter/material.dart';
import 'package:medi_tracker/supabase_config.dart';

class MedicineReminderPage extends StatefulWidget {
  const MedicineReminderPage({super.key});

  @override
  State<MedicineReminderPage> createState() => _MedicineReminderPageState();
}

class _MedicineReminderPageState extends State<MedicineReminderPage> {
  bool isLoading = false;
  bool isSaving = false;

  StreamSubscription<dynamic>? entrigNotificationSubscription;

  List<Map<String, dynamic>> medicines = [];
  List<Map<String, dynamic>> reminders = [];
  List<Map<String, dynamic>> notificationLogs = [];

  Map<String, dynamic>? selectedMedicine;
  TimeOfDay? selectedTime;

  final activeDaysController = TextEditingController();
  final totalDosesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    registerDeviceForEntrig();
    listenToEntrigNotificationTap();
    fetchData();
  }

  @override
  void dispose() {
    entrigNotificationSubscription?.cancel();
    activeDaysController.dispose();
    totalDosesController.dispose();
    super.dispose();
  }

  Future<void> registerDeviceForEntrig() async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      await Entrig.register(
        userId: currentUser.id,
      );
    } catch (e) {
      showMessage('Failed to register push notification: $e');
    }
  }

  void listenToEntrigNotificationTap() {
    entrigNotificationSubscription =
        Entrig.onNotificationOpened.listen((event) async {
          if (!mounted) return;

          if (event.type == 'medicine_reminder') {
            await fetchData();

            if (!mounted) return;

            await showNotificationLogsDialog();
          }
        });
  }

  int unseenNotificationCount() {
    return notificationLogs.where((log) {
      return log['is_seen'] == false;
    }).length;
  }

  Future<void> fetchData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final medicineData = await supabase
          .from('medicine_inventory')
          .select()
          .eq('patient_user_id', currentUser.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final reminderData = await supabase
          .from('medicine_reminder_schedules')
          .select(
        '*, medicine_inventory(medicine_name, dose_power, current_stock)',
      )
          .eq('patient_user_id', currentUser.id)
          .order('created_at', ascending: false);

      final logsData = await supabase
          .from('notification_logs')
          .select()
          .eq('patient_user_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        medicines = List<Map<String, dynamic>>.from(medicineData);
        reminders = List<Map<String, dynamic>>.from(reminderData);
        notificationLogs = List<Map<String, dynamic>>.from(logsData);
      });
    } catch (e) {
      showMessage('Failed to load data: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> selectReminderTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> addReminder() async {
    if (selectedMedicine == null) {
      showMessage('Please select a medicine');
      return;
    }

    if (selectedTime == null) {
      showMessage('Please select reminder time');
      return;
    }

    final activeDays = int.tryParse(activeDaysController.text.trim());
    final totalDoses = int.tryParse(totalDosesController.text.trim());

    if (activeDays == null || activeDays <= 0) {
      showMessage('Enter valid active days');
      return;
    }

    if (totalDoses == null || totalDoses <= 0) {
      showMessage('Enter valid total doses');
      return;
    }

    if (!mounted) return;

    setState(() {
      isSaving = true;
    });

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      await supabase.from('medicine_reminder_schedules').insert({
        'patient_user_id': currentUser.id,
        'medicine_inventory_id': selectedMedicine!['id'],
        'reminder_time': formatTime(selectedTime!),
        'active_days': activeDays,
        'total_doses': totalDoses,
        'taken_doses': 0,
        'missed_doses': 0,
        'start_date': DateTime.now().toIso8601String().substring(0, 10),
        'is_active': true,
      });

      selectedMedicine = null;
      selectedTime = null;
      activeDaysController.clear();
      totalDosesController.clear();

      await fetchData();

      showMessage(
        'Reminder created. Push notification will be sent at reminder time.',
      );
    } catch (e) {
      showMessage('Failed to create reminder: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> markAllNotificationsSeen() async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      await supabase
          .from('notification_logs')
          .update({'is_seen': true})
          .eq('patient_user_id', currentUser.id);

      await fetchData();
    } catch (e) {
      showMessage('Failed to update notifications: $e');
    }
  }

  Future<void> confirmMedicineTaken(Map<String, dynamic> reminder) async {
    try {
      final medicine = reminder['medicine_inventory'];

      if (medicine == null) {
        showMessage('Medicine details not found');
        return;
      }

      final currentStock = medicine['current_stock'] ?? 0;

      if (currentStock <= 0) {
        showMessage('No stock available for this medicine');
        return;
      }

      final newStock = currentStock - 1;
      final newTakenDoses = (reminder['taken_doses'] ?? 0) + 1;
      final totalDoses = reminder['total_doses'] ?? 0;
      final isFinished = newTakenDoses >= totalDoses;

      await supabase
          .from('medicine_inventory')
          .update({'current_stock': newStock})
          .eq('id', reminder['medicine_inventory_id']);

      await supabase.from('medicine_reminder_schedules').update({
        'taken_doses': newTakenDoses,
        'is_active': isFinished ? false : true,
      }).eq('id', reminder['id']);

      await supabase
          .from('notification_logs')
          .update({
        'is_taken': true,
        'is_seen': true,
      })
          .eq('reminder_id', reminder['id']);

      await fetchData();

      showMessage('Medicine marked as taken');
    } catch (e) {
      showMessage('Failed to confirm dose: $e');
    }
  }

  Future<void> markMedicineNotTaken(Map<String, dynamic> log) async {
    try {
      await supabase
          .from('notification_logs')
          .update({
        'is_taken': false,
        'is_seen': true,
      })
          .eq('id', log['id']);

      await fetchData();

      showMessage('Medicine marked as not taken');
    } catch (e) {
      showMessage('Failed to update notification: $e');
    }
  }

  Future<void> deleteReminder(Map<String, dynamic> reminder) async {
    try {
      await supabase
          .from('notification_logs')
          .delete()
          .eq('reminder_id', reminder['id']);

      await supabase
          .from('medicine_reminder_schedules')
          .delete()
          .eq('id', reminder['id']);

      await fetchData();

      showMessage('Reminder deleted');
    } catch (e) {
      showMessage('Failed to delete reminder: $e');
    }
  }

  void confirmDeleteReminder(Map<String, dynamic> reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Do you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteReminder(reminder);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> showNotificationLogsDialog() async {
    await markAllNotificationsSeen();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reminder Notifications'),
          content: notificationLogs.isEmpty
              ? const Text('No notification messages available.')
              : SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: notificationLogs.length,
              itemBuilder: (context, index) {
                final log = notificationLogs[index];
                final isTaken = log['is_taken'] == true;

                return ListTile(
                  leading: Icon(
                    isTaken
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: isTaken ? Colors.green : Colors.orange,
                  ),
                  title: Text(log['title'] ?? 'Medicine Reminder'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['body'] ?? ''),
                      if (log['due_date'] != null ||
                          log['due_time'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Due: ${log['due_date'] ?? ''} ${log['due_time'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isTaken
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isTaken ? 'Taken' : 'Not Taken',
                      style: TextStyle(
                        color: isTaken ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    await fetchData();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color getStatusColor(bool isActive) {
    return isActive ? const Color(0xFF7B5EF2) : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final unseenCount = unseenNotificationCount();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          'Medicine Reminder',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8E6FF7),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                ),
                onPressed: showNotificationLogsDialog,
              ),
              if (unseenCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unseenCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDE8FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Reminder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedMedicine,
                  decoration: const InputDecoration(
                    labelText: 'Select Medicine',
                    border: OutlineInputBorder(),
                  ),
                  items: medicines.map((medicine) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: medicine,
                      child: Text(
                        '${medicine['medicine_name']} (${medicine['dose_power']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMedicine = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: selectReminderTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    selectedTime == null
                        ? 'Select Reminder Time'
                        : 'Time: ${selectedTime!.format(context)}',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: activeDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Active for how many days?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: totalDosesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total number of doses',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : addReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E6FF7),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isSaving ? 'Saving...' : 'Create Reminder',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Your Reminders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (reminders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No reminders created yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ...reminders.map((reminder) {
            final medicine = reminder['medicine_inventory'];
            final isActive = reminder['is_active'] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEDE8FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                        getStatusColor(isActive).withOpacity(0.12),
                        child: Icon(
                          Icons.alarm,
                          color: getStatusColor(isActive),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          medicine?['medicine_name'] ?? 'Medicine',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        isActive ? 'Active' : 'Finished',
                        style: TextStyle(
                          color: getStatusColor(isActive),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Dose: ${medicine?['dose_power'] ?? ''}'),
                  Text('Stock: ${medicine?['current_stock'] ?? 0}'),
                  Text('Reminder Time: ${reminder['reminder_time']}'),
                  Text(
                    'Taken: ${reminder['taken_doses']} / ${reminder['total_doses']}',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isActive
                              ? () {
                            confirmMedicineTaken(reminder);
                          }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E6FF7),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Taken'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            confirmDeleteReminder(reminder);
                          },
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}