import 'package:flutter/material.dart';
import 'package:medi_tracker/supabase_config.dart';

class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final specializationController = TextEditingController();
  final mbbsController = TextEditingController();
  final calendlyController = TextEditingController();

  final degreeController = TextEditingController();
  final chamberAddressController = TextEditingController();

  List<String> degrees = [];
  List<String> chamberAddresses = [];
  List<String> selectedDays = [];

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  bool isLoading = false;

  final List<String> weekDays = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    specializationController.dispose();
    mbbsController.dispose();
    calendlyController.dispose();
    degreeController.dispose();
    chamberAddressController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final userData = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      final doctorData = await supabase
          .from('doctor_profiles')
          .select()
          .eq('user_id', user.id)
          .single();

      nameController.text = userData['full_name'] ?? '';
      phoneController.text = doctorData['phone'] ?? '';
      specializationController.text = doctorData['specialization'] ?? '';
      mbbsController.text = doctorData['mbbs_completion_campus'] ?? '';
      calendlyController.text = doctorData['calendly_link'] ?? '';

      degrees = List<String>.from(doctorData['additional_degrees'] ?? []);
      chamberAddresses =
      List<String>.from(doctorData['chamber_addresses'] ?? []);
      selectedDays = List<String>.from(doctorData['available_days'] ?? []);

      final savedStartTime = doctorData['availability_start_time'];
      final savedEndTime = doctorData['availability_end_time'];

      if (savedStartTime != null && savedStartTime.toString().contains(':')) {
        final parts = savedStartTime.toString().split(':');
        startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }

      if (savedEndTime != null && savedEndTime.toString().contains(':')) {
        final parts = savedEndTime.toString().split(':');
        endTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      showMessage('Failed to load profile: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void addDegree() {
    if (degreeController.text.trim().isNotEmpty) {
      setState(() {
        degrees.add(degreeController.text.trim());
        degreeController.clear();
      });
    }
  }

  void removeDegree(int index) {
    setState(() {
      degrees.removeAt(index);
    });
  }

  void addChamberAddress() {
    if (chamberAddressController.text.trim().isNotEmpty) {
      setState(() {
        chamberAddresses.add(chamberAddressController.text.trim());
        chamberAddressController.clear();
      });
    }
  }

  void removeChamberAddress(int index) {
    setState(() {
      chamberAddresses.removeAt(index);
    });
  }

  void toggleDay(String day) {
    setState(() {
      if (selectedDays.contains(day)) {
        selectedDays.remove(day);
      } else {
        selectedDays.add(day);
      }
    });
  }

  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

  String formatTimeForDatabase(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> saveProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('User not logged in');
      return;
    }

    try {
      await supabase
          .from('user_profiles')
          .update({'full_name': nameController.text.trim()})
          .eq('id', user.id);

      await supabase
          .from('doctor_profiles')
          .update({
        'phone': phoneController.text.trim(),
        'specialization': specializationController.text.trim(),
        'mbbs_completion_campus': mbbsController.text.trim(),
        'additional_degrees': degrees,
        'chamber_addresses': chamberAddresses,
        'available_days': selectedDays,
        'availability_start_time': formatTimeForDatabase(startTime),
        'availability_end_time': formatTimeForDatabase(endTime),
        'calendly_link': calendlyController.text.trim(),
      })
          .eq('user_id', user.id);

      showMessage('Profile Updated');
    } catch (e) {
      showMessage('Failed to update profile: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Profile"),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Appointment Number",
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: specializationController,
                decoration: const InputDecoration(
                  labelText: "Specialization",
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: mbbsController,
                decoration: const InputDecoration(
                  labelText: "MBBS Institution",
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: calendlyController,
                decoration: const InputDecoration(
                  labelText: "Calendly Link",
                  hintText: "https://calendly.com/your-link",
                ),
              ),
              sectionTitle("Degrees"),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: degreeController,
                      decoration: const InputDecoration(
                        hintText: "e.g. FCPS - BSMMU",
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: addDegree,
                  ),
                ],
              ),
              ...degrees.asMap().entries.map((entry) {
                return ListTile(
                  title: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => removeDegree(entry.key),
                  ),
                );
              }),
              sectionTitle("Chamber Address"),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: chamberAddressController,
                      decoration: const InputDecoration(
                        hintText: "Enter chamber address",
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_location_alt),
                    onPressed: addChamberAddress,
                  ),
                ],
              ),
              ...chamberAddresses.asMap().entries.map((entry) {
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => removeChamberAddress(entry.key),
                  ),
                );
              }),
              sectionTitle("Set Availability"),
              const Text(
                "Select available days",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: weekDays.map((day) {
                  final isSelected = selectedDays.contains(day);

                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    onSelected: (_) => toggleDay(day),
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: pickStartTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        startTime == null
                            ? "Start Time"
                            : "Start: ${startTime!.format(context)}",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: pickEndTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        endTime == null
                            ? "End Time"
                            : "End: ${endTime!.format(context)}",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: saveProfile,
                child: const Text("Save Profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}