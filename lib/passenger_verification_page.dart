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

  // Variables to hold new local files
  File? _profileImageFile;
  File? _idImageFile;
  
  // Variables to hold existing uploaded URLs (Document Persistence)
  String? _profileImageUrl;
  String? _idImageUrl;

  bool _isWhatsappAdded = false;
  bool _isLoading = true; // For initial data fetch
  bool _isSubmitting = false; // For the upload process

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingVerificationData();
  }

  // --- 1. PERSISTENCE: LOAD EXISTING DATA ---
  Future<void> _loadExistingVerificationData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
        // NEW: Force refresh the user to get actual email verification status
      await currentUser.reload();
      currentUser = _auth.currentUser;
      DatabaseReference userRef = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebaseapp.com',
).ref('users/passengers/${currentUser!.uid}');
      DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        if (mounted) {
          setState(() {
            _profileImageUrl = data['profileImageUrl'];
            _idImageUrl = data['idImageUrl'];
            _isWhatsappAdded = data['whatsappAdded'] ?? false;
          });
        }
      }
    } catch (e) {
      print("Error loading verification data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- 2. PICK NEW IMAGE FROM GALLERY ---
  Future<void> _pickImage(bool isProfilePhoto) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70); // Compressed for speed

      if (pickedFile != null) {
        setState(() {
          if (isProfilePhoto) {
            _profileImageFile = File(pickedFile.path);
            _profileImageUrl = null; // Clear old network image if they pick a new one
          } else {
            _idImageFile = File(pickedFile.path);
            _idImageUrl = null;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Photo selected locally! Tap Submit to upload.', style: TextStyle(color: Colors.white)),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gallery error: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: warningRed,
        ));
      }
    }
  }

  // --- 3. UPLOAD TO FIREBASE STORAGE ---
  Future<void> _submitDocuments() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() { _isSubmitting = true; });

    try {
      DatabaseReference userRef = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebaseapp.com',
).ref('users/passengers/${currentUser.uid}');
      // Upload Profile Image if a new one was selected
      if (_profileImageFile != null) {
        final profileRef = FirebaseStorage.instance
    .ref()
    .child('passenger_docs/${currentUser.uid}/profile.jpg');
        await profileRef.putFile(_profileImageFile!);
        String profileUrl = await profileRef.getDownloadURL();
        await userRef.update({'profileImageUrl': profileUrl});
        
        setState(() {
           _profileImageUrl = profileUrl;
           _profileImageFile = null; // Clear local file since it's uploaded now
        });
      }

      // Upload ID Image if a new one was selected
      if (_idImageFile != null) {
        final idRef = FirebaseStorage.instance
    .ref()
    .child('passenger_docs/${currentUser.uid}/id_photo.jpg');
        await idRef.putFile(_idImageFile!);
        String idUrl = await idRef.getDownloadURL();
        await userRef.update({'idImageUrl': idUrl});
        
        setState(() {
           _idImageUrl = idUrl;
           _idImageFile = null; 
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Documents submitted securely for admin review.', style: TextStyle(color: Colors.white)),
          backgroundColor: successGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: flisingOrange,
        ));
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    

        // Logic includes both LOCAL files (just picked) and network URLs
    bool hasProfile = _profileImageFile != null || _profileImageUrl != null;
    bool hasId = _idImageFile != null || _idImageUrl != null;
    
    // NEW: Check true Firebase Auth email status
    bool isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false; 
    
    bool isFullyVerified = hasProfile && hasId && isEmailVerified;


    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Verification Portal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: isFullyVerified ? successGreen.withOpacity(0.05) : warningRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isFullyVerified ? successGreen.withOpacity(0.3) : warningRed.withOpacity(0.3), 
                  width: 1.5
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isFullyVerified ? successGreen.withOpacity(0.15) : warningRed.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFullyVerified ? Icons.verified_user : Icons.gpp_maybe,
                      color: isFullyVerified ? successGreen : warningRed,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isFullyVerified ? "DOCUMENTS UPLOADED" : "ACTION REQUIRED",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFullyVerified 
                        ? "Your documents are under review. Once approved by an admin, you can request rides." 
                        : "Please complete the missing steps below.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            const Text("Verification Steps", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 15),

        // 1. Email Status (Read Only - verified at register)
_buildStatusTile(
  icon: Icons.email_outlined,
  title: "Email Address",
  status: isEmailVerified ? "Verified" : "Action Required",
  isComplete: isEmailVerified,
  actionText: "",
  onAction: () {},
),

            // 2. Profile Photo
            _buildImageTile(
              icon: Icons.account_circle_outlined,
              title: "Profile Photo",
              localFile: _profileImageFile,
              networkUrl: _profileImageUrl,
              onAction: () => _pickImage(true),
            ),

            // 3. ID Photo
            _buildImageTile(
              icon: Icons.portrait,
              title: "Official ID or Face Photo",
              localFile: _idImageFile,
              networkUrl: _idImageUrl,
              onAction: () => _pickImage(false),
            ),

      
            
            const SizedBox(height: 40),

            // --- SUBMIT BUTTON ---
            // Only active if they have made changes (local files exist) or haven't submitted yet
            ElevatedButton(
              onPressed: (_profileImageFile == null && _idImageFile == null && _isSubmitting == false) ? null : _submitDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: flisingOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: darkSurface,
                disabledForegroundColor: Colors.white30,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SUBMIT FOR REVIEW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // STANDARD TILE
  Widget _buildStatusTile({required IconData icon, required String title, required String status, required bool isComplete, String? actionText, required VoidCallback onAction}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(status, style: TextStyle(color: isComplete ? successGreen : warningRed, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        trailing: isComplete
            ? Icon(Icons.check_circle, color: successGreen, size: 24)
            : ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(backgroundColor: flisingOrange, minimumSize: const Size(70, 35), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text(actionText ?? "FIX", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }

  // DYNAMIC IMAGE TILE (Handles both Local Files and Network URLs)
  Widget _buildImageTile({required IconData icon, required String title, File? localFile, String? networkUrl, required VoidCallback onAction}) {
    bool hasImage = localFile != null || networkUrl != null;
    
    ImageProvider? imageProvider;
    if (localFile != null) {
      imageProvider = FileImage(localFile);
    } else if (networkUrl != null) {
      imageProvider = NetworkImage(networkUrl);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: darkSurface, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 45, height: 45,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            image: hasImage ? DecorationImage(image: imageProvider!, fit: BoxFit.cover) : null,
          ),
          child: hasImage ? null : Icon(icon, color: Colors.white70, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(hasImage ? (localFile != null ? "Pending Upload" : "Attached") : "Required", 
            style: TextStyle(color: hasImage ? (localFile != null ? flisingOrange : successGreen) : warningRed, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        trailing: hasImage && localFile == null
            ? Icon(Icons.check_circle, color: successGreen, size: 24)
            : ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(backgroundColor: flisingOrange, minimumSize: const Size(70, 35), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text("UPLOAD", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }
}