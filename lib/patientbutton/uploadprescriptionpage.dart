import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medi_tracker/supabase_config.dart';

class UploadPrescriptionPage extends StatefulWidget {
  const UploadPrescriptionPage({super.key});

  @override
  State<UploadPrescriptionPage> createState() => _UploadPrescriptionPageState();
}

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> {
  bool isLoading = false;
  bool isUploading = false;

  final ImagePicker picker = ImagePicker();
  List<Map<String, dynamic>> prescriptions = [];

  @override
  void initState() {
    super.initState();
    fetchPrescriptions();
  }

  Future<void> fetchPrescriptions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final data = await supabase
          .from('prescription_images')
          .select()
          .eq('patient_user_id', currentUser.id)
          .order('uploaded_at', ascending: false);

      setState(() {
        prescriptions = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      showMessage('Failed to load prescriptions: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> pickAndUploadImage() async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedImage == null) return;

      setState(() {
        isUploading = true;
      });

      final bytes = await pickedImage.readAsBytes();
      final fileExtension = pickedImage.name.split('.').last;
      final fileName =
          '${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      final filePath = '${currentUser.id}/$fileName';

      await supabase.storage
          .from('prescriptions')
          .uploadBinary(filePath, bytes);

      final imageUrl = supabase.storage
          .from('prescriptions')
          .getPublicUrl(filePath);

      await supabase.from('prescription_images').insert({
        'patient_user_id': currentUser.id,
        'image_url': imageUrl,
        'file_name': filePath,
        'access_granted': false,
      });

      await fetchPrescriptions();
      showMessage('Prescription uploaded successfully');
    } catch (e) {
      showMessage('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> deletePrescription(Map<String, dynamic> prescription) async {
    try {
      final id = prescription['id'];
      final fileName = prescription['file_name'];

      if (fileName != null && fileName.toString().isNotEmpty) {
        await supabase.storage.from('prescriptions').remove([fileName]);
      }

      await supabase.from('prescription_images').delete().eq('id', id);

      await fetchPrescriptions();
      showMessage('Prescription deleted successfully');
    } catch (e) {
      showMessage('Delete failed: $e');
    }
  }

  void confirmDelete(Map<String, dynamic> prescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Prescription'),
        content: const Text('Do you want to delete this prescription image?'),
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
              deletePrescription(prescription);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.all(30),
                child: Text('Unable to load image'),
              );
            },
          ),
        ),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          'Upload Prescription',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8E6FF7),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8E6FF7),
        foregroundColor: Colors.white,
        onPressed: isUploading ? null : pickAndUploadImage,
        icon: isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.upload_file),
        label: Text(isUploading ? 'Uploading...' : 'Upload Image'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : prescriptions.isEmpty
          ? const Center(
              child: Text(
                'No prescription uploaded yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prescriptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final prescription = prescriptions[index];
                final imageUrl = prescription['image_url'] ?? '';

                return Container(
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
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showImagePreview(imageUrl);
                          },
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 45,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  showImagePreview(imageUrl);
                                },
                                child: const Text('View'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  confirmDelete(prescription);
                                },
                                child: const Text('Delete'),
                              ),
                            ),
                          ],
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
