class Comment {
  final String id;
  final String text;
  final String userId;
  final String username;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.username,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'userId': userId,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
} 