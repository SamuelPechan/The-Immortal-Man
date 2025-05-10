import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';
import 'custom_app_bar.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Create or update user profile
  Future<Map<String, dynamic>?> createUserProfile({
    required String userId,
    required String name,
    required String email,
    File? imageFile,
  }) async {
    try {
      // Handle profile picture if provided
      String? photoURL;
      if (imageFile != null) {
        final storageRef = _storage.ref().child('profilePictures').child(userId);
        final uploadTask = await storageRef.putFile(imageFile);
        photoURL = await uploadTask.ref.getDownloadURL();
      } else {
        // Check if user already has a photoURL in Firebase Auth
        final User? currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.photoURL != null) {
          photoURL = currentUser.photoURL;
        }
      }
      
      // Create user profile document
      final userRef = _firestore.collection('users').doc(userId);
      final userData = {
        'name': name,
        'email': email,
        if (photoURL != null) 'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Check if profile exists
      final docSnapshot = await userRef.get();
      if (!docSnapshot.exists) {
        // Add createdAt only for new documents
        userData['createdAt'] = FieldValue.serverTimestamp();
      }
      
      // Update with merge to preserve existing data
      await userRef.set(userData, SetOptions(merge: true));
      
      debugPrint('User profile created successfully');
      return {
        'name': name,
        'email': email,
        'photoURL': photoURL,
      };
    } catch (error) {
      debugPrint('Error creating user profile: $error');
      return null;
    }
  }
  
  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userSnap = await userRef.get();
      
      if (userSnap.exists) {
        return userSnap.data();
      } else {
        debugPrint('No such profile exists!');
        return null;
      }
    } catch (error) {
      debugPrint('Error fetching user profile: $error');
      return null;
    }
  }
  
  // Update profile picture
  Future<String?> updateProfilePicture(String userId, File imageFile) async {
    try {
      debugPrint('Starting profile picture update for user: $userId');
      
      // First ensure the image file exists and is readable
      if (!await imageFile.exists()) {
        debugPrint('Error: Image file does not exist');
        return null;
      }
      
      debugPrint('Image file exists, proceeding with upload');
      
      // Upload to Firebase Storage
      final storageRef = _storage.ref().child('profilePictures').child(userId);
      final uploadTask = await storageRef.putFile(imageFile);
      final photoURL = await uploadTask.ref.getDownloadURL();
      
      debugPrint('Image uploaded successfully, URL: $photoURL');
      
      // Update Firestore profile
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.update({
        'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Firestore profile updated with new photoURL');
      
      // Update Firebase Auth user photo URL
      final user = _auth.currentUser;
      if (user != null && user.uid == userId) {
        debugPrint('Updating Firebase Auth photoURL');
        try {
          await user.updatePhotoURL(photoURL);
          debugPrint('Firebase Auth photoURL updated successfully');
        } catch (authError) {
          debugPrint('Error updating Firebase Auth photoURL: $authError');
          // Continue even if Auth update fails, as we've already updated Firestore
        }
      } else {
        debugPrint('No matching current user found to update Auth profile');
      }
      
      debugPrint('Profile picture update completed successfully');
      return photoURL;
    } catch (error) {
      debugPrint('Error updating profile picture: $error');
      if (error is FirebaseException) {
        debugPrint('Firebase error code: ${error.code}');
        debugPrint('Firebase error message: ${error.message}');
      }
      return null;
    }
  }
  
  // Setup profile after sign-up - callable from login or registration flow
  Future<void> setupProfileAfterSignUp() async {
    final user = _auth.currentUser;
    if (user != null) {
      await createUserProfile(
        userId: user.uid, 
        name: user.displayName ?? 'New User', 
        email: user.email ?? '',
      );
    }
  }
  
  // Delete user profile and associated data
  Future<bool> deleteUserProfile(String userId) async {
    try {
      debugPrint('Starting user profile deletion for user: $userId');
      
      // Delete profile picture from storage if it exists
      try {
        final storageRef = _storage.ref().child('profilePictures').child(userId);
        await storageRef.delete();
        debugPrint('Profile picture deleted from storage');
      } catch (e) {
        // It's okay if the profile picture doesn't exist
        debugPrint('No profile picture found or error deleting: $e');
      }
      
      // Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();
      debugPrint('User document deleted from Firestore');
      
      // Delete any forum posts or other user content if needed
      // This would depend on your data structure
      // Example: Get all posts by this user and delete them
      final userPosts = await _firestore.collection('forumPosts')
          .where('authorId', isEqualTo: userId)
          .get();
      
      for (var doc in userPosts.docs) {
        await _firestore.collection('forumPosts').doc(doc.id).delete();
      }
      
      debugPrint('Deleted ${userPosts.docs.length} forum posts by user');
      
      // Delete user comments if you have them
      final userComments = await _firestore.collection('comments')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in userComments.docs) {
        await _firestore.collection('comments').doc(doc.id).delete();
      }
      
      debugPrint('Deleted ${userComments.docs.length} comments by user');
      
      return true;
    } catch (error) {
      debugPrint('Error deleting user profile: $error');
      return false;
    }
  }
}

