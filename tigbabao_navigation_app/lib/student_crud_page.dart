import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentCrudPage extends StatefulWidget {
  const StudentCrudPage({super.key});

  @override
  State<StudentCrudPage> createState() =>
      _StudentCrudPageState();
}

class _StudentCrudPageState extends State<StudentCrudPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final courseController = TextEditingController();

  late final CollectionReference<Map<String, dynamic>>
      students;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      studentStream;

  String? editingId;
  bool saving = false;
  bool deleting = false;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    students = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('students');

    studentStream = students.snapshots();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void clearForm() {
    formKey.currentState?.reset();
    nameController.clear();
    courseController.clear();

    setState(() {
      editingId = null;
    });
  }

  // CREATE or UPDATE
  Future<void> saveStudent() async {
    if (saving || deleting) return;

    if (!formKey.currentState!.validate()) {
      return;
    }

    final data = {
      'name': nameController.text.trim(),
      'course': courseController.text.trim(),
    };

    final id = editingId;

    setState(() {
      saving = true;
    });

    try {
      if (id == null) {
        // CREATE: generate a new document.
        await students.add(data);
      } else {
        // UPDATE: modify the selected document.
        await students.doc(id).update(data);
      }

      if (!mounted) return;

      clearForm();

      showMessage(
        id == null
            ? 'Student added successfully.'
            : 'Student updated successfully.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      showMessage('Save failed: ${error.code}');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void editStudent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    nameController.text = data['name'] as String;
    courseController.text = data['course'] as String;

    setState(() {
      editingId = document.id;
    });
  }

  // DELETE
  Future<void> deleteStudent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (saving || deleting) return;

    setState(() {
      deleting = true;
    });

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete Student'),
            content: Text(
              'Delete ${document.data()['name']}?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) return;

      await students.doc(document.id).delete();

      if (!mounted) return;

      if (editingId == document.id) {
        clearForm();
      }

      showMessage('Student deleted successfully.');
    } on FirebaseException catch (error) {
      if (!mounted) return;

      showMessage('Delete failed: ${error.code}');
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
        });
      }
    }
  }

  String? validateText(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'This field is required.';
    }

    if (text.length > 80) {
      return 'Use no more than 80 characters.';
    }

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    courseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = saving || deleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            editingId == null
                ? 'Add Student'
                : 'Edit Student',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  enabled: !busy,
                  validator: validateText,
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: courseController,
                  enabled: !busy,
                  validator: validateText,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    prefixIcon: Icon(Icons.school),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: busy ? null : saveStudent,
                  icon: const Icon(Icons.save),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : editingId == null
                            ? 'Add Student'
                            : 'Update Student',
                  ),
                ),

                if (editingId != null)
                  TextButton(
                    onPressed: busy ? null : clearForm,
                    child: const Text('Cancel Edit'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Text(
            'Saved Students',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // READ: display live Firestore documents.
          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: studentStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Unable to load records. '
                  'Check your connection and database rules.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final documents = snapshot.data!.docs;

              if (documents.isEmpty) {
                return const Text(
                  'No student records yet.',
                );
              }

              return Column(
                children: documents.map((document) {
                  final data = document.data();

                  return Card(
                    key: ValueKey(document.id),
                    child: ListTile(
                      title: Text(data['name'] as String),
                      subtitle: Text(
                        data['course'] as String,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: busy
                                ? null
                                : () => editStudent(document),
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: busy
                                ? null
                                : () => deleteStudent(document),
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
