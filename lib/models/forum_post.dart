import 'comment.dart';

class ForumPost {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;
  final String userId;
  final String username;
  final DateTime createdAt;
  final List<Comment> comments;
  final List<String> likes;

  ForumPost({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.userId,
    required this.username,
    required this.createdAt,
    required this.comments,
    required this.likes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'userId': userId,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'likes': likes,
    };
  }

  factory ForumPost.fromMap(Map<String, dynamic> map) {
    return ForumPost(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      comments: List<Comment>.from(
        (map['comments'] ?? []).map((comment) => Comment.fromMap(comment)),
      ),
      likes: List<String>.from(map['likes'] ?? []),
    );
  }

  ForumPost copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? imageUrls,
    String? userId,
    String? username,
    DateTime? createdAt,
    List<Comment>? comments,
    List<String>? likes,
  }) {
    return ForumPost(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
      likes: likes ?? this.likes,
    );
  }
} 