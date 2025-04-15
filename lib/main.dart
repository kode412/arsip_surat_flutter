import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arsip Surat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.archive),
            SizedBox(width: 10),
            Text('Arsip Surat'),
          ],
        ),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.all(16.0),
        children: [
          MenuItem(
            iconPath: 'images/inbox.png',
            label: 'Surat Masuk',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentPage(title: 'Surat Masuk', collection: 'inbox'),
                ),
              );
            },
          ),
          MenuItem(
            iconPath: 'images/outbox.png',
            label: 'Surat Keluar',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentPage(title: 'Surat Keluar', collection: 'outbox'),
                ),
              );
            },
          ),
          MenuItem(
            iconPath: 'images/announcement.png',
            label: 'Pengumuman',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentPage(title: 'Pengumuman', collection: 'announcements'),
                ),
              );
            },
          ),
          MenuItem(
            iconPath: 'images/announcement.png',
            label: 'Menu Edaran',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentPage(title: 'Menu Edaran', collection: 'circulars'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MenuItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final VoidCallback onTap;

  MenuItem({required this.iconPath, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                iconPath,
                width: 50,
                height: 50,
              ),
              SizedBox(height: 10),
              Text(label, style: TextStyle(fontSize: 16.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentPage extends StatefulWidget {
  final String title;
  final String collection;

  DocumentPage({required this.title, required this.collection});

  @override
  _DocumentPageState createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  DateTime? selectedDate;
  File? _pickedImage;
  PlatformFile? _pickedFile;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _importFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _addDocument() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pilih tanggal terlebih dahulu!')),
      );
      return;
    }

    try {
      String? imageUrl;
      String? fileUrl;

      // Upload image if exists
      if (_pickedImage != null) {
        final ref = _storage.ref().child('${widget.collection}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_pickedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Upload file if exists
      if (_pickedFile != null) {
        final ref = _storage.ref().child('${widget.collection}/${_pickedFile!.name}');
        await ref.putData(_pickedFile!.bytes!);
        fileUrl = await ref.getDownloadURL();
      }

      // Add document to Firestore
      await _firestore.collection(widget.collection).add({
        'title': _pickedFile != null ? _pickedFile!.name : 'Dokumen ${DateTime.now().millisecondsSinceEpoch}',
        'date': selectedDate,
        'imageUrl': imageUrl,
        'fileUrl': fileUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Reset state
      setState(() {
        _pickedImage = null;
        _pickedFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dokumen berhasil ditambahkan!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteDocument(String docId) async {
    try {
      await _firestore.collection(widget.collection).doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dokumen berhasil dihapus!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Form Tanggal
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate == null
                        ? 'Pilih Tanggal'
                        : 'Tanggal: ${_dateFormat.format(selectedDate!)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ],
            ),
            SizedBox(height: 20),

            // Tombol Ambil Foto dan Import File
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _takePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow[900],
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt),
                        SizedBox(width: 10),
                        Text('Ambil Foto'),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _importFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[900],
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file),
                        SizedBox(width: 10),
                        Text('Import File'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Tampilkan Foto yang Diambil
            if (_pickedImage != null)
              Image.file(
                _pickedImage!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),

            // Tampilkan Nama File yang Dipilih
            if (_pickedFile != null)
              Text(
                'File: ${_pickedFile!.name}',
                style: TextStyle(fontSize: 16),
              ),

            // Tombol Tambah Dokumen
            ElevatedButton(
              onPressed: _addDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Tambah Dokumen',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            
            // List Dokumen dari Firebase
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection(widget.collection).orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('Tidak ada dokumen'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      DateTime date = (data['date'] as Timestamp).toDate();

                      return ListTile(
                        title: Text(data['title']),
                        subtitle: Text('Tanggal: ${_dateFormat.format(date)}'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteDocument(doc.id),
                        ),
                        onTap: () {
                          // You can add functionality to view/download the document here
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}