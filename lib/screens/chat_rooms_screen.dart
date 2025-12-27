import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  try {
    DateTime dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.parse(raw);
    } else {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  } catch (_) {
    return '';
  }
}

Widget _buildProfileAvatar(Map<String, dynamic>? user, {double radius = 24}) {
  if (user != null) {
    final profilePic = user['profile_pic']?.toString();
    if (profilePic != null && profilePic.isNotEmpty) {
      final assetPath = 'assets/avatars/$profilePic.png';
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color.fromARGB(255, 213, 240, 255),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            errorBuilder: (c, e, s) => const Icon(Icons.person, size: 18),
          ),
        ),
      );
    }
  }

  String? img;
  if (user != null) {
    img = user['avatar']?.toString() ??
        user['profile_picture']?.toString() ??
        user['photo']?.toString();
  }

  if (img == null || img.isEmpty) {
    return CircleAvatar(radius: radius, child: const Icon(Icons.person, size: 18));
  }

  String url = img;
  try {
    if (!url.startsWith('http')) {
      final baseRoot = ApiService.baseUrl.replaceAll('/api', '');
      url = baseRoot + (img.startsWith('/') ? img : '/$img');
    }
  } catch (_) {}

  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.grey[200],
    backgroundImage: NetworkImage(url),
  );
}

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  late Future<List<ChatRoom>?> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _fetchRooms();
  }

  Future<List<ChatRoom>?> _fetchRooms() async {
    final response = await ApiService.fetchChatRooms();
    if (!response.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
    return response.data;
  }

  Future<void> _refresh() async {
    setState(() {
      _roomsFuture = _fetchRooms();
    });
    await _roomsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 31, 143, 189),
        foregroundColor: Colors.white,
        title: const Text('Messages'),
        centerTitle: true,
        elevation: 4,
        shadowColor: const Color.fromARGB(255, 31, 143, 189).withAlpha(150),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.fromARGB(255, 67, 163, 208), Color(0xFFE1F5FE)],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80,
            left: -60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withAlpha(46),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 46, 17, 189).withAlpha(64),
                ),
              ),
            ),
          ),

          // Content
          RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<ChatRoom>?>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final rooms = snapshot.data ?? [];

                if (rooms.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white70),
                        SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final otherUser = room.otherUser;
                    final name = otherUser['name']?.toString() ?? 
                                 otherUser['email']?.toString() ?? 
                                 'User';
                    final lastMsg = room.lastMessage ?? 'No messages yet';
                    final time = _formatDate(room.lastMessageAt);
                    final unread = room.unreadCount;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: const Color.fromARGB(255, 213, 240, 255),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: _buildProfileAvatar(otherUser, radius: 28),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0 ? Colors.black87 : Colors.grey[600],
                              fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (time.isNotEmpty)
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unread > 0 ? Colors.blue : Colors.grey,
                                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            if (unread > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : unread.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                roomId: room.id,
                                otherUser: otherUser,
                              ),
                            ),
                          ).then((_) => _refresh());
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
