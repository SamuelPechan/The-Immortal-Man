import 'package:flutter/material.dart';
import 'Nutrition.dart';
import 'AboutUs.dart';
import 'Courses.dart';
import 'Settings.dart';
import 'Fitness.dart';
import 'Forums.dart';
import 'faq.dart';
import 'in_person_trainings.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.1, // Make buttons slightly wider than tall
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(), // Prevents grid from scrolling
                  children: [
                    _buildNavigationButton(
                      context,
                      'About\nThe Immortal Man',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutUs(),
                          ),
                        );
                      },
                      imagePath: 'assets/fire.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'Courses',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Courses(),
                          ),
                        );
                      },
                      imagePath: 'assets/Courses.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'Nutrition',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Nutrition(),
                          ),
                        );
                      },
                      imagePath: 'assets/Steak.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'Fitness',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Fitness(),
                          ),
                        );
                      },
                      imagePath: 'assets/Fitness.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'Brotherhood\nForum',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Forums(),
                          ),
                        );
                      },
                      imagePath: 'assets/Forums.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'Training',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InPersonTrainings(),
                          ),
                        );
                      },
                      imagePath: 'assets/InPersonTrainings.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'FAQ',
                      Colors.amber,
                          () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FAQScreen(),
                          ),
                        );
                      },
                      imagePath: 'assets/FAQ.png',
                    ),
                    _buildNavigationButton(
                      context,
                      'Settings',
                      Colors.amber,
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Settings(),
                          ),
                        );
                      },
                      imagePath: 'assets/Settings.png',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onPressed,
    {String? imagePath}
  ) {
    // Calculate responsive sizes
    final screenSize = MediaQuery.of(context).size;
    final imageSize = screenSize.width * 0.15;
    final fontSize = screenSize.width * 0.045;

    return Container(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orangeAccent, Colors.amber],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imagePath != null)
                  Image.asset(
                    imagePath,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading image: $error');
                      return Icon(
                        Icons.error_outline,
                        color: Colors.black,
                        size: imageSize * 0.5,
                      );
                    },
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
