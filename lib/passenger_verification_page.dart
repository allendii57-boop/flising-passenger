import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PassengerVerificationPage extends StatefulWidget {
  const PassengerVerificationPage({super.key});
  @override
  State<PassengerVerificationPage> createState() => _PassengerVerificationPageState();
}

class _PassengerVerificationPageState extends State<PassengerVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color darkSurface = const Color(0xFF1C1C1E);
  final Color flisingOrange = const Color(0xFFE9692C);
  final Color successGreen = const Color(0xFF4CAF50);
  final Color warningRed = const Color(0xFFD32F2F);

  File? _profileImageFile;
  File? _idImageFile;
  String? _profileImageUrl;
  String? _idImageUrl;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPendingApproval = false;
  bool _isApproved = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final ref = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebaseapp.com',
      ).ref('users/passengers/${user.uid}');
      final snap = await ref.get();
      if (snap.exists && mounted) {
        final data = snap.value as Map;
        setState(() {
          _profileImageUrl = data['profileImageUrl'];
          _idImageUrl = data['idImageUrl'];
          _isPendingApproval = data['pendingApproval'] ?? false;
          _isApproved = data['isVerified'] ?? false;
        });
      }
    } catch (e) {
      print('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    if (_isPendingApproval || _isApproved) return;
    try {
      final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (f != null && mounted) {
        setState(() {
          if (isProfile) {
            _profileImageFile = File(f.path);
            _profileImageUrl = null;
          } else {
            _idImageFile = File(f.path);
            _idImageUrl = null;
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: warningRed));
    }
  }

  Future<void> _submitDocuments() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSubmitting = true);
    try {
      final dbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebaseapp.com',
      ).ref('users/passengers/${user.uid}');

      if (_profileImageFile != null) {
        final ref = FirebaseStorage.instance.ref('passenger_docs/${user.uid}/profile.jpg');
        await ref.putFile(_profileImageFile!);
        final url = await ref.getDownloadURL();
        await dbRef.update({'profileImageUrl': url});
        setState(() { _profileImageUrl = url; _profileImageFile = null; });
      }

      if (_idImageFile != null) {
        final ref = FirebaseStorage.instance.ref('passenger_docs/${user.uid}/id_photo.jpg');
        await ref.putFile(_idImageFile!);
        final url = await ref.getDownloadURL();
        await dbRef.update({'idImageUrl': url});
        setState(() { _idImageUrl = url; _idImageFile = null; });
      }

      await dbRef.update({'pendingApproval': true});
      setState(() => _isPendingApproval = true);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Documents submitted! Awaiting admin review.'),
          backgroundColor: successGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: warningRed));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = _profileImageFile != null || _profileImageUrl != null;
    final hasId = _idImageFile != null || _idImageUrl != null;
    final canSubmit = hasProfile && hasId && !_isPendingApproval && !_isApproved;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Verification Portal', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                  color: _isApproved ? successGreen.withOpacity(0.1) : _isPendingApproval ? Colors.orange.withOpacity(0.1) : warningRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _isApproved ? successGreen.withOpacity(0.3) : _isPendingApproval ? Colors.orange.withOpacity(0.3) : warningRed.withOpacity(0.2), width: 1.5),
                ),
                child: Column(children: [
                  Icon(_isApproved ? Icons.verified_user : _isPendingApproval ? Icons.hourglass_top : Icons.gpp_maybe,
                    color: _isApproved ? successGreen : _isPendingApproval ? Colors.orange : warningRed, size: 50),
                  const SizedBox(height: 20),
                  Text(_isApproved ? 'VERIFIED' : _isPendingApproval ? 'PENDING APPROVAL' : 'ACTION REQUIRED',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_isApproved ? 'You are verified and can request rides.' : _isPendingApproval ? 'Your documents are under review. We will email you once approved.' : 'Please complete the steps below.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 35),
              const Align(alignment: Alignment.centerLeft,
                child: Text('Verification Steps', style: TextStyle(color: Colors.white54, fontSize: 14))),
              const SizedBox(height: 15),
              _buildImageTile(
                icon: Icons.account_circle_outlined,
                title: 'Profile Photo',
                localFile: _profileImageFile,
                networkUrl: _profileImageUrl,
                onAction: () => _pickImage(true),
                locked: _isPendingApproval || _isApproved,
              ),
              const SizedBox(height: 12),
              _buildImageTile(
                icon: Icons.portrait,
                title: 'Official ID or Face Photo',
                localFile: _idImageFile,
                networkUrl: _idImageUrl,
                onAction: () => _pickImage(false),
                locked: _isPendingApproval || _isApproved,
              ),
              const SizedBox(height: 40),
              if (!_isPendingApproval && !_isApproved)
                ElevatedButton(
                  onPressed: canSubmit ? (_isSubmitting ? null : _submitDocuments) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: flisingOrange,
                    disabledBackgroundColor: darkSurface,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT FOR REVIEW', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildImageTile({required IconData icon, required String title, File? localFile, String? networkUrl, required VoidCallback onAction, required bool locked}) {
    final hasImage = localFile != null || networkUrl != null;
    ImageProvider? imageProvider;
    if (localFile != null) imageProvider = FileImage(localFile);
    else if (networkUrl != null) imageProvider = NetworkImage(networkUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 45, height: 45,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10),
            image: hasImage ? DecorationImage(image: imageProvider!, fit: BoxFit.cover) : null),
          child: hasImage ? null : Icon(icon, color: Colors.white70, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _isApproved ? 'Locked - Verified' : locked ? 'Submitted' : localFile != null ? 'Ready to upload' : hasImage ? 'Attached' : 'Not uploaded',
            style: TextStyle(color: _isApproved ? successGreen : locked ? Colors.orange : hasImage ? successGreen : Colors.white38, fontSize: 13),
          ),
        ),
        trailing: locked
          ? Icon(_isApproved ? Icons.lock : Icons.hourglass_top, color: _isApproved ? successGreen : Colors.orange, size: 24)
          : ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(backgroundColor: flisingOrange, minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(hasImage ? 'CHANGE' : 'UPLOAD', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
      ),
    );
  }
}
