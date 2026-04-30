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
  final chamberController = TextEditingController();

  final degreeController = TextEditingController();

  List<String> degrees = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;

    final userData = await supabase
        .from('user_profiles')
        .select()
        .eq('id', user!.id)
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
    chamberController.text = doctorData['chamber_information'] ?? '';

    degrees = List<String>.from(doctorData['additional_degrees'] ?? []);

    setState(() => isLoading = false);
  }

  void addDegree() {
    if (degreeController.text.isNotEmpty) {
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

  Future<void> saveProfile() async {
    final user = supabase.auth.currentUser;

    await supabase
        .from('user_profiles')
        .update({'full_name': nameController.text.trim()})
        .eq('id', user!.id);

    await supabase
        .from('doctor_profiles')
        .update({
          'phone': phoneController.text.trim(),
          'specialization': specializationController.text.trim(),
          'mbbs_completion_campus': mbbsController.text.trim(),
          'additional_degrees': degrees,
          'chamber_information': chamberController.text.trim(),
        })
        .eq('user_id', user.id);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Profile Updated")));
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
                        labelText: "Contact Number",
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
                    const SizedBox(height: 20),

                    const Text(
                      "Degrees",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

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

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: chamberController,
                      decoration: const InputDecoration(
                        labelText: "Chamber Info (Day, Time, Location)",
                      ),
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
