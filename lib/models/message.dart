
class ChatMessage {
  final int id;
  final String content;
  final int senderId;
  final int receiverId;
  final String senderName;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      senderName: json['sender']?['name'] ?? 'Пользователь',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class ChatPreview {
  final int userId;
  final String userName;
  final String? userAvatar;
  final DateTime? lastSeen;
  final String lastMessage;
  final DateTime createdAt;
  final String? propertyTitle;
  final int unreadCount;

  ChatPreview({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.lastSeen,
    required this.lastMessage,
    required this.createdAt,
    this.propertyTitle,
    this.unreadCount = 0,
  });

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    return ChatPreview(
      userId: json['user']['id'],
      userName: json['user']['name'],
      userAvatar: json['user']['avatar'],
      lastSeen: json['user']['lastSeen'] != null ? DateTime.parse(json['user']['lastSeen']) : null,
      lastMessage: json['lastMessage'],
      createdAt: DateTime.parse(json['createdAt']),
      propertyTitle: json['property']?['title'],
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
