import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

const _dbUrl =
    'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app';

class PassengerVerificationPage extends StatefulWidget {
  const PassengerVerificationPage({super.key});

  @override
  State<PassengerVerificationPage> createState() =>
      _PassengerVerificationPageState();
}

class _PassengerVerificationPageState
    extends State<PassengerVerificationPage> {
  // ─── Auth & DB ───────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _passengerRef;
  late String _uid;

  // ─── Colors ──────────────────────────────────
  final Color darkSurface = const Color(0xFF1C1C1E);
  final Color flisingOrange = const Color(0xFFE9692C);
  final Color successGreen = const Color(0xFF4CAF50);
  final Color warningRed = const Color(0xFFD32F2F);

  // ─── Local file picks ────────────────────────
  File? _profileFile;
  File? _idFile;

  // ─── Remote URLs ─────────────────────────────
  String? _profileUrl;
  String? _idUrl;

  // ─── Cached profile pic ──────────────────────
  File? _cachedProfileFile;

  // ─── State flags ─────────────────────────────
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPending = false;
  bool _isApproved = false;

  // ─── Profile picture change request ──────────
  bool _profileChangeRequested = false;
  bool _profileChangeUnlocked = false;

  final ImagePicker _picker = ImagePicker();

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser!.uid;
    _passengerRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _dbUrl,
    ).ref('users/passengers/$_uid');
    _loadData();
  }

  // ─── Load data ───────────────────────────────
  Future<void> _loadData() async {
    try {
      await _loadCachedProfile();

      final snap = await _passengerRef.get();
      if (snap.exists && mounted) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _profileUrl = data['profileImageUrl'];
          _idUrl = data['idImageUrl'];
          _isPending = data['pendingApproval'] ?? false;
          _isApproved = data['isVerified'] ?? false;
          _profileChangeRequested = data['profileChangeRequest'] ?? false;
          _profileChangeUnlocked = data['profileChangeUnlocked'] ?? false;
        });

        // Cache profile in background
        if (_profileUrl != null && _cachedProfileFile == null) {
          _cacheProfilePictureInBackground(_profileUrl!);
        }
      }
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCachedProfile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/passenger_profile_$_uid.jpg');
      if (await file.exists()) {
        if (mounted) setState(() => _cachedProfileFile = file);
      }
    } catch (_) {}
  }

  void _cacheProfilePictureInBackground(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/passenger_profile_$_uid.jpg');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) setState(() => _cachedProfileFile = file);
      }
    } catch (_) {}
  }

  // ─── Pick image ──────────────────────────────
  Future<void> _pickImage(bool isProfile) async {
    if (isProfile) {
      final locked =
          (_isPending || _isApproved) && !_profileChangeUnlocked;
      if (locked) return;
    } else {
      if (_isPending || _isApproved) return;
    }

    try {
      final f = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 75);
      if (f != null && mounted) {
        setState(() {
          if (isProfile) {
            _profileFile = File(f.path);
            _profileUrl = null;
          } else {
            _idFile = File(f.path);
            _idUrl = null;
          }
        });
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<String> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // ─── Submit documents ─────────────────────────
  Future<void> _submitDocuments() async {
    setState(() => _isSubmitting = true);
    try {
      final updates = <String, dynamic>{};

      if (_profileFile != null) {
        final url = await _uploadFile(
            _profileFile!, 'passenger_docs/$_uid/profile.jpg');
        updates['profileImageUrl'] = url;
        setState(() {
          _profileUrl = url;
          _profileFile = null;
        });
        _cacheProfilePictureInBackground(url);
      }

      if (_idFile != null) {
        final url = await _uploadFile(
            _idFile!, 'passenger_docs/$_uid/id_photo.jpg');
        updates['idImageUrl'] = url;
        setState(() {
          _idUrl = url;
          _idFile = null;
        });
      }

      updates['pendingApproval'] = true;
      await _passengerRef.update(updates);
      setState(() => _isPending = true);

      _showSnack('Documents submitted! Awaiting admin review.', isError: false);
    } catch (e) {
      _showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Request profile picture change ──────────
  Future<void> _requestProfilePictureChange() async {
    try {
      await _passengerRef.update({
        'profileChangeRequest': true,
        'profileChangeUnlocked': false,
        'profileChangeRequestedAt': ServerValue.timestamp,
      });
      setState(() => _profileChangeRequested = true);
      _showSnack(
          'Request sent! Admin will review and notify you.',
          isError: false);
    } catch (e) {
      _showSnack('Could not send request: $e', isError: true);
    }
  }

  // ─── Upload new profile pic after unlock ─────
  Future<void> _uploadNewProfilePicture() async {
    try {
      final f = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (f == null) return;

      setState(() => _isSubmitting = true);
      final file = File(f.path);
      final url = await _uploadFile(
          file, 'passenger_docs/$_uid/profile.jpg');

      await _passengerRef.update({
        'profileImageUrl': url,
        'profileChangeRequest': false,
        'profileChangeUnlocked': false,
        'profileChangedAt': ServerValue.timestamp,
      });

      _cacheProfilePictureInBackground(url);
      setState(() {
        _profileUrl = url;
        _profileChangeRequested = false;
        _profileChangeUnlocked = false;
      });

      _showSnack('Profile picture updated!', isError: false);
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? warningRed : successGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasProfile = _profileFile != null || _profileUrl != null;
    final hasId = _idFile != null || _idUrl != null;
    final canSubmit =
        hasProfile && hasId && !_isPending && !_isApproved;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Verification Portal',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 24),

                  _buildProfilePictureSection(),
                  const SizedBox(height: 24),

                  const Text('Verification Documents',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 12),

                  _buildDocTile(
                    icon: Icons.portrait,
                    title: 'Official ID / Face Photo',
                    subtitle: 'National ID or passport photo',
                    localFile: _idFile,
                    networkUrl: _idUrl,
                    onTap: () => _pickImage(false),
                  ),
                  const SizedBox(height: 36),

                  if (!_isPending && !_isApproved)
                    ElevatedButton(
                      onPressed: canSubmit
                          ? (_isSubmitting ? null : _submitDocuments)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: flisingOrange,
                        disabledBackgroundColor: darkSurface,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text('SUBMIT FOR REVIEW',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16)),
                    ),
                ],
              ),
            ),
    );
  }

  // ─── Profile picture section ──────────────────
  Widget _buildProfilePictureSection() {
    ImageProvider? imageProvider;
    if (_profileFile != null) {
      imageProvider = FileImage(_profileFile!);
    } else if (_cachedProfileFile != null) {
      imageProvider = FileImage(_cachedProfileFile!);
      if (_profileUrl != null) _cacheProfilePictureInBackground(_profileUrl!);
    } else if (_profileUrl != null) {
      imageProvider = NetworkImage(_profileUrl!);
    }

    final canChangeNow =
        (!_isPending && !_isApproved) || _profileChangeUnlocked;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.black,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Icon(Icons.account_circle,
                        color: Colors.white38, size: 80)
                    : null,
              ),
              if (canChangeNow)
                GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: flisingOrange,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Profile Photo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _isApproved && _profileChangeUnlocked
                ? 'Admin unlocked — tap camera to change'
                : _isApproved
                    ? 'Verified — locked'
                    : _isPending
                        ? 'Submitted'
                        : 'Tap camera to upload',
            style: TextStyle(
              color: _isApproved
                  ? (_profileChangeUnlocked
                      ? Colors.orange
                      : successGreen)
                  : _isPending
                      ? Colors.orange
                      : Colors.white54,
              fontSize: 12,
            ),
          ),

          if (_isApproved && !_profileChangeUnlocked) ...[
            const SizedBox(height: 14),
            _profileChangeRequested
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_top,
                          color: Colors.orange, size: 14),
                      const SizedBox(width: 6),
                      const Text(
                          'Pending admin approval',
                          style: TextStyle(
                              color: Colors.orange, fontSize: 12)),
                    ],
                  )
                : TextButton.icon(
                    onPressed: _requestProfilePictureChange,
                    icon: Icon(Icons.photo_camera_outlined,
                        color: flisingOrange, size: 16),
                    label: Text(
                      'Request Profile Picture Change',
                      style:
                          TextStyle(color: flisingOrange, fontSize: 12),
                    ),
                  ),
          ],

          if (_profileChangeUnlocked) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed:
                  _isSubmitting ? null : _uploadNewProfilePicture,
              icon: const Icon(Icons.upload,
                  color: Colors.white, size: 16),
              label: const Text('Upload New Photo',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: flisingOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Status banner ────────────────────────────
  Widget _buildStatusBanner() {
    final color = _isApproved
        ? successGreen
        : _isPending
            ? Colors.orange
            : warningRed;
    final icon = _isApproved
        ? Icons.verified_user
        : _isPending
            ? Icons.hourglass_top
            : Icons.gpp_maybe;
    final title = _isApproved
        ? 'VERIFIED ✓'
        : _isPending
            ? 'PENDING APPROVAL'
            : 'ACTION REQUIRED';
    final subtitle = _isApproved
        ? 'You are verified and can request rides.'
        : _isPending
            ? 'Documents are under review. We will email you once approved.'
            : 'Please upload your documents below.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 10),
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  // ─── Document tile ────────────────────────────
  Widget _buildDocTile({
    required IconData icon,
    required String title,
    required String subtitle,
    File? localFile,
    String? networkUrl,
    required VoidCallback onTap,
  }) {
    final hasImage = localFile != null || networkUrl != null;
    ImageProvider? imageProvider;
    if (localFile != null) imageProvider = FileImage(localFile);
    else if (networkUrl != null) imageProvider = NetworkImage(networkUrl);
    final locked = _isPending || _isApproved;

    return Container(
      decoration: BoxDecoration(
          color: darkSurface, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            image: hasImage
                ? DecorationImage(
                    image: imageProvider!, fit: BoxFit.cover)
                : null,
          ),
          child: hasImage ? null : Icon(icon, color: Colors.white38),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Text(
          _isApproved
              ? 'Locked — Verified ✓'
              : locked
                  ? 'Submitted — Under Review'
                  : hasImage
                      ? 'Ready to submit'
                      : subtitle,
          style: TextStyle(
            fontSize: 12,
            color: _isApproved
                ? successGreen
                : locked
                    ? Colors.orange
                    : hasImage
                        ? successGreen
                        : Colors.white38,
          ),
        ),
        trailing: locked
            ? Icon(
                _isApproved ? Icons.lock : Icons.hourglass_top,
                color: _isApproved ? successGreen : Colors.orange)
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: flisingOrange,
                  minimumSize: const Size(76, 34),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(hasImage ? 'CHANGE' : 'UPLOAD',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
      ),
    );
  }
}
