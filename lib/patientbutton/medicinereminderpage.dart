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

  int safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  int? parseActiveDays() {
    final value = int.tryParse(activeDaysController.text.trim());

    if (value == null || value <= 0) return null;

    return value;
  }

  int? parseTotalDoses() {
    final value = int.tryParse(totalDosesController.text.trim());

    if (value == null || value <= 0) return null;

    return value;
  }

  int getMedicineStock(Map<String, dynamic>? medicine) {
    return safeInt(medicine?['current_stock']);
  }

  String getMedicineName(Map<String, dynamic>? medicine) {
    return medicine?['medicine_name']?.toString() ?? 'Medicine';
  }

  String getMedicineDose(Map<String, dynamic>? medicine) {
    return medicine?['dose_power']?.toString() ?? '';
  }

  bool hasCompletePlanInput() {
    return selectedMedicine != null &&
        selectedTime != null &&
        parseActiveDays() != null &&
        parseTotalDoses() != null;
  }

  bool isPlanStockEnough() {
    if (!hasCompletePlanInput()) return false;

    final currentStock = getMedicineStock(selectedMedicine);
    final totalDoses = parseTotalDoses() ?? 0;

    return currentStock >= totalDoses;
  }

  String dailyDosePlanText(int totalDoses, int activeDays) {
    if (totalDoses <= 0 || activeDays <= 0) return 'Not ready';

    final dosePerDay = totalDoses / activeDays;

    if (dosePerDay == dosePerDay.roundToDouble()) {
      return '${dosePerDay.toInt()} per day';
    }

    return '${dosePerDay.toStringAsFixed(1)} per day';
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

    final activeDays = parseActiveDays();
    final totalDoses = parseTotalDoses();

    if (activeDays == null) {
      showMessage('Enter valid active days');
      return;
    }

    if (totalDoses == null) {
      showMessage('Enter valid total doses');
      return;
    }

    final currentStock = getMedicineStock(selectedMedicine);
    final shortage = totalDoses - currentStock;

    if (shortage > 0) {
      showStockShortageDialog(
        currentStock: currentStock,
        requiredStock: totalDoses,
        shortage: shortage,
      );
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

  void showStockShortageDialog({
    required int currentStock,
    required int requiredStock,
    required int shortage,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Not Enough Stock'),
          content: Text(
            'You cannot create this reminder because the selected medicine does not have enough stock.\n\n'
                'Required stock: $requiredStock\n'
                'Available stock: $currentStock\n'
                'Shortage: $shortage\n\n'
                'Please add more stock or reduce the total number of doses.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

      final currentStock = getMedicineStock(medicine);

      if (currentStock <= 0) {
        showMessage('No stock available for this medicine');
        return;
      }

      final newStock = currentStock - 1;
      final newTakenDoses = safeInt(reminder['taken_doses']) + 1;
      final totalDoses = safeInt(reminder['total_doses']);
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

  Widget buildAnalysisTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.14),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStockAnalysisDashboard() {
    final activeDays = parseActiveDays();
    final totalDoses = parseTotalDoses();
    final currentStock = getMedicineStock(selectedMedicine);

    final hasMedicine = selectedMedicine != null;
    final isComplete = hasCompletePlanInput();

    final requiredStock = totalDoses ?? 0;
    final remainingStock = currentStock - requiredStock;
    final shortage = remainingStock < 0 ? remainingStock.abs() : 0;

    final isEnough = isComplete && remainingStock >= 0;

    Color statusColor = const Color(0xFF7B5EF2);
    IconData statusIcon = Icons.info_outline;
    String statusTitle = 'Analysis Pending';
    String statusBody =
        'Select medicine, time, active days and total doses to check stock before creating the reminder.';

    if (isComplete && isEnough) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusTitle = 'Stock is sufficient';
      statusBody =
      '$remainingStock stock will remain after completing this reminder plan.';
    } else if (isComplete && !isEnough) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
      statusTitle = 'Not enough stock';
      statusBody =
      'You are short of $shortage stock. Add more stock or reduce the total doses.';
    } else if (hasMedicine) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_actions;
      statusTitle = 'Complete the plan';
      statusBody =
      'Enter reminder time, active days and total doses to calculate stock availability.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.14),
                child: Icon(
                  Icons.analytics_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stock Insights',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: buildAnalysisTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Current Stock',
                  value: hasMedicine ? currentStock.toString() : '-',
                  subtitle: 'available',
                  color: const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildAnalysisTile(
                  icon: Icons.medication_outlined,
                  title: 'Required',
                  value: totalDoses?.toString() ?? '-',
                  subtitle: 'doses',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: buildAnalysisTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Active Days',
                  value: activeDays?.toString() ?? '-',
                  subtitle: 'days',
                  color: const Color(0xFF7B5EF2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildAnalysisTile(
                  icon: Icons.trending_up,
                  title: isComplete && isEnough ? 'Extra Stock' : 'Shortage',
                  value: !isComplete
                      ? '-'
                      : isEnough
                      ? remainingStock.toString()
                      : shortage.toString(),
                  subtitle: isEnough ? 'will remain' : 'needed',
                  color: isComplete
                      ? isEnough
                      ? Colors.green
                      : Colors.red
                      : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusBody,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      if (isComplete)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Daily plan: ${dailyDosePlanText(totalDoses ?? 0, activeDays ?? 0)}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double reminderProgress(Map<String, dynamic> reminder) {
    final taken = safeInt(reminder['taken_doses']);
    final total = safeInt(reminder['total_doses']);

    if (total <= 0) return 0;

    final progress = taken / total;

    return progress.clamp(0.0, 1.0).toDouble();
  }

  Widget buildStatusBadge({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildReminderCard(Map<String, dynamic> reminder) {
    final medicine = reminder['medicine_inventory'];
    final isActive = reminder['is_active'] ?? false;
    final currentStock = getMedicineStock(medicine);
    final isOutOfStock = currentStock <= 0;
    final takenDoses = safeInt(reminder['taken_doses']);
    final totalDoses = safeInt(reminder['total_doses']);
    final activeDays = safeInt(reminder['active_days']);
    final progress = reminderProgress(reminder);
    final progressPercent = (progress * 100).round();

    Color statusColor = getStatusColor(isActive);
    String statusText = isActive ? 'Active' : 'Finished';

    if (isOutOfStock && isActive) {
      statusColor = Colors.red;
      statusText = 'No Stock';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOutOfStock
              ? Colors.red.withOpacity(0.25)
              : const Color(0xFFEDE8FF),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(
                    Icons.medication_outlined,
                    color: statusColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getMedicineName(medicine),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        getMedicineDose(medicine),
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                buildStatusBadge(
                  text: statusText,
                  color: statusColor,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Color(0xFF7B5EF2),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${reminder['reminder_time']} daily',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: Color(0xFF7B5EF2),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$activeDays days',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: isOutOfStock ? Colors.red : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isOutOfStock
                                  ? 'No stock available'
                                  : 'Stock: $currentStock',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                isOutOfStock ? Colors.red : Colors.black87,
                                fontWeight: isOutOfStock
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Taken: $takenDoses / $totalDoses',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    backgroundColor: Colors.grey.withOpacity(0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOutOfStock ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$progressPercent% completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOutOfStock ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isOutOfStock && isActive)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Please add stock before marking this medicine as taken.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isActive && !isOutOfStock
                            ? () {
                          confirmMedicineTaken(reminder);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E6FF7),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.white,
                        ),
                        child: Text(
                          isOutOfStock ? 'No Stock' : 'Taken',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          confirmDeleteReminder(reminder);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unseenCount = unseenNotificationCount();
    final planComplete = hasCompletePlanInput();
    final stockEnough = isPlanStockEnough();
    final shouldDisableForShortage = planComplete && !stockEnough;

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
                    final stock = getMedicineStock(medicine);

                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: medicine,
                      child: Text(
                        '${medicine['medicine_name']} (${medicine['dose_power']}) - Stock: $stock',
                        overflow: TextOverflow.ellipsis,
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
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Active for how many days?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: totalDosesController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Total number of doses',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                buildStockAnalysisDashboard(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isSaving || shouldDisableForShortage
                        ? null
                        : addReminder,
                    icon: Icon(
                      shouldDisableForShortage
                          ? Icons.lock_outline
                          : Icons.add_alarm,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E6FF7),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white,
                    ),
                    label: Text(
                      isSaving
                          ? 'Saving...'
                          : shouldDisableForShortage
                          ? 'Cannot Create Reminder'
                          : 'Create Reminder',
                    ),
                  ),
                ),
                if (shouldDisableForShortage)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Add more stock or reduce total doses before creating this reminder.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Reminders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${reminders.length} active/created',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
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
            return buildReminderCard(reminder);
          }),
        ],
      ),
    );
  }
}