import 'package:flutter/material.dart';
import 'navigation_screen.dart';
import 'custom_app_bar.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_page.dart'; // Import for ProfilePage and UserProfileService
import 'authentication_persistence.dart'; // Import the persistence service
import 'notification_settings_page.dart'; // Import notification settings page
import 'password_change_page.dart'; // Import password change page

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _profileService = UserProfileService();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload the user to get the latest data
      if (_auth.currentUser != null) {
        debugPrint('Reloading user data in Settings page');
        await _auth.currentUser!.reload();
        _currentUser = _auth.currentUser;
        
        // Log the current photo URL for debugging
        debugPrint('Current user photo URL: ${_currentUser?.photoURL}');
      } else {
        debugPrint('No authenticated user found when loading Settings');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to delete user account
  Future<void> _deleteAccount(BuildContext context) async {
    // Show confirmation dialog
    final bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.amber),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.amber),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 16),
              Text(
                'Deleting account...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userId = user.uid;
        
        // First delete user data from Firestore using UserProfileService
        final success = await _profileService.deleteUserProfile(userId);
        
        if (!success) {
          throw Exception('Failed to delete user data');
        }
        
        // Then delete the user account
        await user.delete();
        
        // Clear saved credentials
        await AuthenticationPersistence.clearCredentials();
        
        if (context.mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deleted.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Close loading dialog if it's open
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      String errorMessage = 'Failed to delete account.';
      
      // Handle specific error cases
      if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log out and log back in before deleting your account.';
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'Settings',
        onBackPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const NavigationScreen(),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile button with user's profile picture
            _buildProfileButton(
              context,
              title: 'My Profile',
              onTap: () async {
                debugPrint('Profile button tapped, navigating to profile page');
                
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
                
                debugPrint('Returned from profile page');
                
                // Always reload user data when returning from profile page
                _loadUserData();
              },
            ),
            
            const SizedBox(height: 16),
            
            // Notifications button
            _buildSettingsButton(
              context,
              icon: Icons.notifications,
              title: 'Notification Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsPage(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password change button
            _buildSettingsButton(
              context,
              icon: Icons.lock,
              title: 'Change Password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PasswordChangePage(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Delete Account button
            _buildSettingsButton(
              context,
              icon: Icons.delete_forever,
              title: 'Delete Account',
              onTap: () => _deleteAccount(context),
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
            ),
            
            // Spacer to push logout button to bottom
            const Spacer(),
            
            // Logout button with gradient instead of solid color
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Clear saved credentials
                  await AuthenticationPersistence.clearCredentials();
                  
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();
                  
                  // Navigate to login screen
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  elevation: 0, // No shadow
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    width: double.infinity,
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Special profile button with user photo
  Widget _buildProfileButton(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: _isLoading
            ? const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.amber,
                  strokeWidth: 2,
                ),
              )
            : SizedBox(
                key: ValueKey<String?>(_currentUser?.photoURL ?? 'no-profile-photo'),
                width: 36,
                height: 36,
                child: ClipOval(
                  child: _currentUser?.photoURL != null
                      ? Image.network(
                          _currentUser!.photoURL!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          // Add error handling
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error loading profile image in settings: $error');
                            return const Icon(
                              Icons.person,
                              color: Colors.amber,
                              size: 20,
                            );
                          },
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.amber,
                          size: 20,
                        ),
                ),
              ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _currentUser?.displayName ?? 'User',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.amber,
        ),
        onTap: onTap,
      ),
    );
  }
  
  // Helper method to build settings buttons with consistent styling
  Widget _buildSettingsButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.amber,
    Color textColor = Colors.amber,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor,
          size: 30,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: iconColor,
        ),
        onTap: onTap,
      ),
    );
  }
} 