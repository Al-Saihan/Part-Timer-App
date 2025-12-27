class ChatRoom {
  final int id;
  final Map<String, dynamic> otherUser;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  ChatRoom({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    // Handle other_participant from API
    final otherParticipant = json['other_participant'] ?? json['other_user'] ?? json['otherUser'] ?? {};
    
    // Handle latest_message from API
    final latestMsg = json['latest_message'] ?? json['last_message'] ?? json['lastMessage'];
    String? lastMsgContent;
    DateTime? lastMsgTime;
    
    if (latestMsg != null && latestMsg is Map) {
      lastMsgContent = latestMsg['content']?.toString();
      lastMsgTime = latestMsg['created_at'] != null
          ? DateTime.parse(latestMsg['created_at'].toString())
          : null;
    }

    return ChatRoom(
      id: json['id'] ?? json['room_id'] ?? 0,
      otherUser: otherParticipant is Map ? Map<String, dynamic>.from(otherParticipant) : {},
      lastMessage: lastMsgContent,
      lastMessageAt: lastMsgTime,
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class ChatMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    required this.createdAt,
    this.isMe = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    // Handle different field types - convert to int safely
    final id = json['id'];
    final messageId = id is int ? id : int.tryParse(id?.toString() ?? '0') ?? 0;
    
    final roomIdRaw = json['room_id'] ?? json['roomId'];
    final roomId = roomIdRaw is int ? roomIdRaw : int.tryParse(roomIdRaw?.toString() ?? '0') ?? 0;
    
    final senderIdRaw = json['sender_id'] ?? json['senderId'];
    final senderId = senderIdRaw is int ? senderIdRaw : int.tryParse(senderIdRaw?.toString() ?? '0') ?? 0;
    
    return ChatMessage(
      id: messageId,
      roomId: roomId,
      senderId: senderId,
      content: json['content']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? json['messageType']?.toString() ?? 'text',
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      isMe: currentUserId != null && senderId == currentUserId,
    );
  }
}
