import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'profile_page.dart';

enum CommentSortOption {
  newest,
  oldest,
  mostLiked
}

class Comment {
  final String id;
  String text;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final String? authorProfileImage;
  bool isExpanded;
  List<Reply> replies;
  bool isEdited;
  int likes;
  List<String> likedBy;

  Comment({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.authorProfileImage,
    this.isExpanded = false,
    this.replies = const [],
    this.isEdited = false,
    this.likes = 0,
    List<String>? likedBy,
  }) : likedBy = likedBy ?? [];

  factory Comment.fromFirestore(DocumentSnapshot doc, List<Reply> replies) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      text: data['text'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      authorProfileImage: data['authorProfileImage'],
      replies: replies,
      isEdited: data['isEdited'] ?? false,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'authorProfileImage': authorProfileImage,
      'isEdited': isEdited,
      'likes': likes,
      'likedBy': likedBy,
    };
  }
}

class Reply {
  final String id;
  String text;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final String? authorProfileImage;
  final String commentId;
  bool isEdited;
  int likes;
  List<String> likedBy;
  final String? parentReplyId;  // Add missing property
  final String? replyToUsername; // Add missing property
  List<Reply> replies; // Add missing property

  Reply({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.commentId,
    this.authorProfileImage,
    this.isEdited = false,
    this.likes = 0,
    List<String>? likedBy,
    this.parentReplyId,  // Add to constructor
    this.replyToUsername, // Add to constructor
    List<Reply>? replies, // Add to constructor
  }) : likedBy = likedBy ?? [],
       replies = replies ?? []; // Initialize replies list

  factory Reply.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Reply(
      id: doc.id,
      text: data['text'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      commentId: data['commentId'] ?? '',
      authorProfileImage: data['authorProfileImage'],
      isEdited: data['isEdited'] ?? false,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      parentReplyId: data['parentReplyId'], // Add to factory
      replyToUsername: data['replyToUsername'], // Add to factory
      replies: [], // Initialize with empty list
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'commentId': commentId,
      'authorProfileImage': authorProfileImage,
      'isEdited': isEdited,
      'likes': likes,
      'likedBy': likedBy,
      'parentReplyId': parentReplyId, // Add to toFirestore
      'replyToUsername': replyToUsername, // Add to toFirestore
    };
  }
}

class ForumPost {
  final String id;
  String title;
  String content;
  final String authorId;
  final String author;
  final String? authorProfilePic;
  final DateTime timestamp;
  final List<String> tags;
  bool isEdited;
  int likes;
  List<String> likedBy;
  List<Comment> comments;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.author,
    this.authorProfilePic,
    required this.timestamp,
    required this.tags,
    this.isEdited = false,
    this.likes = 0,
    List<String>? likedBy,
    List<Comment>? comments,
  }) : likedBy = likedBy ?? [],
       comments = comments ?? [];

  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ForumPost(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      author: data['author'] ?? 'Anonymous',
      authorProfilePic: data['authorProfilePic'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(data['tags'] ?? []),
      isEdited: data['isEdited'] ?? false,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'author': author,
      'authorProfilePic': authorProfilePic,
      'timestamp': Timestamp.fromDate(timestamp),
      'tags': tags,
      'isEdited': isEdited,
      'likes': likes,
      'likedBy': likedBy,
    };
  }
}

