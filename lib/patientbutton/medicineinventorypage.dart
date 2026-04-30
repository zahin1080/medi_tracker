import 'package:flutter/material.dart';
import 'package:medi_tracker/supabase_config.dart';

class MedicineInventoryPage extends StatefulWidget {
  const MedicineInventoryPage({super.key});

  @override
  State<MedicineInventoryPage> createState() => _MedicineInventoryPageState();
}

class _MedicineInventoryPageState extends State<MedicineInventoryPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> medicines = [];

  @override
  void initState() {
    super.initState();
    fetchMedicines();
  }

  Future<void> fetchMedicines() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final data = await supabase
          .from('medicine_inventory')
          .select()
          .eq('patient_user_id', currentUser.id)
          .order('created_at', ascending: false);

      setState(() {
        medicines = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      showMessage('Failed to load medicines: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> addMedicine({
    required String medicineName,
    required String dosePower,
    required int stock,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      await supabase.from('medicine_inventory').insert({
        'patient_user_id': currentUser.id,
        'medicine_name': medicineName,
        'dose_power': dosePower,
        'current_stock': stock,
        'low_stock_threshold': 5,
        'is_active': true,
      });

      await fetchMedicines();
      showMessage('Medicine added successfully');
    } catch (e) {
      showMessage('Failed to add medicine: $e');
    }
  }

  Future<void> updateMedicine({
    required String id,
    required String medicineName,
    required String dosePower,
    required int stock,
  }) async {
    try {
      await supabase
          .from('medicine_inventory')
          .update({
            'medicine_name': medicineName,
            'dose_power': dosePower,
            'current_stock': stock,
          })
          .eq('id', id);

      await fetchMedicines();
      showMessage('Medicine updated successfully');
    } catch (e) {
      showMessage('Failed to update medicine: $e');
    }
  }

  Future<void> reduceStock({
    required String id,
    required int currentStock,
    required int reduceBy,
  }) async {
    if (reduceBy <= 0) {
      showMessage('Enter a valid reduction amount');
      return;
    }

    if (reduceBy > currentStock) {
      showMessage('Reduction amount cannot be greater than current stock');
      return;
    }

    try {
      final newStock = currentStock - reduceBy;

      await supabase
          .from('medicine_inventory')
          .update({'current_stock': newStock})
          .eq('id', id);

      await fetchMedicines();
      showMessage('Stock reduced successfully');
    } catch (e) {
      showMessage('Failed to reduce stock: $e');
    }
  }

  Future<void> deleteMedicine(String id) async {
    try {
      await supabase.from('medicine_inventory').delete().eq('id', id);

      await fetchMedicines();
      showMessage('Medicine removed successfully');
    } catch (e) {
      showMessage('Failed to remove medicine: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void showAddMedicineDialog() {
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medicine'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name'),
              ),
              TextField(
                controller: doseController,
                decoration: const InputDecoration(labelText: 'Dose / Power'),
              ),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Count / Stock'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final dose = doseController.text.trim();
              final stock = int.tryParse(stockController.text.trim());

              if (name.isEmpty || dose.isEmpty || stock == null || stock < 0) {
                showMessage('Please enter valid medicine details');
                return;
              }

              Navigator.pop(context);

              addMedicine(medicineName: name, dosePower: dose, stock: stock);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void showEditMedicineDialog(Map<String, dynamic> medicine) {
    final nameController = TextEditingController(
      text: medicine['medicine_name'] ?? '',
    );
    final doseController = TextEditingController(
      text: medicine['dose_power'] ?? '',
    );
    final stockController = TextEditingController(
      text: medicine['current_stock'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Medicine'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name'),
              ),
              TextField(
                controller: doseController,
                decoration: const InputDecoration(labelText: 'Dose / Power'),
              ),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Count / Stock'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final dose = doseController.text.trim();
              final stock = int.tryParse(stockController.text.trim());

              if (name.isEmpty || dose.isEmpty || stock == null || stock < 0) {
                showMessage('Please enter valid medicine details');
                return;
              }

              Navigator.pop(context);

              updateMedicine(
                id: medicine['id'],
                medicineName: name,
                dosePower: dose,
                stock: stock,
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void showReduceStockDialog(Map<String, dynamic> medicine) {
    final reduceController = TextEditingController();
    final currentStock = medicine['current_stock'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reduce Stock'),
        content: TextField(
          controller: reduceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'How many doses/counts to reduce?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reduceBy = int.tryParse(reduceController.text.trim());

              if (reduceBy == null) {
                showMessage('Enter a valid number');
                return;
              }

              Navigator.pop(context);

              reduceStock(
                id: medicine['id'],
                currentStock: currentStock,
                reduceBy: reduceBy,
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Medicine'),
        content: const Text('Do you want to remove this medicine?'),
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
              deleteMedicine(id);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Color getStockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 5) return Colors.orange;
    return const Color(0xFF7B5EF2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          'Medicine Inventory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8E6FF7),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8E6FF7),
        foregroundColor: Colors.white,
        onPressed: showAddMedicineDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medicines.isEmpty
          ? const Center(
              child: Text(
                'No medicine added yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: medicines.length,
              itemBuilder: (context, index) {
                final medicine = medicines[index];
                final stock = medicine['current_stock'] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(
                                0xFF8E6FF7,
                              ).withOpacity(0.12),
                              child: const Icon(
                                Icons.medication_outlined,
                                color: Color(0xFF7B5EF2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                medicine['medicine_name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ),
                            Text(
                              'Stock: $stock',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: getStockColor(stock),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dose / Power: ${medicine['dose_power'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF777777),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  showReduceStockDialog(medicine);
                                },
                                child: const Text('Reduce'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  showEditMedicineDialog(medicine);
                                },
                                child: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  showDeleteConfirmation(medicine['id']);
                                },
                                child: const Text('Remove'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
