import 'dart:async';

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

  Timer? reminderCheckerTimer;

  List<Map<String, dynamic>> medicines = [];
  List<Map<String, dynamic>> reminders = [];

  Map<String, dynamic>? selectedMedicine;
  TimeOfDay? selectedTime;

  final activeDaysController = TextEditingController();
  final totalDosesController = TextEditingController();

  final Set<String> alreadyShownToday = {};

  @override
  void initState() {
    super.initState();
    fetchData();

    reminderCheckerTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      checkDueReminders();
    });
  }

  @override
  void dispose() {
    reminderCheckerTimer?.cancel();
    activeDaysController.dispose();
    totalDosesController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
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

      setState(() {
        medicines = List<Map<String, dynamic>>.from(medicineData);
        reminders = List<Map<String, dynamic>>.from(reminderData);
      });
    } catch (e) {
      showMessage('Failed to load data: $e');
    } finally {
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
        'is_active': true,
      });

      selectedMedicine = null;
      selectedTime = null;
      activeDaysController.clear();
      totalDosesController.clear();

      await fetchData();
      showMessage('Reminder created successfully');
    } catch (e) {
      showMessage('Failed to create reminder: $e');
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  void checkDueReminders() {
    if (!mounted || reminders.isEmpty) return;

    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final reminder in reminders) {
      final isActive = reminder['is_active'] ?? false;
      if (!isActive) continue;

      final reminderTime = reminder['reminder_time'] ?? '';
      if (!reminderTime.contains(':')) continue;

      final parts = reminderTime.split(':');
      final reminderHour = int.tryParse(parts[0]);
      final reminderMinute = int.tryParse(parts[1]);

      if (reminderHour == null || reminderMinute == null) continue;

      final dueTime = DateTime(
        now.year,
        now.month,
        now.day,
        reminderHour,
        reminderMinute,
      );

      final difference = now.difference(dueTime).inSeconds;

      final uniqueKey = '${reminder['id']}-$todayKey';

      if (difference >= 0 &&
          difference <= 300 &&
          !alreadyShownToday.contains(uniqueKey)) {
        alreadyShownToday.add(uniqueKey);
        showReminderDialog(reminder);
      }
    }
  }

  void showReminderDialog(Map<String, dynamic> reminder) {
    final medicine = reminder['medicine_inventory'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Timer(const Duration(minutes: 5), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
            showMessage(
              'You have missed your medicine: ${medicine?['medicine_name'] ?? 'Medicine'}',
            );
          }
        });

        return AlertDialog(
          title: const Text('Medicine Reminder'),
          content: Text(
            'Time to take ${medicine?['medicine_name'] ?? 'your medicine'} (${medicine?['dose_power'] ?? ''}).',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                confirmMedicineTaken(reminder);
              },
              child: const Text('I have taken it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> confirmMedicineTaken(Map<String, dynamic> reminder) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final medicine = reminder['medicine_inventory'];
      final currentStock = medicine['current_stock'] ?? 0;

      if (currentStock <= 0) {
        showMessage('No stock available for this medicine');
        return;
      }

      final newStock = currentStock - 1;
      final newTakenDoses = (reminder['taken_doses'] ?? 0) + 1;
      final totalDoses = reminder['total_doses'] ?? 0;

      await supabase
          .from('medicine_inventory')
          .update({'current_stock': newStock})
          .eq('id', reminder['medicine_inventory_id']);

      await supabase
          .from('medicine_reminder_schedules')
          .update({
            'taken_doses': newTakenDoses,
            'is_active': newTakenDoses >= totalDoses ? false : true,
          })
          .eq('id', reminder['id']);

      await fetchData();
      showMessage('Medicine marked as taken');
    } catch (e) {
      showMessage('Failed to confirm dose: $e');
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await supabase.from('medicine_reminder_schedules').delete().eq('id', id);

      await fetchData();
      showMessage('Reminder deleted');
    } catch (e) {
      showMessage('Failed to delete reminder: $e');
    }
  }

  void confirmDeleteReminder(String id) {
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
              deleteReminder(id);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color getStatusColor(bool isActive) {
    return isActive ? const Color(0xFF7B5EF2) : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          'Medicine Reminder',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8E6FF7),
        iconTheme: const IconThemeData(color: Colors.white),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              backgroundColor: getStatusColor(
                                isActive,
                              ).withOpacity(0.12),
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
                                  confirmDeleteReminder(reminder['id']);
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