class ForumDetailScreen extends StatefulWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String? postId;  // Add post ID for Firestore reference
  final String? postOwnerId; // Add post owner ID for permission checks
  final bool isEdited; // Add to track if post has been edited
  final String? authorProfilePic;
  final String? authorName;
  final DateTime? postTime;

  const ForumDetailScreen({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.postId,
    this.postOwnerId,
    this.isEdited = false, // Default to false
    this.authorProfilePic,
    this.authorName,
    this.postTime,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final List<Comment> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  int _postLikes = 0;
  bool _userLikedPost = false;
  ForumPost? _post; // Add missing _post field
  CommentSortOption _currentSortOption = CommentSortOption.newest; // Add sort option state
  
  // Firebase references
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) {
      _loadComments();
      _loadPostLikes();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load comments from Firestore
  Future<void> _loadComments() async {
    if (widget.postId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Loading comments for post: ${widget.postId}');
      
      // Ensure the comments collection exists
      final commentsRef = _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments');

      // Create the query with proper sorting
      Query commentsQuery;
      
      // Apply sort based on the current option
      switch (_currentSortOption) {
        case CommentSortOption.newest:
          commentsQuery = commentsRef.orderBy('createdAt', descending: true);
          break;
        case CommentSortOption.oldest:
          commentsQuery = commentsRef.orderBy('createdAt', descending: false);
          break;
        case CommentSortOption.mostLiked:
          commentsQuery = commentsRef.orderBy('likes', descending: true);
          break;
      }
      
      // Get comments with applied sort
      final commentsSnapshot = await commentsQuery.get();
      
      debugPrint('Found ${commentsSnapshot.docs.length} comments');

      List<Comment> loadedComments = [];

      // For each comment, get its replies
      for (var commentDoc in commentsSnapshot.docs) {
        final repliesRef = commentsRef.doc(commentDoc.id).collection('replies');
        
        final repliesSnapshot = await repliesRef.orderBy('createdAt').get();
        
        debugPrint('Comment ${commentDoc.id} has ${repliesSnapshot.docs.length} replies');

        // Build a map of replies for easy access
        Map<String, Reply> repliesMap = {};
        List<Reply> topLevelReplies = [];

        // First pass: create all reply objects
        for (var replyDoc in repliesSnapshot.docs) {
          Reply reply = Reply.fromFirestore(replyDoc);
          repliesMap[reply.id] = reply;
          debugPrint('Created reply: ${reply.id}, parentReplyId: ${reply.parentReplyId}');
        }

        // Second pass: organize replies into a hierarchy
        for (var replyId in repliesMap.keys) {
          Reply reply = repliesMap[replyId]!;
          
          // If this reply is a reply to another reply
          if (reply.parentReplyId != null && repliesMap.containsKey(reply.parentReplyId)) {
            debugPrint('Adding reply ${reply.id} as child of ${reply.parentReplyId}');
            repliesMap[reply.parentReplyId]!.replies.add(reply);
          } else {
            // This is a top-level reply (directly to the comment)
            debugPrint('Adding reply ${reply.id} as top-level reply');
            topLevelReplies.add(reply);
          }
        }
        
        // Verify the hierarchy was built correctly
        int totalNestedReplies = 0;
        for (var reply in topLevelReplies) {
          totalNestedReplies += reply.replies.length;
          // Log the structure
          debugPrint('Top reply ${reply.id} has ${reply.replies.length} nested replies');
        }
        
        debugPrint('Comment ${commentDoc.id}: ${topLevelReplies.length} top-level replies, $totalNestedReplies nested replies');

        loadedComments.add(Comment.fromFirestore(commentDoc, topLevelReplies));
      }

      setState(() {
        _comments.clear();
        _comments.addAll(loadedComments);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
      String errorMessage = 'Failed to load comments';
      if (e is FirebaseException) {
        switch (e.code) {
          case 'permission-denied':
            errorMessage = 'You don\'t have permission to view these comments.';
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
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadComments,
            ),
          ),
        );
      }
    }
  }

  // Load post likes and check if user has liked
  Future<void> _loadPostLikes() async {
    if (widget.postId == null) return;
    
    try {
      // Get the post document
      final postDoc = await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .get();
      
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        
        // Get current user ID
        final currentUser = _auth.currentUser;
        final userId = currentUser?.uid;
        
        // Get likes count and likedBy list
        final likesCount = data['likes'] ?? 0;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        
        // Initialize the _post object
        _post = ForumPost(
          id: postDoc.id,
          title: data['title'] ?? '',
          content: data['content'] ?? '',
          authorId: data['authorId'] ?? '',
          author: data['author'] ?? 'Anonymous',
          authorProfilePic: data['authorProfilePic'],
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          tags: List<String>.from(data['tags'] ?? []),
          isEdited: data['isEdited'] ?? false,
          likes: likesCount,
          likedBy: likedBy,
        );
        
        setState(() {
          _postLikes = likesCount;
          _userLikedPost = userId != null && likedBy.contains(userId);
        });
      }
    } catch (e) {
      debugPrint('Error loading post likes: $e');
    }
  }
  
  // Toggle like on the post
  Future<void> _togglePostLike() async {
    final User? user = FirebaseAuth.instance.currentUser;
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
      final postRef = FirebaseFirestore.instance
          .collection('forum_posts')
          .doc(widget.postId);

      // Check if user already liked the post
      final bool wasLiked = _post!.likedBy.contains(userId);
      
      if (wasLiked) {
        // Unlike the post
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        setState(() {
          _post!.likes--;
          _post!.likedBy.remove(userId);
          // Also update UI state variables
          _postLikes = _post!.likes;
          _userLikedPost = false;
        });
      } else {
        // Like the post
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        setState(() {
          _post!.likes++;
          _post!.likedBy.add(userId);
          // Also update UI state variables
          _postLikes = _post!.likes;
          _userLikedPost = true;
        });
      }
      
      debugPrint('Post like toggled. New like count: $_postLikes, User liked: $_userLikedPost');
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

  // Add a comment method
  Future<void> _addComment() async {
    if (widget.postId == null) return;
    if (_commentController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        // Handle anonymous comment case
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to comment'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Reload user to get latest data including photoURL
      await currentUser.reload();
      final refreshedUser = _auth.currentUser!;
      
      debugPrint('Adding comment with profile pic: ${refreshedUser.photoURL}');
      
      // Reference to the comments collection
      final commentsRef = _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments');
      
      // Add the new comment
      final commentRef = await commentsRef.add({
        'text': _commentController.text,
        'authorId': refreshedUser.uid,
        'authorName': refreshedUser.displayName ?? 'Anonymous',
        'authorProfileImage': refreshedUser.photoURL,
        'createdAt': Timestamp.now(),
        'isEdited': false,
        'likes': 0,
        'likedBy': [],
      });

      // Update reply count in the post with error handling
      try {
        await _firestore.collection('forum_posts').doc(widget.postId).update({
          'replies': FieldValue.increment(1)
        });
      } catch (e) {
        // Continue even if we can't update the reply count
      }
      
      // Get the text now because we'll clear the input field
      final commentText = _commentController.text;
      
      // Clear input field
      _commentController.clear();

      // Add comment to local list for immediate UI update
      setState(() {
        _comments.insert(
          0,
          Comment(
            id: commentRef.id,
            text: commentText,
            authorId: refreshedUser.uid,
            authorName: refreshedUser.displayName ?? 'Anonymous',
            createdAt: DateTime.now(),
            authorProfileImage: refreshedUser.photoURL,
          ),
        );
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added successfully!'),
          backgroundColor: Color(0xFFD4AF37),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      String errorMessage = 'Failed to add comment';
      if (e is FirebaseException) {
        if (e.code == 'unavailable' || e.code == 'network-request-failed') {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Firestore rules need to be updated to allow comments.';
        } else {
          errorMessage = 'Error: ${e.message}';
        }
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Add reply to comment
  Future<void> _addReply(Comment comment, String replyText, {Reply? parentReply}) async {
    if (widget.postId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to reply'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Reload user to get latest data including photoURL
      await currentUser.reload();
      final refreshedUser = _auth.currentUser!;
      
      debugPrint('Adding reply with profile pic: ${refreshedUser.photoURL}');
      
      // Add reply to Firestore
      final repliesRef = _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies');
      
      // Determine if this is a reply to a comment or a reply to another reply
      final replyToId = parentReply?.id;
      final replyToUsername = parentReply?.authorName;
      
      debugPrint('Creating reply with parentReplyId: $replyToId, replyToUsername: $replyToUsername');
      
      // Add the reply
      final replyDoc = await repliesRef.add({
        'text': replyText,
        'authorId': refreshedUser.uid,
        'authorName': refreshedUser.displayName ?? 'Anonymous',
        'authorProfileImage': refreshedUser.photoURL,
        'createdAt': Timestamp.now(),
        'commentId': comment.id,
        'parentReplyId': replyToId,
        'replyToUsername': replyToUsername,
        'isEdited': false,
        'likes': 0,
        'likedBy': [],
      });
      
      // Create the new reply object
      final newReply = Reply(
        id: replyDoc.id,
        text: replyText,
        authorId: refreshedUser.uid,
        authorName: refreshedUser.displayName ?? 'Anonymous',
        createdAt: DateTime.now(),
        commentId: comment.id,
        authorProfileImage: refreshedUser.photoURL,
        isEdited: false,
        likes: 0,
        parentReplyId: replyToId,
        replyToUsername: replyToUsername,
        replies: [], // Initialize with empty replies list
      );

      debugPrint('Created reply: ${newReply.id}, parentReplyId: ${newReply.parentReplyId}');
      
      // Update the UI based on whether this is a reply to a comment or a reply to another reply
      setState(() {
        if (parentReply != null) {
          // Add to a nested reply
          debugPrint('Adding to parent reply: ${parentReply.id}');
          parentReply.replies.add(newReply);
        } else {
          // Add to comment's top-level replies
          debugPrint('Adding to comment: ${comment.id}');
          comment.replies.add(newReply);
        }
        _isLoading = false;
      });
      
      // Refresh the UI to ensure all relationships are properly displayed
      if (mounted) {
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply added successfully!'),
          backgroundColor: Color(0xFFD4AF37),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      debugPrint('Error adding reply: $e');
      setState(() {
        _isLoading = false;
      });
      
      String errorMessage = 'Failed to add reply';
      if (e is FirebaseException) {
        if (e.code == 'unavailable' || e.code == 'network-request-failed') {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Firestore rules need to be updated to allow replies.';
        } else {
          errorMessage = 'Error: ${e.message}';
        }
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Delete comment from Firestore - cleaned up
  Future<void> _deleteComment(Comment comment) async {
    if (widget.postId == null) return;

    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to delete comments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if current user is either the comment author or the post owner
    final bool isCommentAuthor = user.uid == comment.authorId;
    final bool isPostOwner = widget.postOwnerId != null && user.uid == widget.postOwnerId;

    if (!isCommentAuthor && !isPostOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own comments or comments on your post'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    String dialogContent = isPostOwner && !isCommentAuthor
        ? 'Are you sure you want to delete this comment from your post?'
        : 'Are you sure you want to delete your comment?';

    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Comment',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: Text(
          dialogContent,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
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

    try {
      // Delete all replies first
      final repliesSnapshot = await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies')
          .get();

      for (var replyDoc in repliesSnapshot.docs) {
        await _firestore
            .collection('forum_posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(comment.id)
            .collection('replies')
            .doc(replyDoc.id)
            .delete();
      }

      // Then delete the comment itself
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .delete();

      // Update reply count in the post
      await _firestore.collection('forum_posts').doc(widget.postId).update({
        'replies': FieldValue.increment(-1)
      });

      // Remove from local list
      setState(() {
        _comments.remove(comment);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment deleted successfully'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete nested reply from Firestore - new method
  Future<void> _deleteNestedReply(Comment comment, Reply parentReply, Reply nestedReply) async {
    if (widget.postId == null) return;

    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to delete replies'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check permission:
    // 1. The reply author can delete their own reply
    // 2. The parent reply author can delete replies to their reply
    // 3. The comment author can delete any reply under their comment
    // 4. The post owner can delete any reply
    final bool isReplyAuthor = user.uid == nestedReply.authorId;
    final bool isParentReplyAuthor = user.uid == parentReply.authorId;
    final bool isCommentAuthor = user.uid == comment.authorId;
    final bool isPostOwner = widget.postOwnerId != null && user.uid == widget.postOwnerId;

    if (!isReplyAuthor && !isParentReplyAuthor && !isCommentAuthor && !isPostOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to delete this reply'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Customize dialog message based on permissions
    String dialogContent = 'Are you sure you want to delete this reply?';
    if (isPostOwner && !isReplyAuthor) {
      dialogContent = 'Are you sure you want to delete this reply from your post?';
    } else if (isCommentAuthor && !isReplyAuthor) {
      dialogContent = 'Are you sure you want to delete this reply to your comment?';
    } else if (isParentReplyAuthor && !isReplyAuthor) {
      dialogContent = 'Are you sure you want to delete this reply to your message?';
    }

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Reply',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: Text(
          dialogContent,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
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

    try {
      // Delete the reply from Firestore
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies')
          .doc(nestedReply.id)
          .delete();

      // Remove from local list
      setState(() {
        parentReply.replies.remove(nestedReply);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply deleted successfully'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show reply dialog for a comment or nested reply
  Future<void> _showReplyDialog(Comment comment, {Reply? parentReply}) async {
    _editController.clear();
    
    debugPrint('Showing reply dialog for comment: ${comment.id}, parent reply: ${parentReply?.id}');
    if (parentReply != null) {
      debugPrint('Reply will be to: @${parentReply.authorName}');
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Reply to ',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 18,
                ),
              ),
              TextSpan(
                text: '@${parentReply?.authorName ?? comment.authorName}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        content: TextField(
          controller: _editController,
          maxLines: 3,
          autofocus: true,  // Auto focus the text field
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Write your reply...',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Post Reply',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (result && _editController.text.isNotEmpty) {
      debugPrint('Adding reply to comment: ${comment.id}, parent reply: ${parentReply?.id}');
      await _addReply(
        comment,
        _editController.text,
        parentReply: parentReply,
      );
      
      // After adding reply, refresh comments to ensure everything is up to date
      _loadComments();
    }
  }

  // Edit nested reply method - new method
  Future<void> _editNestedReply(Comment comment, Reply parentReply, Reply nestedReply) async {
    // Only the author can edit their own reply
    final User? user = _auth.currentUser;
    if (user == null || user.uid != nestedReply.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit your own replies'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the edit controller text to the current reply text
    _editController.text = nestedReply.text;

    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Edit Reply',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: TextField(
          controller: _editController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Edit your reply...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_editController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reply cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              await _updateNestedReply(comment, parentReply, nestedReply, _editController.text);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  // Update nested reply - new method
  Future<void> _updateNestedReply(Comment comment, Reply parentReply, Reply nestedReply, String newText) async {
    if (widget.postId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the reply in Firestore
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies')
          .doc(nestedReply.id)
          .update({
        'text': newText,
        'isEdited': true, // Mark as edited
      });

      // Update local reply
      setState(() {
        nestedReply.text = newText;
        nestedReply.isEdited = true; // Mark as edited locally
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply updated successfully'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  // Add a method to change sort option
  void _changeSortOption(CommentSortOption option) {
    if (_currentSortOption != option) {
      setState(() {
        _currentSortOption = option;
      });
      _loadComments(); // Reload comments with new sort order
    }
  }

  void _navigateToUserProfile(String userId, String username) {
    // Don't navigate if it's an anonymous user
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user has no profile to view'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId, viewOnly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if the current user is the post owner
    final currentUser = _auth.currentUser;
    final bool isPostOwner = currentUser != null && widget.postOwnerId == currentUser.uid;
    
    return GestureDetector(
      // Add tap handler to dismiss keyboard
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'Discussion',
        onBackPressed: () => Navigator.pop(context),
        actions: isPostOwner ? [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () => _editPost(),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.black),
            onPressed: () => _deletePost(),
          ),
        ] : null,
      ),
        // Keep resizeToAvoidBottomInset true
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
        children: [
              // Make the main content scrollable
              Expanded(
                child: SingleChildScrollView(
                  // Add controller to enable programmatic scrolling
                  controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      // Post content
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author info and timestamp
                Row(
                  children: [
                                // Author info section with profile picture
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.5,
                        ),
                        image: (widget.authorProfilePic != null && widget.authorProfilePic!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(widget.authorProfilePic!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      ),
                      child: (widget.authorProfilePic == null || widget.authorProfilePic!.isEmpty)
                        ? const Icon(
                            Icons.person,
                            color: Color(0xFFD4AF37),
                            size: 24,
                          )
                        : null,
                    ),
                    // Author name and post time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author name
                          GestureDetector(
                            onTap: () {
                              if (widget.postOwnerId != null && widget.postOwnerId!.isNotEmpty) {
                                _navigateToUserProfile(widget.postOwnerId!, widget.authorName ?? 'Anonymous');
                              }
                            },
                            child: Text(
                              widget.authorName ?? 'Anonymous',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Post time
                          Text(
                            widget.postTime != null ? _formatTimestamp(widget.postTime!) : 'Unknown time',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edited indicator
                    if (widget.isEdited)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                        ),
                        child: const Text(
                          'Edited',
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Post title
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Post description
                Text(
                  widget.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                // Post image if available
                if (widget.imageUrl != null) ...[
                  const SizedBox(height: 16),
                              ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.imageUrl!,
                        fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[900],
                                      child: const Center(
                                        child: Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                      ),
                                    );
                                  },
                    ),
                  ),
                ],
                // Like section
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Like button
                    GestureDetector(
                      onTap: _togglePostLike,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _userLikedPost 
                              ? const Color(0xFFD4AF37).withOpacity(0.3) 
                              : Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _userLikedPost 
                                ? const Color(0xFFD4AF37) 
                                : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _userLikedPost ? Icons.favorite : Icons.favorite_border,
                              color: _userLikedPost 
                                  ? const Color(0xFFD4AF37) 
                                  : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _postLikes.toString(),
                              style: TextStyle(
                                color: _userLikedPost 
                                    ? const Color(0xFFD4AF37) 
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
                      // Comments section
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                            top: BorderSide(
                              color: const Color(0xFFD4AF37).withOpacity(0.3),
                            ),
              ),
            ),
                        child: Column(
                          children: [
                            // Sort options
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Sort by:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                _buildSortButton('Newest', CommentSortOption.newest),
                const SizedBox(width: 8),
                _buildSortButton('Oldest', CommentSortOption.oldest),
                const SizedBox(width: 8),
                _buildSortButton('Most Liked', CommentSortOption.mostLiked),
              ],
            ),
          ),
                            // Comments list
                            _isLoading
                      ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFFD4AF37),
                                    ),
                  ),
                )
              : _comments.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: Center(
                    child: Text(
                      'No comments yet.\nBe the first to share your thoughts!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                                        ),
                            ),
                          ),
                        )
                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                final comment = _comments[index];
                      final currentUser = _auth.currentUser;
                      final bool canDeleteComment = currentUser != null && 
                                        (currentUser.uid == comment.authorId || 
                                         widget.postOwnerId == currentUser.uid);
                      
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Comment
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Author profile picture
                                  Container(
                                    width: 30,
                                    height: 30,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFD4AF37),
                                        width: 1,
                                      ),
                                      image: comment.authorProfileImage != null
                                        ? DecorationImage(
                                            image: NetworkImage(comment.authorProfileImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    ),
                                    child: comment.authorProfileImage == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Color(0xFFD4AF37),
                                          size: 16,
                                        )
                                      : null,
                                  ),
                                  GestureDetector(
                                    onTap: () => _navigateToUserProfile(comment.authorId, comment.authorName),
                                    child: Text(
                                      comment.authorName,
                                      style: const TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimestamp(comment.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  // Add edited indicator for comments
                                  if (comment.isEdited) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '(Edited)',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  // Delete/Edit buttons - show if user is the comment owner
                                  if (canDeleteComment) ...[
                                    const Spacer(),
                                    // Add edit button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Color(0xFFD4AF37),
                                        size: 16,
                                      ),
                                      onPressed: () => _editComment(comment),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                      onPressed: () => _deleteComment(comment),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                comment.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _toggleCommentLike(comment),
                                        child: Row(
                                          children: [
                                            Icon(
                                              comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                                                  ? const Color(0xFFD4AF37)
                                                  : Colors.grey,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${comment.likes}',
                                              style: TextStyle(
                                                color: comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                                                    ? const Color(0xFFD4AF37)
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Existing reply button
                                      GestureDetector(
                                        onTap: () {
                                          _showReplyDialog(comment);
                                        },
                                        child: const Text(
                                          'Reply',
                                          style: TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Replies
                        if (comment.replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show first reply
                                      if (comment.replies.isNotEmpty)
                                        _buildReplyWidget(comment, comment.replies[0]),
                                if (comment.replies.length > 1) ...[
                                  if (!comment.isExpanded)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          comment.isExpanded = true;
                                        });
                                      },
                                      child: Text(
                                        'View ${comment.replies.length - 1} more replies',
                                        style: const TextStyle(color: Color(0xFFD4AF37)),
                                      ),
                                    )
                                  else
                                    ...comment.replies
                                        .skip(1)
                                                .map((reply) => _buildReplyWidget(comment, reply)),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
              // Comment input section
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Color(0xFFD4AF37), width: 1),
              ),
            ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                              counterStyle: const TextStyle(
                                color: Color(0xFFD4AF37),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onTap: () {
                              // Scroll to bottom when keyboard appears
                              Future.delayed(const Duration(milliseconds: 300), () {
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              });
                            },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFD4AF37)),
                          onPressed: () {
                            _addComment();
                            // Dismiss keyboard after sending
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ],
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

  // Helper method to build sort option buttons
  Widget _buildSortButton(String label, CommentSortOption option) {
    final bool isSelected = _currentSortOption == option;
    
    return InkWell(
      onTap: () => _changeSortOption(option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFFD4AF37),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyWidget(Comment parentComment, Reply reply) {
    final currentUser = _auth.currentUser;
    final bool isReplyAuthor = currentUser != null && currentUser.uid == reply.authorId;
    final bool canDelete = currentUser != null && 
                          (currentUser.uid == reply.authorId || 
                           currentUser.uid == parentComment.authorId || 
                           widget.postOwnerId == currentUser.uid);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(77),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Author profile picture
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1,
                        ),
                        image: reply.authorProfileImage != null
                          ? DecorationImage(
                              image: NetworkImage(reply.authorProfileImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      ),
                      child: reply.authorProfileImage == null
                        ? const Icon(
                            Icons.person,
                            color: Color(0xFFD4AF37),
                            size: 12,
                          )
                        : null,
                    ),
                    GestureDetector(
                      onTap: () => _navigateToUserProfile(reply.authorId, reply.authorName),
                      child: Text(
                        reply.authorName,
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(reply.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                    // Add edited indicator for replies
                    if (reply.isEdited) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(Edited)',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 8,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    // Edit and Delete buttons
                    if (canDelete) ...[
                      const Spacer(),
                      // Only show edit button to the author of the reply
                      if (isReplyAuthor)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.edit,
                            color: Color(0xFFD4AF37),
                            size: 14,
                          ),
                          onPressed: () => _editReply(parentComment, reply),
                        ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 14,
                        ),
                        onPressed: () => _deleteReply(parentComment, reply),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Add the "replying to @username" part if this is a reply to another reply
                if (reply.replyToUsername != null) ...[
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Replying to ',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        TextSpan(
                          text: '@${reply.replyToUsername}',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  reply.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Like button
                    InkWell(
                      onTap: () => _toggleReplyLike(parentComment, reply),
                      child: Row(
                        children: [
                          Icon(
                            reply.likedBy.contains(_auth.currentUser?.uid)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: reply.likedBy.contains(_auth.currentUser?.uid)
                                ? const Color(0xFFD4AF37)
                                : Colors.grey,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            reply.likes.toString(),
                            style: TextStyle(
                              color: reply.likedBy.contains(_auth.currentUser?.uid)
                                  ? const Color(0xFFD4AF37)
                                  : Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reply button
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showReplyDialog(parentComment, parentReply: reply),
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Nested replies - with indentation
        if (reply.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: reply.replies.map((nestedReply) {
                return _buildNestedReplyWidget(parentComment, reply, nestedReply);
              }).toList(),
            ),
          ),
      ],
    );
  }

  // New method for building nested replies
  Widget _buildNestedReplyWidget(Comment parentComment, Reply parentReply, Reply nestedReply) {
    final currentUser = _auth.currentUser;
    final bool isReplyAuthor = currentUser != null && currentUser.uid == nestedReply.authorId;
    final bool isParentReplyAuthor = currentUser != null && currentUser.uid == parentReply.authorId;
    final bool isCommentAuthor = currentUser != null && currentUser.uid == parentComment.authorId;
    final bool isPostOwner = currentUser != null && widget.postOwnerId == currentUser.uid;
    
    final bool canDelete = isReplyAuthor || isParentReplyAuthor || isCommentAuthor || isPostOwner;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 0.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(90),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: const Color(0xFFD4AF37).withAlpha(100),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Author profile picture
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 1,
                    ),
                    image: nestedReply.authorProfileImage != null
                      ? DecorationImage(
                          image: NetworkImage(nestedReply.authorProfileImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  ),
                  child: nestedReply.authorProfileImage == null
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFFD4AF37),
                        size: 10,
                      )
                    : null,
                ),
                GestureDetector(
                  onTap: () => _navigateToUserProfile(nestedReply.authorId, nestedReply.authorName),
                  child: Text(
                    nestedReply.authorName,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(nestedReply.createdAt),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 9,
                  ),
                ),
                // Add edited indicator for nested replies
                if (nestedReply.isEdited) ...[
                  const SizedBox(width: 4),
                  const Text(
                    '(Edited)',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 7,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                // Edit and Delete buttons
                if (canDelete) ...[
                  const Spacer(),
                  // Only show edit button to the author of the reply
                  if (isReplyAuthor)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.edit,
                        color: Color(0xFFD4AF37),
                        size: 12,
                      ),
                      onPressed: () => _editNestedReply(parentComment, parentReply, nestedReply),
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 12,
                    ),
                    onPressed: () => _deleteNestedReply(parentComment, parentReply, nestedReply),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            // Add the "replying to @username" part
            if (nestedReply.replyToUsername != null) ...[
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Replying to ',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextSpan(
                      text: '@${nestedReply.replyToUsername}',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              nestedReply.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like button
                InkWell(
                  onTap: () => _toggleReplyLike(parentComment, nestedReply),
                  child: Row(
                    children: [
                      Icon(
                        nestedReply.likedBy.contains(_auth.currentUser?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: nestedReply.likedBy.contains(_auth.currentUser?.uid)
                            ? const Color(0xFFD4AF37)
                            : Colors.grey,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        nestedReply.likes.toString(),
                        style: TextStyle(
                          color: nestedReply.likedBy.contains(_auth.currentUser?.uid)
                              ? const Color(0xFFD4AF37)
                              : Colors.grey,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reply button removed - no further level of nesting allowed
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Method to navigate back to main forum page for edit/delete operations
  void _navigateBackToForumList() {
    Navigator.pop(context);
  }

  // Edit post method
  void _editPost() async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Edit Post',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: const Text(
          'You\'ll be returned to the main forum page to edit this post.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Proceed',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && context.mounted) {
      _navigateBackToForumList();
    }
  }

  // Delete post method - cleaned up
  void _deletePost() async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Post',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
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

    if (confirmDelete && context.mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Delete all comments and their replies first
        if (widget.postId != null) {
          // Get all comments
          final commentsSnapshot = await _firestore
              .collection('forum_posts')
              .doc(widget.postId)
              .collection('comments')
              .get();

          // Delete each comment and its replies
          for (var commentDoc in commentsSnapshot.docs) {
            // Get replies for this comment
            final repliesSnapshot = await _firestore
                .collection('forum_posts')
                .doc(widget.postId)
                .collection('comments')
                .doc(commentDoc.id)
                .collection('replies')
                .get();

            // Delete all replies
            for (var replyDoc in repliesSnapshot.docs) {
              await _firestore
                  .collection('forum_posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .doc(commentDoc.id)
                  .collection('replies')
                  .doc(replyDoc.id)
                  .delete();
            }

            // Delete the comment
            await _firestore
                .collection('forum_posts')
                .doc(widget.postId)
                .collection('comments')
                .doc(commentDoc.id)
                .delete();
          }

          // Delete the post image if it exists
          if (widget.imageUrl != null) {
            try {
              // Extract storage reference from URL
              await FirebaseStorage.instance.refFromURL(widget.imageUrl!).delete();
            } catch (e) {
              // Continue with post deletion even if image deletion fails
            }
          }

          // Delete the post
          await _firestore.collection('forum_posts').doc(widget.postId).delete();

          // Navigate back after successful deletion
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post deleted successfully'),
                backgroundColor: Color(0xFFD4AF37),
              ),
            );
            _navigateBackToForumList();
          }
        }
      } catch (e) {
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete post: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Add this method to edit a comment
  Future<void> _editComment(Comment comment) async {
    // Only the author can edit their own comment
    final User? user = _auth.currentUser;
    if (user == null || user.uid != comment.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit your own comments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the edit controller text to the current comment text
    _editController.text = comment.text;

    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Edit Comment',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: TextField(
          controller: _editController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Edit your comment...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_editController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Comment cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              await _updateComment(comment, _editController.text);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  // Update comment in Firestore
  Future<void> _updateComment(Comment comment, String newText) async {
    if (widget.postId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the comment in Firestore
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .update({
        'text': newText,
        'isEdited': true, // Mark as edited
      });

      // Update local comment
      setState(() {
        comment.text = newText;
        comment.isEdited = true; // Mark as edited locally
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment updated successfully'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Edit a reply (top-level)
  Future<void> _editReply(Comment parentComment, Reply reply) async {
    // Only the author can edit their own reply
    final User? user = _auth.currentUser;
    if (user == null || user.uid != reply.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only edit your own replies'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the edit controller text to the current reply text
    _editController.text = reply.text;

    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Edit Reply',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: TextField(
          controller: _editController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Edit your reply...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD4AF37)),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_editController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reply cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              await _updateReply(parentComment, reply, _editController.text);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  // Update reply in Firestore (top-level)
  Future<void> _updateReply(Comment parentComment, Reply reply, String newText) async {
    if (widget.postId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the reply in Firestore
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(parentComment.id)
          .collection('replies')
          .doc(reply.id)
          .update({
        'text': newText,
        'isEdited': true, // Mark as edited
      });

      // Update local reply
      setState(() {
        reply.text = newText;
        reply.isEdited = true; // Mark as edited locally
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply updated successfully'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete reply from Firestore (top-level)
  Future<void> _deleteReply(Comment comment, Reply reply) async {
    if (widget.postId == null) return;

    final User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to delete replies'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if current user is either the reply author, comment author, or post owner
    final bool isReplyAuthor = user.uid == reply.authorId;
    final bool isCommentAuthor = user.uid == comment.authorId;
    final bool isPostOwner = widget.postOwnerId != null && user.uid == widget.postOwnerId;

    if (!isReplyAuthor && !isCommentAuthor && !isPostOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own replies, replies to your comments, or replies on your post'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Customize dialog message based on permissions
    String dialogContent = 'Are you sure you want to delete this reply?';
    if (isPostOwner && !isReplyAuthor) {
      dialogContent = 'Are you sure you want to delete this reply from your post?';
    } else if (isCommentAuthor && !isReplyAuthor) {
      dialogContent = 'Are you sure you want to delete this reply to your comment?';
    }

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Reply',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
        content: Text(
          dialogContent,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD4AF37)),
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

    try {
      // Delete all nested replies first
      for (var nestedReply in List.from(reply.replies)) {
        try {
          await _firestore
              .collection('forum_posts')
              .doc(widget.postId)
              .collection('comments')
              .doc(comment.id)
              .collection('replies')
              .doc(nestedReply.id)
              .delete();
        } catch (e) {
          // Continue even if individual nested reply deletion fails
        }
      }

      // Delete the reply
      await _firestore
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id)
          .collection('replies')
          .doc(reply.id)
          .delete();

      // Remove from local list
      setState(() {
        comment.replies.remove(reply);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply deleted successfully'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method for handling comment likes
  Future<void> _toggleCommentLike(Comment comment) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like comments')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = user.uid;
      final commentRef = FirebaseFirestore.instance
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(comment.id);

      // Check if user already liked the comment
      if (comment.likedBy.contains(userId)) {
        // Unlike the comment
        await commentRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        setState(() {
          comment.likes--;
          comment.likedBy.remove(userId);
        });
      } else {
        // Like the comment
        await commentRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        setState(() {
          comment.likes++;
          comment.likedBy.add(userId);
        });
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Toggle like on a reply
  Future<void> _toggleReplyLike(Comment parentComment, Reply reply) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like replies')),
      );
      return;
    }

    try {
      final userId = user.uid;
      final replyRef = FirebaseFirestore.instance
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(parentComment.id)
          .collection('replies')
          .doc(reply.id);

      // Check if user already liked the reply
      final bool userLikedReply = reply.likedBy.contains(userId);

      if (userLikedReply) {
        // Unlike the reply
        await replyRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        setState(() {
          reply.likes--;
          reply.likedBy.remove(userId);
        });
      } else {
        // Like the reply
        await replyRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        setState(() {
          reply.likes++;
          reply.likedBy.add(userId);
        });
      }
    } catch (e) {
      debugPrint('Error toggling reply like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 