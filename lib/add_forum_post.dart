import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

// ForumPost model class
class ForumPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfilePic;
  final String title;
  final String description;
  final List<String> imageUrls;
  final DateTime timestamp;
  final int views;
  final int likes;
  final int commentCount;

  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorProfilePic,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.timestamp,
    required this.views,
    required this.likes,
    required this.commentCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfilePic': authorProfilePic,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'timestamp': Timestamp.fromDate(timestamp),
      'views': views,
      'likes': likes,
      'commentCount': commentCount,
    };
  }
}

class AddForumPost extends StatefulWidget {
  // Static lock to prevent multiple post submissions even across widget instances
  static bool isSubmittingPost = false;
  
  const AddForumPost({super.key});

  @override
  _AddForumPostState createState() => _AddForumPostState();
}

class _AddForumPostState extends State<AddForumPost> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isCheckingConnection = false;
  bool _isConnected = false;
  bool _isCreatingPost = false;
  bool _isSubmitted = false;
  String? _postError;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _checkFirestoreConnection();
    
    // Check if a post is already being submitted somewhere
    if (AddForumPost.isSubmittingPost) {
      setState(() {
        _isSubmitted = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    
    // If this instance was the one submitting, clear the lock when disposed
    if (_isCreatingPost) {
      AddForumPost.isSubmittingPost = false;
    }
    
    super.dispose();
  }

  Future<void> _checkFirestoreConnection() async {
    setState(() {
      _isCheckingConnection = true;
    });

    try {
      // For production mode, we need to verify the authenticated user first
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user for Firestore connection check in add post screen');
        setState(() {
          _isCheckingConnection = false;
          _isConnected = false;
        });
        return;
      }

      debugPrint('Checking Firestore connection as authenticated user: ${user.uid}');
      
      try {
        // Try a simple Firestore operation that requires authentication
        await _firestore
          .collection('forum_posts')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
          
        debugPrint('Firestore connection check successful in add post screen');
        setState(() {
          _isCheckingConnection = false;
          _isConnected = true;
        });
      } catch (e) {
        if (e is FirebaseException) {
          debugPrint('Firebase exception during connection check in add post screen: ${e.code} - ${e.message}');
          
          // Even if we get permission-denied, the connection is still working
          if (e.code == 'permission-denied') {
            setState(() {
              _isCheckingConnection = false;
              _isConnected = true;
            });
            return;
          }
        }
        setState(() {
          _isCheckingConnection = false;
          _isConnected = false;
        });
      }
    } catch (e) {
      debugPrint('Final connection check error in add post screen: $e');
      setState(() {
        _isCheckingConnection = false;
        _isConnected = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  Future<Uint8List?> compressImage(File imageFile) async {
    try {
      // Simple implementation - just read the bytes
      // In a production app, you would use a compression library 
      return await imageFile.readAsBytes();
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _createPost() async {
    // Check both instance state and global state
    if (_isSubmitted || _isCreatingPost || AddForumPost.isSubmittingPost) {
      return;
    }

    // Set the global lock
    AddForumPost.isSubmittingPost = true;
    
    // Set both flags immediately to prevent multiple clicks
    setState(() {
      _isCreatingPost = true;
      _isSubmitted = true;
      _postError = null;
    });

    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _isCreatingPost = false;
        // Keep _isSubmitted true for empty title case
        _postError = 'Title cannot be empty';
      });
      // Release global lock on validation failure
      AddForumPost.isSubmittingPost = false;
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('User not authenticated when creating post');
        setState(() {
          _isCreatingPost = false;
          // Keep _isSubmitted true for auth failure
          _postError = 'You must be logged in to create a post';
        });
        // Release global lock on auth failure
        AddForumPost.isSubmittingPost = false;
        return;
      }

      await user.reload();
      final refreshedUser = _auth.currentUser!;
      
      debugPrint('Creating post as authenticated user: ${refreshedUser.uid}');

      DocumentReference postRef = _firestore.collection('forum_posts').doc();

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          try {
            String fileName = '${postRef.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            Reference storageRef = _storage.ref().child('forum_images/$fileName');
            
            debugPrint('Uploading image $i of ${_selectedImages.length}');
            
            final Uint8List? compressedImage = await compressImage(_selectedImages[i]);
            if (compressedImage == null) {
              debugPrint('Failed to compress image $i');
              continue;
            }
            
            await storageRef.putData(
              compressedImage,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            
            String downloadUrl = await storageRef.getDownloadURL();
            imageUrls.add(downloadUrl);
            debugPrint('Successfully uploaded image $i: $downloadUrl');
          } catch (e) {
            debugPrint('Error uploading image $i: $e');
          }
        }
      }

      final post = ForumPost(
        id: postRef.id,
        authorId: refreshedUser.uid,
        authorName: refreshedUser.displayName ?? 'Anonymous',
        authorProfilePic: refreshedUser.photoURL,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        timestamp: DateTime.now(),
        views: 0,
        likes: 0,
        commentCount: 0,
      );

      debugPrint('Saving post to Firestore: ${postRef.id}');
      await postRef.set(post.toMap());
      debugPrint('Post created successfully');

      setState(() {
        _isCreatingPost = false;
        // _isSubmitted remains true
      });
      
      // Release the global lock on successful post creation
      // We do this after setState so any UI updates are already processed
      AddForumPost.isSubmittingPost = false;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      
      String errorMessage = 'Failed to create post';
      if (e is FirebaseException) {
        debugPrint('Firebase error when creating post: ${e.code} - ${e.message}');
        
        switch (e.code) {
          case 'permission-denied':
            errorMessage = 'You don\'t have permission to create posts.';
            break;
          case 'unavailable':
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your internet connection.';
            break;
          default:
            errorMessage = 'Error: ${e.message}';
        }
      }
      
      setState(() {
        _isCreatingPost = false;
        _postError = errorMessage;
        // Only reset _isSubmitted for specific network errors where retrying makes sense
        if (e is FirebaseException &&
            (e.code == 'unavailable' || e.code == 'network-request-failed')) {
          _isSubmitted = false;
          // Also release the global lock only for those specific errors
          AddForumPost.isSubmittingPost = false;
        }
        // For all other errors, keep _isSubmitted true to prevent resubmission
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isCreatingPost) {
          final bool? shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Post is being created', style: TextStyle(color: Color(0xFFD4AF37))),
              content: const Text('Are you sure you want to cancel this post?', 
                style: TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay', style: TextStyle(color: Color(0xFFD4AF37))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        
        if (!_isSubmitted && (_titleController.text.isNotEmpty || 
            _descriptionController.text.isNotEmpty || _selectedImages.isNotEmpty)) {
          final bool? shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Discard post?', style: TextStyle(color: Color(0xFFD4AF37))),
              content: const Text('You have unsaved changes. Are you sure you want to discard this post?', 
                style: TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFFD4AF37))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFFD4AF37),
          title: const Text('Create Post', style: TextStyle(color: Colors.black)),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _isCheckingConnection
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : !_isConnected
                ? _buildConnectionError()
                : _buildPostForm(),
      ),
    );
  }

  Widget _buildConnectionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              color: Color(0xFFD4AF37),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connection Error',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to connect to the server. Please check your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkFirestoreConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_postError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                _postError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Title',
              labelStyle: TextStyle(color: Color(0xFFD4AF37)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            ),
            enabled: !_isSubmitted,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              labelStyle: TextStyle(color: Color(0xFFD4AF37)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            ),
            enabled: !_isSubmitted,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isSubmitted ? null : _pickImages,
            icon: const Icon(Icons.photo),
            label: const Text('Add Image'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD4AF37),
              side: const BorderSide(color: Color(0xFFD4AF37)),
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      children: [
                        Image.file(
                          _selectedImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                        if (!_isSubmitted)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              color: Colors.black.withOpacity(0.7),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (context) {
                // Use a local flag to ensure immediate disabling on click
                final GlobalKey buttonKey = GlobalKey();
                bool localSubmitFlag = _isSubmitted || _isCreatingPost;
                
                // Create a wrapper for the createPost function that disables the button immediately
                void onCreatePostPress() {
                  if (localSubmitFlag) return;
                  
                  // Disable the button immediately by updating the local state
                  localSubmitFlag = true;
                  
                  // Force a rebuild of just this button
                  (buttonKey.currentState as StatefulElement?)?.markNeedsBuild();
                  
                  // Then call the actual create post method
                  _createPost();
                }
                
                return ElevatedButton(
                  key: buttonKey,
                  onPressed: localSubmitFlag ? null : onCreatePostPress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isCreatingPost
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating Post...'),
                          ],
                        )
                      : _isSubmitted
                          ? const Text(
                              'Post Created',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            )
                          : const Text(
                              'Create Post',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
} 