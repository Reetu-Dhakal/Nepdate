import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:swipable_stack/swipable_stack.dart';
import 'package:image_picker/image_picker.dart';

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
        fontFamily: 'Poppins',
      ),
      home: const PhoneLoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ------------------ PHONE LOGIN ------------------
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

// ------------------ PROFILE PAGE ------------------
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
  final List<File> _photos = [];
  bool _saving = false;

  Future<void> pickPhoto() async {
    if (_photos.length >= 5) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _photos.add(File(image.path)));
  }

  Future<List<String>> uploadPhotos(List<File> files, String uid) async {
    List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(
        'profile_photos/$uid-$i.jpg',
      );
      await ref.putFile(files[i]);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    List<String> photoUrls = [];
    if (_photos.isNotEmpty) photoUrls = await uploadPhotos(_photos, user.uid);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': nameController.text.trim(),
      'age': int.parse(ageController.text.trim()),
      'bio': bioController.text.trim(),
      'location': locationController.text.trim(),
      'photos': photoUrls,
      'interests': ['Music', 'Travel', 'Movies'],
      'gender': 'Female',
    });

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MyHomePage(title: 'Discover')),
    );
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    _photos
                        .map(
                          (photo) => Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: FileImage(photo),
                              ),
                              Positioned(
                                right: -10,
                                top: -10,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      setState(() => _photos.remove(photo)),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList()
                      ..add(
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: pickPhoto,
                              child: CircleAvatar(
                                radius: 40,
                                child: const Icon(Icons.add_a_photo),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
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

// ------------------ HOME PAGE ------------------
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _cards = [];
  late final SwipableStackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SwipableStackController();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final currentUser = FirebaseAuth.instance.currentUser;
    setState(() {
      _cards.addAll(
        snapshot.docs
            .where((doc) => doc.id != currentUser!.uid)
            .map(
              (doc) => {
                'uid': doc.id,
                'name': doc['name'],
                'age': doc['age'],
                'bio': doc['bio'],
                'photos': doc['photos'] ?? [],
                'interests': doc['interests'] ?? [],
                'gender': doc['gender'] ?? '',
              },
            ),
      );
    });
  }

  Future<void> _handleSwipe(Map<String, dynamic> user, bool liked) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('likes')
        .doc(currentUser.uid);
    await docRef.set({}, SetOptions(merge: true));
    final subRef = docRef.collection('userLikes').doc(user['uid']);
    await subRef.set({'liked': liked});

    if (liked) {
      final otherLikeDoc = await FirebaseFirestore.instance
          .collection('likes')
          .doc(user['uid'])
          .collection('userLikes')
          .doc(currentUser.uid)
          .get();
      if (otherLikeDoc.exists && otherLikeDoc['liked'] == true) {
        final chatId = [currentUser.uid, user['uid']]..sort();
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId.join('_'))
            .set({
              'users': [currentUser.uid, user['uid']],
              'createdAt': FieldValue.serverTimestamp(),
            });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('It\'s a match with ${user['name']}!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: SwipableStack(
          controller: _controller,
          itemCount: _cards.length,
          onSwipeCompleted: (index, direction) {
            final user = _cards[index];
            _handleSwipe(user, direction == SwipeDirection.right);
          },
          overlayBuilder: (context, properties) {
            if (properties.direction == SwipeDirection.right) {
              return Center(
                child: Text(
                  'LIKE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            } else if (properties.direction == SwipeDirection.left) {
              return Center(
                child: Text(
                  'NOPE',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }
            return Container();
          },
          builder: (context, properties) {
            final user = _cards[properties.index];
            int currentPage = 0;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              elevation: 8,
              child: Stack(
                children: [
                  if (user['photos'].isNotEmpty)
                    PageView.builder(
                      itemCount: user['photos'].length,
                      onPageChanged: (index) =>
                          setState(() => currentPage = index),
                      itemBuilder: (context, index) {
                        return Image.network(
                          user['photos'][index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${user['name']}, ${user['age']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (user['gender'].isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurpleAccent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user['gender'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['bio'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: (user['interests'] as List)
                              .map(
                                (e) => Chip(
                                  backgroundColor: Colors.deepPurple,
                                  label: Text(
                                    e,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(user['photos'].length, (
                            index,
                          ) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentPage == index
                                    ? Colors.deepPurple
                                    : Colors.white30,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: 'dislike',
              onPressed: () =>
                  _controller.next(swipeDirection: SwipeDirection.left),
              backgroundColor: Colors.red,
              child: const Icon(Icons.thumb_down),
            ),
            FloatingActionButton(
              heroTag: 'like',
              onPressed: () =>
                  _controller.next(swipeDirection: SwipeDirection.right),
              backgroundColor: Colors.green,
              child: const Icon(Icons.thumb_up),
            ),
          ],
        ),
      ),
    );
  }
}
