import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PassengerRegisterScreen extends StatefulWidget {
  const PassengerRegisterScreen({super.key});

  @override
  State<PassengerRegisterScreen> createState() =>
      _PassengerRegisterScreenState();
}

class _PassengerRegisterScreenState extends State<PassengerRegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  final Color flisingOrange = const Color(0xFFE9692C);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showTermsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Passenger Terms & Conditions',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: const [
                    Text(
                      'Flising Ride - Passenger Terms & Conditions\n\n'
                      '1. Service Overview\n'
                      'Flising Ride connects passengers with verified drivers across Papua New Guinea for safe, reliable passenger transport and parcel delivery.\n\n'
                      '2. Data Ownership, Security & Privacy\n'
                      'All photographs, full names, phone numbers, and identification details collected by Flising Ride are strictly for internal record-keeping and the safety and security of both passengers and drivers. This information will NEVER be sold, disclosed, or given to any third party, and remains the sole and exclusive property of Flising Ride.\n\n'
                      '3. Account & Identity Verification\n'
                      'Passengers must provide their true full name, active phone number, valid email address, and verification photo where required. Impersonation or false registration details will result in immediate account termination.\n\n'
                      '4. Fares & Cash Payments\n'
                      'Fares are automatically calculated by GPS distance and service type (Car, Motorcycle, or Send Delivery) and rounded to the nearest 10 toea. All trips currently operate on Cash Payment (PGK Kina) paid directly to the driver upon completion of the ride.\n\n'
                      '5. Cancellations, Conduct & Parcel Rules\n'
                      'Passengers must treat drivers with respect and may cancel within the allowed window prior to driver arrival. Repeated fake bookings, refusal to pay completed trip fares, abusive behavior, or attempting to send illegal or hazardous items via Send Delivery will result in permanent suspension.\n\n'
                      '6. Real-Time GPS & Trip Safety Records\n'
                      'Flising Ride records real-time GPS coordinates and trip logs during active bookings to match nearby drivers, provide live ETAs, and maintain security records for passenger and driver protection.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() => _agreedToTerms = true);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: flisingOrange,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('I ACCEPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.', isError: true);
      return;
    }

    if (!_agreedToTerms) {
      _showSnack('Please accept the Terms & Conditions to continue.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    UserCredential? userCredential;

    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(name);
      await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://flising-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref('users/passengers/${userCredential.user!.uid}').set({
        'fullName': name,
        'email': email,
        'role': 'passenger',
        'isVerified': true,
        'registeredAt': ServerValue.timestamp,
      });
      await userCredential.user?.sendEmailVerification();
      await _auth.signOut();

      if (!mounted) return;
      _showSnack(
        'Account created! A verification link has been sent to $email. Please verify before logging in.',
        isError: false,
      );

      await Future.delayed(const Duration(seconds: 4));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      try {
        await userCredential?.user?.delete();
      } catch (_) {}

      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered. Please log in instead.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'weak-password':
          msg = 'Password is too weak. Use at least 6 characters.';
          break;
        default:
          msg = e.message ?? 'Registration failed.';
      }
      if (mounted) _showSnack(msg, isError: true);
    } catch (e) {
      try {
        await userCredential?.user?.delete();
      } catch (_) {}
      if (mounted) _showSnack('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor:
          isError ? const Color(0xFFD32F2F) : const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          helperText: helperText,
          helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
          prefixIcon: Icon(icon, color: flisingOrange),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: flisingOrange)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            Image.asset(
              'assets/images/flising_mark.png',
              height: 60,
              errorBuilder: (c, e, s) =>
                  Icon(Icons.local_taxi, color: flisingOrange, size: 60),
            ),
            const SizedBox(height: 20),
            const Text(
              'Create Passenger Account',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Book rides across Papua New Guinea.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            _buildField(
              _nameController,
              'Full Name',
              Icons.person_outline,
              helperText: 'This name will be shown to your driver',
            ),
            _buildField(
              _phoneController,
              'Phone Number',
              Icons.phone_android,
              type: TextInputType.phone,
            ),
            _buildField(
              _emailController,
              'Email Address',
              Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password (Min. 6 characters)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.lock_outline, color: flisingOrange),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: flisingOrange)),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: flisingOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: flisingOrange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: flisingOrange, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'A verification email will be sent after sign up. '
                      'You must verify your email before you can log in and book rides.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: flisingOrange,
                    side: const BorderSide(color: Colors.white54),
                    onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showTermsDialog,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions and Privacy Policy',
                              style: TextStyle(
                                color: flisingOrange,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: flisingOrange,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SIGN UP',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
