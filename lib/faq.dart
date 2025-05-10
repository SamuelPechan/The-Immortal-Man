import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'navigation_screen.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: CustomAppBar(
          title: "Frequently Asked Questions",
          onBackPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const NavigationScreen(),
              ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          FAQItem(
            question: "What is The Immortal Man?",
            answer: "The Immortal Man is a comprehensive fitness and wellness platform designed to help you achieve optimal health and longevity through nutrition, fitness, and community support."
          ),
          FAQItem(
            question: "How do I sign up for courses?",
            answer: "You can sign up for courses through the 'Courses' section of the app. Browse available options and select the one that best fits your goals and interests."
          ),
          FAQItem(
            question: "How can I participate in the community forums?",
            answer: "Navigate to the 'Forum' section of the app where you can view discussions, create posts, and interact with other community members."
          ),
          FAQItem(
            question: "What nutrition plans are available?",
            answer: "We offer various nutrition approaches tailored to different goals and dietary preferences. Check the 'Nutrition' section for detailed information on available plans."
          ),
          FAQItem(
            question: "How do I sign up for in-person training?",
            answer: "Visit the 'In-Person Trainings' section to view available sessions and locations. You can book directly through the app."
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const FAQItem({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  State<FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orangeAccent, Colors.amber],
          ),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: ExpansionTile(
          title: Text(
            widget.question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
              color: Colors.black,
            ),
          ),
          collapsedIconColor: Colors.black,
          iconColor: Colors.black,
          onExpansionChanged: (expanded) {
            // No need to store state as ExpansionTile handles it internally
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  fontSize: 14.0,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
