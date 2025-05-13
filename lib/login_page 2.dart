import 'package:flutter/material.dart';
import 'navigation_screen.dart';
import 'sign_up_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';  // Add this import for Timer and TimeoutException
import 'profile_page.dart'; // Import for UserProfileService
import 'authentication_persistence.dart'; // Import the persistence service
import 'utils/gradient_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _profileService = UserProfileService(); // Initialize the service
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    setState(() => _isLoading = true);
    
    try {
      _rememberMe = await AuthenticationPersistence.getRememberMe();
      
      if (_rememberMe) {
        final savedEmail = await AuthenticationPersistence.getSavedEmail();
        final savedPassword = await AuthenticationPersistence.getSavedPassword();
        
        if (savedEmail != null) {
          _emailController.text = savedEmail;
        }
        
        if (savedPassword != null) {
          _passwordController.text = savedPassword;
        }
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void loginUser() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Save credentials if remember me is checked
      await AuthenticationPersistence.saveCredentials(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _rememberMe,
      );
      
      // Check if user has a profile, create one if not
      final profile = await _profileService.getUserProfile(userCredential.user!.uid);
      if (profile == null) {
        // Create basic profile if none exists
        await _profileService.createUserProfile(
          userId: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'User Name',
          email: userCredential.user!.email ?? '',
        );
      }

      // Navigate to next screen if login is successful
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavigationScreen()),
      );
    } on FirebaseAuthException catch (error) {
      String errorMessage = 'An error occurred during login.';

      switch (error.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please enter a valid email.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password sign-in is not enabled.';
          break;
        case 'missing-password':
          errorMessage = 'Please enter both email and password.';
        default:
          errorMessage = error.message ?? errorMessage;
      }

      // Show error message in UI
      if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Add this new method to handle password reset
  void _handleForgotPassword() async {
    // Create a separate controller for reset email to avoid conflicts with login
    final resetEmailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.amber),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address to receive a password reset link.',
              style: TextStyle(color: Colors.amber),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController, // Use the new controller
              style: const TextStyle(color: Colors.amber),
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: const TextStyle(color: Colors.amber),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.amber),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.amber, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.amber),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              
              // Validate email is not empty
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your email address'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Validate email format
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Close the dialog first
              Navigator.pop(context);

              // Show a loading message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sending password reset email...'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );

              try {
                // Set a timeout for the operation
                bool completed = false;
                
                // Start a timer that will show an error if the operation takes too long
                Timer timeoutTimer = Timer(const Duration(seconds: 15), () {
                  if (!completed && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('The request is taking longer than expected. Please check your network connection.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                });
                
                // Send password reset email
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                
                // Mark as completed to cancel the timeout message
                completed = true;
                timeoutTimer.cancel();
                
                if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent! Check your inbox and spam folder.'),
                    backgroundColor: Colors.amber,
                    duration: Duration(seconds: 5),
                  ),
                );
                }
              } catch (e) {
                debugPrint('Password reset error: $e');
                
                if (context.mounted) {
                  String errorMessage;
                  
                  if (e is FirebaseAuthException) {
                    switch (e.code) {
                      case 'invalid-email':
                  errorMessage = 'Please enter a valid email address.';
                        break;
                      case 'user-not-found':
                        // Due to security reasons, we don't want to reveal if an email exists
                        errorMessage = 'If this email is registered, a reset link will be sent.';
                        break;
                      case 'network-request-failed':
                        errorMessage = 'Network error. Please check your internet connection.';
                        break;
                      default:
                        errorMessage = 'An error occurred. Please try again later.';
                        break;
                    }
                  } else {
                    errorMessage = 'An unexpected error occurred. Please try again later.';
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
                }
              }
            },
            child: const Text(
              'Send Reset Link',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Image(
                    image: AssetImage('assets/The_Immortal_Man_First_Icon_Updated.png'),
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: const TextStyle(color: Colors.amber), // Gold hint text
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber), // Gold border
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber), // Gold border
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber, width: 2), // Thicker gold border when focused
                      ),
                    ),
                    style: const TextStyle(color: Colors.amber), // White typing text
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Colors.amber), // Gold hint text
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber), // Gold border
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber), // Gold border
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber, width: 2), // Thicker gold border when focused
                      ),
                    ),
                    style: const TextStyle(color: Colors.amber), // White typing text
                  ),
                  const SizedBox(height: 12),
                  
                  // Remember me checkbox
                  Row(
                    children: [
                      Theme(
                        data: Theme.of(context).copyWith(
                          checkboxTheme: CheckboxThemeData(
                            fillColor: WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFFD4AF37);
                                }
                                return Colors.white12;
                              },
                            ),
                            checkColor: WidgetStateProperty.all(Colors.black),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: _isLoading ? null : (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Remember me',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  GradientButton(
                    text: 'Login',
                    height: 55,
                    width: double.infinity,
                    onPressed: _isLoading ? null : loginUser,
                    isLoading: _isLoading,
                    loadingText: 'Logging in...',
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