class ProfilePage extends StatefulWidget {
  final String? userId; // The ID of the user whose profile to display
  final bool viewOnly; // Whether this is view-only mode (no editing)

  const ProfilePage({
    super.key, 
    this.userId, // Optional - if null, will show current user's profile
    this.viewOnly = false, // Default to edit mode for backward compatibility
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  // User information
  String _username = "User Name";
  String? _photoUrl;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  
  // Text editing controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  // Add new controller declarations in the _ProfilePageState class
  final TextEditingController _emailContactController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _otherSocialController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _nameController.text = _username;
    _emailController.text = currentUser?.email ?? 'Email not available';
    _loadUserData();
  }
  
  // Load user profile data from Firestore - updated to use UserProfileService
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Determine which user ID to use
      String? profileUserId;
      
      if (widget.viewOnly && widget.userId != null) {
        // If in view-only mode with a specific user ID, use that
        profileUserId = widget.userId;
        debugPrint('Loading profile in view-only mode for user: $profileUserId');
      } else {
        // Otherwise, use the current authenticated user
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user found');
        }
        profileUserId = currentUser.uid;
        debugPrint('Loading profile for current user: $profileUserId');
      }

      // Get the user document from Firestore
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(profileUserId)
          .get();

      if (documentSnapshot.exists) {
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _username = data['name'] ?? 'User Name';
          _nameController.text = _username;
          
          // In view-only mode, we still need the email but don't always have it
          if (!widget.viewOnly) {
            User? currentUser = FirebaseAuth.instance.currentUser;
            _emailController.text = currentUser?.email ?? '';
          } else {
            _emailController.text = data['email'] ?? 'Email not available';
          }
          
          _photoUrl = data['photoURL'];
          
          // Set the bio field if it exists
          _bioController.text = data['bio'] ?? '';
          
          // Set contact information fields
          _emailContactController.text = data['contactEmail'] ?? '';
          _facebookController.text = data['facebookProfile'] ?? '';
          _instagramController.text = data['instagramProfile'] ?? '';
          _otherSocialController.text = data['otherSocial'] ?? '';
          
          _isLoading = false;
        });
      } else {
        // If user document doesn't exist but we have auth data
        if (!widget.viewOnly) {
          User? currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            setState(() {
              _nameController.text = currentUser.displayName ?? 'User Name';
              _emailController.text = currentUser.email ?? '';
              _photoUrl = currentUser.photoURL;
              _isLoading = false;
            });
          } else {
            throw Exception('User profile not found');
          }
        } else {
          throw Exception('Profile not found or does not exist anymore.');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }
  
  // Function to pick image
  Future<void> _pickImage() async {
    try {
      debugPrint('Opening image picker');
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Reduce image quality slightly for better performance
      );
      
      if (pickedImage != null) {
        debugPrint('Image selected: ${pickedImage.path}');
        final imageFile = File(pickedImage.path);
        
        // Verify the file exists
        if (await imageFile.exists()) {
          debugPrint('Image file exists, setting profile image');
          setState(() {
            _profileImage = imageFile;
          });
        } else {
          debugPrint('Error: Image file does not exist at path: ${pickedImage.path}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not load the selected image'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('No image selected from picker');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Helper method to read file as bytes
  Future<Uint8List?> _getImageBytes(File imageFile) async {
    try {
      return await imageFile.readAsBytes();
    } catch (e) {
      debugPrint('Error reading image file as bytes: $e');
      return null;
    }
  }
  
  // Save profile changes to Firestore - updated to use UserProfileService
  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      final userId = _auth.currentUser!.uid;
      debugPrint('Saving profile for user: $userId');
      
      // Handle profile image upload if there's a new image
      if (_profileImage != null) {
        debugPrint('Uploading new profile image');
        
        try {
          // First check if file exists
          if (!await _profileImage!.exists()) {
            debugPrint('Profile image file no longer exists at path: ${_profileImage!.path}');
            throw Exception('Selected image file no longer exists');
          }
          
          // Convert File to Uint8List (bytes)
          final imageBytes = await _getImageBytes(_profileImage!);
          if (imageBytes == null) {
            throw Exception('Failed to read image file');
          }
          
          debugPrint('Successfully read image as bytes: ${imageBytes.length} bytes');
          
          // Create a simple filename with user ID to enforce ownership
          final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Reference to Firebase Storage - use public_uploads folder which should have less restrictive permissions
          final storageRef = FirebaseStorage.instance
            .ref()
            .child('public_uploads')
            .child(fileName);
          
          debugPrint('Uploading to storage path: ${storageRef.fullPath}');
          
          // Upload image data with metadata
          await storageRef.putData(
            imageBytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'userId': userId,
                'uploadedAt': DateTime.now().toIso8601String(),
                'purpose': 'profile_picture'
              }
            ),
          );
          
          // Get download URL
          final newPhotoUrl = await storageRef.getDownloadURL();
          
          debugPrint('Image uploaded successfully, URL: $newPhotoUrl');
          
          // Update Auth user photo URL
          await _auth.currentUser!.updatePhotoURL(newPhotoUrl);
          
          setState(() {
            _photoUrl = newPhotoUrl;
          });
          
          debugPrint('New profile image uploaded: $_photoUrl');
        } catch (uploadError) {
          debugPrint('Failed to upload profile image: $uploadError');
          
          // Provide more specific error messages for common issues
          String errorMessage = 'Failed to upload profile image';
          
          if (uploadError is FirebaseException) {
            debugPrint('Firebase error code: ${uploadError.code}');
            debugPrint('Firebase error message: ${uploadError.message}');
            
            switch (uploadError.code) {
              case 'unauthorized':
              case 'permission-denied':
                errorMessage = 'Permission denied. Your Firebase Storage rules need to be updated to allow image uploads.';
                break;
              case 'canceled':
                errorMessage = 'Image upload was canceled';
                break;
              case 'storage/quota-exceeded':
                errorMessage = 'Storage quota exceeded. Please contact support.';
                break;
              default:
                errorMessage = 'Upload error: ${uploadError.message}';
            }
          }
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          // Continue with other profile updates even if image upload fails
        }
      }
      
      // Update profile data in Firestore
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      
      final updatedData = {
        'name': _nameController.text.trim(),
        if (_photoUrl != null) 'photoURL': _photoUrl,
        'bio': _bioController.text.trim(),
        
        // Add contact information fields
        'contactEmail': _emailContactController.text.trim(),
        'facebookProfile': _facebookController.text.trim(),
        'instagramProfile': _instagramController.text.trim(),
        'otherSocial': _otherSocialController.text.trim(),
        
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      await userRef.set(updatedData, SetOptions(merge: true));
      
      // Update Auth displayName
      await _auth.currentUser!.updateDisplayName(_nameController.text.trim());
      
      // Update username state
      setState(() {
        _username = _nameController.text.trim();
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      setState(() {
        _errorMessage = 'Error updating profile: $e';
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
        _profileImage = null; // Clear the selected image after saving
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: widget.viewOnly ? _username : 'My Profile',
        onBackPressed: () => Navigator.pop(context),
        actions: [
          if (!widget.viewOnly)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: _signOut,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.amber,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(
                                    _profileImage!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                    ? Image.network(
                                        _photoUrl!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.amber,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 120,
                                            height: 120,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.person,
                                              size: 80,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.person,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                      ),
                          ),
                        ),
                        // Only show edit camera button if not in view-only mode
                        if (!widget.viewOnly)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // Profile Form
                    ProfileTextField(
                      controller: _nameController,
                      label: 'Name',
                      icon: Icons.person,
                      enabled: !widget.viewOnly, // Disable editing in view-only mode
                    ),
                    const SizedBox(height: 16),
                    // Contact Information Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contact Information',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ProfileTextField(
                            controller: _emailContactController,
                            label: 'Email',
                            icon: Icons.email,
                            enabled: !widget.viewOnly,
                          ),
                          const SizedBox(height: 12),
                          ProfileTextField(
                            controller: _facebookController,
                            label: 'Facebook',
                            icon: Icons.public,
                            enabled: !widget.viewOnly,
                          ),
                          const SizedBox(height: 12),
                          ProfileTextField(
                            controller: _instagramController,
                            label: 'Instagram',
                            icon: Icons.photo_camera,
                            enabled: !widget.viewOnly,
                          ),
                          const SizedBox(height: 12),
                          ProfileTextField(
                            controller: _otherSocialController,
                            label: 'Other Social Media',
                            icon: Icons.share,
                            enabled: !widget.viewOnly,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About Me',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ProfileTextField(
                            controller: _bioController,
                            label: 'Bio',
                            icon: Icons.description,
                            maxLines: 3,
                            enabled: !widget.viewOnly,
                          ),
                        ],
                      ),
                    ),
                    // Only show action buttons if not in view-only mode
                    if (!widget.viewOnly) ...[
                      const SizedBox(height: 32),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.0,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sign Out Button
                      TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newEmailController.dispose();
    _bioController.dispose();
    
    // Dispose new controllers
    _emailContactController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _otherSocialController.dispose();
    
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Add this custom widget for profile text fields
class ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool enabled;
  final TextInputType keyboardType;

  const ProfileTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.amber),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white12,
        prefixIcon: Icon(icon, color: Colors.amber),
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
    );
  }
} 