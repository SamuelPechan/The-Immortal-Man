import 'package:flutter/material.dart';
import 'navigation_screen.dart';
import 'custom_app_bar.dart';

class Fitness extends StatelessWidget {
  const Fitness({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'Fitness',
        onBackPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const NavigationScreen(),
            ),
          );
        },
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Coming soon text with gold color
            const Text(
              'Coming Soon!',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Additional description text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'New fitness content is being developed for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 