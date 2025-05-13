import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async'; // Add this import for Timer and async utilities
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add proper error handling for Firebase initialization
  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
    
    // Test Firestore connection
    try {
      debugPrint('Testing Firestore connection...');
      
      // Check Firestore connection by attempting to access settings
      FirebaseFirestore.instance.settings.toString();
      
      // If we get here, Firestore connection works
      debugPrint('Firestore connection successful');
      
      // Check if 'forum_posts' collection exists
      final testQuery = await FirebaseFirestore.instance.collection('forum_posts').limit(1).get();
      debugPrint('Forum posts collection exists: ${testQuery.size > 0 ? 'Yes (has posts)' : 'Yes (empty)'}');
    } catch (firestoreError) {
      debugPrint('Firestore connection test failed: $firestoreError');
      // We'll still continue with the app, as this is just a test
    }
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
    // Show an error UI or handle gracefully
    runApp(FirebaseErrorApp(error: e.toString()));
    return;
  }
  
  runApp(const MyApp());
}

// Error app to show when Firebase fails to initialize
class FirebaseErrorApp extends StatelessWidget {
  final String error;
  
  const FirebaseErrorApp({super.key, this.error = "Unknown error"});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFD4AF37),
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Unable to connect to the server. Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(51), // 0.2 opacity = 51/255
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Error details: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      main();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to LoginPage after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/The_Immortal_Man_First_Icon_Updated.png'),
              width: 400,
              height: 400,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }
}
