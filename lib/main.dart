import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:swipable_stack/swipable_stack.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NepDate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const PhoneLoginPage(),
    );
  }
}

// ------------------ Phone Login ------------------
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  String? _verificationId;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> sendOtp() async {
    final phone = phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      _show('Enter phone in format: +97798xxxxxxx');
      return;
    }

    setState(() => _sendingOtp = true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        },
        verificationFailed: (e) {
          _show('Verification failed: ${e.message ?? 'Unknown error'}');
        },
        codeSent: (verificationId, resendToken) {
          setState(() => _verificationId = verificationId);
          _show('OTP sent');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();
    if (_verificationId == null) {
      _show('Send OTP first');
      return;
    }
    if (otp.length < 6) {
      _show('Enter valid 6-digit OTP');
      return;
    }

    setState(() => _verifyingOtp = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } on FirebaseAuthException catch (e) {
      _show('OTP verification failed: ${e.message ?? 'Invalid OTP'}');
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Enter phone number',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sendingOtp ? null : sendOtp,
              child: Text(_sendingOtp ? 'Sending...' : 'Send OTP'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Enter OTP'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _verifyingOtp ? null : verifyOtp,
              child: Text(_verifyingOtp ? 'Verifying...' : 'Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------ Profile Page ------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login again.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': nameController.text.trim(),
        'age': int.parse(ageController.text.trim()),
        'bio': bioController.text.trim(),
        'photos': [],
        'location': locationController.text.trim(),
        'interests': [],
        'gender': '',
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyHomePage(title: 'Discover')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (v) {
                  final age = int.tryParse((v ?? '').trim());
                  if (age == null || age <= 0) return 'Enter valid age';
                  return null;
                },
              ),
              TextFormField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter bio' : null,
              ),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter location' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : saveProfile,
                child: Text(_saving ? 'Saving...' : 'Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ Home Page with Swipable Cards ------------------
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _cards = [
    {'name': 'Asha', 'age': 24, 'bio': 'Loves hiking and coffee.'},
    {'name': 'Rabin', 'age': 27, 'bio': 'Music producer and foodie.'},
    {'name': 'Nima', 'age': 22, 'bio': 'Photographer and traveler.'},
  ];

  late final SwipableStackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SwipableStackController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SwipableStack(
          controller: _controller,
          itemCount: _cards.length,
          onSwipeCompleted: (index, direction) {
            final user = _cards[index];
            print('Swiped ${direction.name} on ${user['name']}');

            // TODO: Implement like/pass Firestore logic here
          },
          builder: (context, properties) {
            final user = _cards[properties.index];
            return Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${user['name']}, ${user['age']}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user['bio'],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
