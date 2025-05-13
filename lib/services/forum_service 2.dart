import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment.dart';

class ForumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a comment to a post
  Future<void> addComment(String postId, Comment comment) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        
        if (!postDoc.exists) {
          throw Exception('Post does not exist!');
        }
        
        final List<dynamic> comments = postDoc.data()?['comments'] ?? [];
        comments.add(comment.toMap());
        
        transaction.update(postRef, {'comments': comments});
      });
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }
} 