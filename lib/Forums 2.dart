import 'package:flutter/material.dart';
import 'navigation_screen.dart';
import 'forum_detail_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'custom_app_bar.dart';
import 'utils/gradient_button.dart';

// Add this enum at the top of the file, after imports
enum ForumSortOption {
  newest,
  mostLiked
}

class ForumPost {
  final String id;
  String title;
  String description;
  String? imageUrl; // Changed to URL for Firebase Storage
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  int views;
  int replies;
  bool isExpanded;
  bool isEdited; // Added to track if post has been edited
  File? imageFile; // Only used locally before upload
  String? authorProfilePic;
  int likes; // Added for tracking likes count
  List<String> likedBy; // Added to track who liked the post

  ForumPost({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.views = 0,
    this.replies = 0,
    this.isExpanded = false,
    this.isEdited = false, // Default to false
    this.imageFile,
    this.authorProfilePic,
    this.likes = 0, // Default to 0 likes
    List<String>? likedBy, // Default to empty list
  }) : likedBy = likedBy ?? [];

  // Create a ForumPost from a Firestore document
  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ForumPost(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorProfilePic: data['authorProfilePic'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      views: data['views'] ?? 0,
      replies: data['replies'] ?? 0,
      isEdited: data['isEdited'] ?? false,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  // Convert ForumPost to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'views': views,
      'replies': replies,
      'isEdited': isEdited,
      'authorProfilePic': authorProfilePic,
      'likes': likes,
      'likedBy': likedBy,
    };
  }
}

class Forums extends StatefulWidget {
  const Forums({super.key});

  @override
  State<Forums> createState() => _ForumsState();
}

class _ForumsState extends State<Forums> {
  late List<ForumPost> _posts = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final int _maxDescriptionLength = 500; // Character limit for description
  File? _selectedImage;
  bool _isLoading = true;
  ForumSortOption _currentSortOption = ForumSortOption.newest; // Add sorting option state
  
  // Static flag to prevent multiple simultaneous post submissions
  static bool _isCurrentlyPostingToForum = false;
  
