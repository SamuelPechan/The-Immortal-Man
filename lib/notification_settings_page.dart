import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_app_bar.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Notification settings
  bool _notifyNewPosts = true;
  bool _notifyCommentsOnPosts = true;
  bool _notifyReplies = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved notification settings
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _notifyNewPosts = prefs.getBool('notify_new_posts') ?? true;
        _notifyCommentsOnPosts = prefs.getBool('notify_comments_on_posts') ?? true;
        _notifyReplies = prefs.getBool('notify_replies') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save notification settings
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('notify_new_posts', _notifyNewPosts);
      await prefs.setBool('notify_comments_on_posts', _notifyCommentsOnPosts);
      await prefs.setBool('notify_replies', _notifyReplies);
      
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved!'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
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
        title: 'Notification Settings',
        onBackPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push Notifications',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose which notifications you want to receive',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                
                // New forum posts notification
                _buildNotificationToggle(
                  title: 'New Forum Posts',
                  subtitle: 'Get notified when new forum posts are created',
                  value: _notifyNewPosts,
                  onChanged: (value) {
                    setState(() {
                      _notifyNewPosts = value;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Comments on your posts notification
                _buildNotificationToggle(
                  title: 'Comments on Your Posts',
                  subtitle: 'Get notified when someone comments on your posts',
                  value: _notifyCommentsOnPosts,
                  onChanged: (value) {
                    setState(() {
                      _notifyCommentsOnPosts = value;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Replies to your comments notification
                _buildNotificationToggle(
                  title: 'Replies to Your Comments',
                  subtitle: 'Get notified when someone replies to your comments',
                  value: _notifyReplies,
                  onChanged: (value) {
                    setState(() {
                      _notifyReplies = value;
                    });
                  },
                ),
                
                const Spacer(),
                
                // Save button with gradient
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      elevation: 0,
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
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 18,
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

  // Helper method to build notification toggle
  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.amber,
            activeTrackColor: Colors.amber.withOpacity(0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
} 