  // Firebase references
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // Load posts from Firestore
  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get all posts with simple error handling
      try {
        // Update query based on sort option
        Query query = _firestore.collection('forum_posts');
        
        switch (_currentSortOption) {
          case ForumSortOption.newest:
            query = query.orderBy('createdAt', descending: true);
            break;
          case ForumSortOption.mostLiked:
            query = query.orderBy('likes', descending: true);
            break;
        }
        
        final snapshot = await query.get().timeout(const Duration(seconds: 10));
        
        // Convert posts from Firestore documents
        final posts = snapshot.docs.map((doc) {
          try {
            return ForumPost.fromFirestore(doc);
          } catch (e) {
            // Return a basic post if there's an error parsing
            return ForumPost(
              id: doc.id,
              title: 'Error loading post',
              description: 'There was an error loading this post.',
              authorId: '',
              authorName: 'Unknown',
              createdAt: DateTime.now(),
            );
          }
        }).toList();
        
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
        
        // If no posts were found, create a sample post
        if (posts.isEmpty && _auth.currentUser != null) {
          _createSamplePost();
        }
      } catch (firestoreError) {
        // Handle specific Firestore errors
        String errorMessage = 'Failed to load posts';
        if (firestoreError is FirebaseException) {
          switch (firestoreError.code) {
            case 'permission-denied':
              errorMessage = 'Access denied. Check your Firestore rules.';
              // Show the Firestore rules dialog to help set up proper permissions
              if (context.mounted) {
                _showFirestoreRulesDialog();
              }
              break;
            case 'unavailable':
            case 'network-request-failed':
              errorMessage = 'Network error. Please check your internet connection.';
              break;
            default:
              errorMessage = 'Error: ${firestoreError.message}';
          }
        }
        
        setState(() {
          _isLoading = false;
        });
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadPosts,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load forum posts: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadPosts,
            ),
          ),
        );
      }
    }
  }

  // Create a sample post if there are no posts in the database
  Future<void> _createSamplePost() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Reload user to get the latest data including photoURL
      await user.reload();
      final refreshedUser = _auth.currentUser!;
      
      // Create a new document in Firestore
      await _firestore.collection('forum_posts').add({
        'title': 'Welcome to the Forum!',
        'description': 'This is a sample post to help you get started. Feel free to create your own posts or reply to this one!',
        'authorId': refreshedUser.uid,
        'authorName': refreshedUser.displayName ?? 'App User',
        'authorProfilePic': refreshedUser.photoURL,
        'createdAt': Timestamp.now(),
        'views': 0,
        'replies': 0,
        'likes': 0,
        'likedBy': [],
      });
      
      // Reload posts to show the sample post
      _loadPosts();
    } catch (e) {
      // Just silently fail if we can't create the sample post
    }
  }

  // Pick an image from the gallery
  Future<File?> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }

  // Add missing _getImage method
  Future<void> _getImage() async {
    final File? image = await _pickImage();
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImage(File? imageFile, String postId) async {
    if (imageFile == null) return null;
    
    try {
      final ref = _storage.ref().child('forum_images').child('$postId.jpg');
      
      // Compress the image
      final List<int> imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(Uint8List.fromList(imageBytes));
      
      if (originalImage == null) {
        throw Exception('Could not decode image');
      }
      
      // Resize the image to a width of 800, maintaining the aspect ratio
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: 800,
        interpolation: img.Interpolation.linear,
      );
      
      // Encode the image with quality settings
      final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Upload the compressed image
      final task = await ref.putData(
        Uint8List.fromList(compressedBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Get the download URL
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // Save post to Firestore
  Future<void> _savePost(String title, String description, File? imageFile) async {
    // Check if already in the process of posting
    if (_ForumsState._isCurrentlyPostingToForum) {
      debugPrint('Post submission already in progress, ignoring duplicate request');
      return;
    }
    
    if (title.isEmpty) return;

    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a post'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the static flag to prevent duplicate submissions
    _ForumsState._isCurrentlyPostingToForum = true;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connection first
      bool connected = await _checkFirestoreConnection();
      if (!connected) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to Firestore. Please check your internet connection and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Reset the flag since we're not proceeding
        _ForumsState._isCurrentlyPostingToForum = false;
        return;
      }

      // Reload user to get the latest data including photoURL
      await user.reload();
      final refreshedUser = _auth.currentUser!;
      
      debugPrint('Creating post with user profile pic: ${refreshedUser.photoURL}');

      // Create a new document in Firestore
      final docRef = await _firestore.collection('forum_posts').add({
        'title': title,
        'description': description,
        'authorId': refreshedUser.uid,
        'authorName': refreshedUser.displayName ?? 'Anonymous',
        'authorProfilePic': refreshedUser.photoURL,
        'createdAt': Timestamp.now(),
        'views': 0,
        'replies': 0,
        'isEdited': false,
        'likes': 0,
        'likedBy': [],
      });

      // Upload image if provided
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile, docRef.id);
        
        // Update the document with the image URL
        if (imageUrl != null) {
          await docRef.update({'imageUrl': imageUrl});
        }
      }

      // Reload posts to show the new post
      await _loadPosts();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to create post';
      
      if (e is FirebaseException) {
        if (e.code == 'unavailable' || e.code == 'network-request-failed') {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.code == 'permission-denied') {
          errorMessage = 'You don\'t have permission to create posts.';
        } else {
          errorMessage = 'Error creating post: ${e.message}';
        }
      } else if (e is TimeoutException) {
        errorMessage = 'Connection timed out. Please check your internet connection.';
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      
      // Always reset the static flag when done
      _ForumsState._isCurrentlyPostingToForum = false;
    }
  }

  // Update view count in Firestore - simplified
  Future<void> _updateViewCount(ForumPost post) async {
    try {
      // Update view count in Firestore
      await _firestore.collection('forum_posts').doc(post.id).update({
        'views': FieldValue.increment(1)
      });
    } catch (e) {
      // Try again with a different approach if normal update failed
      if (e is FirebaseException && e.code == 'permission-denied') {
        try {
          // First get the current document to check the current view count
          final docSnapshot = await _firestore.collection('forum_posts').doc(post.id).get();
          if (docSnapshot.exists) {
            final data = docSnapshot.data() as Map<String, dynamic>;
            final currentViews = data['views'] as int? ?? 0;
            
            // Then update with the new count
            await _firestore.collection('forum_posts').doc(post.id).update({
              'views': currentViews + 1
            });
          }
        } catch (innerError) {
          // If this also fails, we'll just keep the local view count updated
          // but won't worry about persisting it to Firestore
        }
      }
    }
  }

  // Delete post from Firestore
  Future<void> _deletePost(ForumPost post) async {
    try {
      // Check if user is the author
      final User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != post.authorId) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only delete your own posts'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      bool confirmDelete = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Delete Post',
            style: TextStyle(color: Colors.amber),
          ),
          content: const Text(
            'Are you sure you want to delete this post?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.amber),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmDelete) return;

      setState(() {
        _isLoading = true;
      });

      // Delete the image from Storage if it exists
      if (post.imageUrl != null) {
        try {
          await _storage.refFromURL(post.imageUrl!).delete();
        } catch (e) {
          // Continue with post deletion even if image deletion fails
        }
      }

      // Delete the post from Firestore
      await _firestore.collection('forum_posts').doc(post.id).delete();

      // Reload posts
      await _loadPosts();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to show Firestore rules dialog
  void _showFirestoreRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Update Firestore Security Rules',
          style: TextStyle(color: Colors.amber),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IMPORTANT: Your app is experiencing permission issues because the Firestore security rules need to be updated.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To fix the commenting and view count problems, copy these rules to your Firebase Firestore console:',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      '''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow full public access for this app
    match /{document=**} {
      // Anyone can read any document
      allow read: if true;
      
      // Anyone can create documents
      allow create: if true;
      
      // Allow updates and deletions with minimal restrictions
      allow update, delete: if true;
    }
  }
}''',
                      style: TextStyle(
                        color: Colors.amber,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instructions:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Go to the Firebase Console (firebase.google.com)',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '2. Select your project',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '3. Navigate to "Firestore Database" in the sidebar',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '4. Click on the "Rules" tab',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '5. Replace ALL existing rules with the rules above',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '6. Click "Publish"',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'NOTE: These rules provide NO SECURITY but will allow your app to function. For a production app, you would want more restrictive rules.',
                style: TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  // Check if Firestore connection is available - simplified version
  Future<bool> _checkFirestoreConnection() async {
    try {
      // Check internet connectivity first
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // Try to access Firestore with a small timeout to ensure connection is working
      final timeout = const Duration(seconds: 5);
      await _firestore
          .collection('forum_posts')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      
      return true;
    } catch (e) {
      // If there was an error, show the Firestore rules dialog for permission errors
      if (e is FirebaseException && e.code == 'permission-denied' && context.mounted) {
        _showFirestoreRulesDialog();
      }
      return false;
    }
  }

  // Method to toggle between sort options
  void _toggleSortOption() {
    setState(() {
      if (_currentSortOption == ForumSortOption.newest) {
        _currentSortOption = ForumSortOption.mostLiked;
      } else {
        _currentSortOption = ForumSortOption.newest;
      }
    });
    // Reload posts with new sort order
    _loadPosts();
  }

  void _addNewForum() {
    // Reset selected image when opening dialog
    _selectedImage = null;
    _titleController.clear();
    _descriptionController.clear();
    
    // Create a flag to track submission status
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Define a local loading state for the dialog
            bool isDialogLoading = false;
            // Initialize with the result of connection check to make it potentially true
            bool showConnectionError = false;
            
            // Function to check connection and update UI
            Future<void> checkConnection() async {
              setStateDialog(() {
                isDialogLoading = true;
              });
              
              bool connected = await _checkFirestoreConnection();
              
              setStateDialog(() {
                isDialogLoading = false;
                showConnectionError = !connected;
              });
              
              if (connected && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection restored! You can now create your post.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
            
            // Initial connection check when dialog opens
            Future.microtask(() => checkConnection());
            
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Create New Forum',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showConnectionError) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.red),
                            SizedBox(height: 8),
                            Text(
                              'Unable to connect to server',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Please check your internet connection',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => checkConnection(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: isDialogLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Try Again'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.amber),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                        fillColor: const Color(0xFF1A1A1A),
                        filled: true,
                      ),
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.amber),
                      maxLength: _maxDescriptionLength,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Body',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                        fillColor: const Color(0xFF1A1A1A),
                        filled: true,
                        counterStyle: const TextStyle(color: Colors.amber),
                      ),
                      enabled: !isSubmitting,
                    ),
                    // Display selected image if available
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GradientButton(
                        text: _selectedImage == null ? 'Add Image' : 'Change Image',
                        onPressed: isSubmitting ? null : () async {
                          await _getImage();
                          // Using setState from StatefulBuilder to update UI
                          setStateDialog(() {});
                        },
                        height: 45,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    isSubmitting
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Creating...',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GradientButton(
                          text: 'Create Post',
                          onPressed: () async {
                            // Validate form
                            if (_titleController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a title for your post'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            if (_descriptionController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a description for your post'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Immediately set submitting state to prevent multiple clicks
                            setStateDialog(() {
                              isSubmitting = true;
                            });

                            // Create the post
                            await _savePost(
                              _titleController.text,
                              _descriptionController.text,
                              _selectedImage,
                            );
                            
                            // Note: We don't need to set isSubmitting back to false
                            // because we're closing the dialog
                            
                            if (mounted) {
                              Navigator.pop(context); // Close the dialog
                            }
                          },
                          height: 45,
                        ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Edit post dialog
  Future<void> _editPost(ForumPost post) async {
    // First check if user is the author
    final User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit your own posts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final TextEditingController titleController = TextEditingController(text: post.title);
    final TextEditingController descriptionController = TextEditingController(text: post.description);
    File? imageFile;
    bool removeImage = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Edit Post',
              style: TextStyle(color: Colors.amber),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  // Show current image if there is one
                  if (post.imageUrl != null && !removeImage)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            post.imageUrl!,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 150,
                                color: Colors.grey[800],
                                child: const Icon(Icons.error, color: Colors.white),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              removeImage = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Remove Image'),
                        ),
                      ],
                    ),
                  // Show preview of new image
                  if (imageFile != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(imageFile!, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              imageFile = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Remove New Image'),
                        ),
                      ],
                    ),
                  // Show image picker button if no preview is showing
                  if (imageFile == null && (post.imageUrl == null || removeImage))
                    ElevatedButton(
                      onPressed: () async {
                        final image = await _pickImage();
                        if (image != null) {
                          setState(() {
                            imageFile = image;
                            removeImage = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A2A),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Add Image', style: TextStyle(color: Colors.amber)),
                        ],
                      ),
                    ),
                ],
              ),
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
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Title cannot be empty'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context, true);
                },
                child: const Text(
                  'Update',
                  style: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          );
        },
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        File? uploadImageFile;
        
        // Determine which image to use
        if (removeImage) {
          // Create an empty file as a marker to indicate removal
          uploadImageFile = File('');
        } else if (imageFile != null) {
          uploadImageFile = imageFile;
        }
        
        await _updatePost(
          post,
          titleController.text.trim(),
          descriptionController.text.trim(),
          uploadImageFile,
        );
      }
    });
  }

  // Update post in Firestore
  Future<void> _updatePost(ForumPost post, String title, String description, File? imageFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare update data
      Map<String, dynamic> updateData = {
        'title': title,
        'description': description,
        'isEdited': true, // Mark the post as edited
      };

      // Handle image updates
      if (imageFile != null) {
        if (imageFile.path.isEmpty) {
          // This is our marker to remove the image
          updateData['imageUrl'] = null;
          
          // Delete the existing image from Storage if it exists
          if (post.imageUrl != null) {
            try {
              await _storage.refFromURL(post.imageUrl!).delete();
            } catch (e) {
              // Continue with post update even if image deletion fails
            }
          }
        } else {
          // This is a new image to upload
          final String? newImageUrl = await _uploadImage(imageFile, post.id);
          if (newImageUrl != null) {
            updateData['imageUrl'] = newImageUrl;
            
            // Delete the old image if there was one
            if (post.imageUrl != null) {
              try {
                await _storage.refFromURL(post.imageUrl!).delete();
              } catch (e) {
                // Continue with post update even if image deletion fails
              }
            }
          }
        }
      }

      // Update the post in Firestore
      await _firestore.collection('forum_posts').doc(post.id).update(updateData);

      // Update local post
      setState(() {
        post.title = title;
        post.description = description;
        post.isEdited = true; // Mark as edited locally
        if (imageFile != null) {
          if (imageFile.path.isEmpty) {
            post.imageUrl = null;
          } else if (updateData.containsKey('imageUrl')) {
            post.imageUrl = updateData['imageUrl'];
          }
        }
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper function to toggle post like
  Future<void> _togglePostLike(ForumPost post) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = user.uid;
      final postRef = _firestore.collection('forum_posts').doc(post.id);

      // Check if user already liked the post
      final bool userLiked = post.likedBy.contains(userId);
      
      if (userLiked) {
        // Unlike the post
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        setState(() {
          post.likes--;
          post.likedBy.remove(userId);
        });
      } else {
        // Like the post
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        setState(() {
          post.likes++;
          post.likedBy.add(userId);
        });
      }
    } catch (e) {
      debugPrint('Error toggling post like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'Brotherhood Forum',
        onBackPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const NavigationScreen(),
            ),
          );
        },
        actions: [
          IconButton(
            icon: Icon(
              _currentSortOption == ForumSortOption.newest ? Icons.sort : Icons.thumb_up,
              color: Colors.black,
            ),
            onPressed: _toggleSortOption,
          ),
        ],
      ),
      body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              : _posts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // If loading failed
                        if (_posts.isEmpty) ...[
                            const Text(
                              'Unable to load posts. Please check your internet connection.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadPosts,
                            icon: const Icon(Icons.refresh, color: Colors.black),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
               : ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(
                  color: Colors.amber,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      post.title,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Add profile picture
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 1,
                                ),
                                // Added image only if authorProfilePic exists
                                image: post.authorProfilePic != null
                                  ? DecorationImage(
                                      image: NetworkImage(post.authorProfilePic!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              ),
                              // Add default icon if no profile picture
                              child: post.authorProfilePic == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.amber,
                                    size: 16,
                                  )
                                : null,
                            ),
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatTimestamp(post.createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            // Add the "Edited" indicator if the post has been edited
                            if (post.isEdited) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '(Edited)',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (post.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            post.isExpanded
                                ? post.description
                                : (post.description.length > 100
                                    ? '${post.description.substring(0, 100)}...'
                                    : post.description),
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (post.description.length > 100)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  post.isExpanded = !post.isExpanded;
                                });
                              },
                              child: Text(
                                post.isExpanded ? 'Show less' : '...more',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                                  
                        // Show image preview if available
                        if (post.imageUrl != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(post.imageUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                                  
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            // First row: views, replies, likes
                            Row(
                              children: [
                                // Likes
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _togglePostLike(post),
                                    child: Row(
                                      children: [
                                        Icon(
                                          post.likedBy.contains(_auth.currentUser?.uid) 
                                              ? Icons.favorite 
                                              : Icons.favorite_border,
                                          size: 16, 
                                          color: post.likedBy.contains(_auth.currentUser?.uid)
                                              ? Colors.amber
                                              : Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${post.likes} likes',
                                          style: TextStyle(
                                            color: post.likedBy.contains(_auth.currentUser?.uid)
                                                ? Colors.amber
                                                : Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Views
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.remove_red_eye,
                                          size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post.views} views',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Replies
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.comment,
                                          size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post.replies} replies',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            // Second row: edit and delete buttons if user is the author
                            if (_auth.currentUser?.uid == post.authorId) 
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Add edit button
                                  TextButton.icon(
                                    onPressed: () => _editPost(post),
                                    icon: const Icon(Icons.edit, 
                                      color: Colors.amber, 
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _deletePost(post),
                                    icon: const Icon(Icons.delete, 
                                      color: Colors.red, 
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () async {
                      // Update view count
                      setState(() {
                        post.views++;
                      });
                      await _updateViewCount(post);
                                
                      // Navigate to detail screen
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForumDetailScreen(
                            title: post.title,
                            description: post.description,
                            imageUrl: post.imageUrl,
                            postId: post.id,
                            postOwnerId: post.authorId, // Pass the post owner ID
                            isEdited: post.isEdited, // Pass the edited state
                            authorProfilePic: post.authorProfilePic, // Pass author profile pic
                            authorName: post.authorName, // Pass author name
                            postTime: post.createdAt, // Pass post creation time
                          ),
                        ),
                      ).then((_) => _loadPosts()); // Refresh posts when returning from detail screen
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewForum,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orangeAccent, Colors.amber],
            ),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
} 