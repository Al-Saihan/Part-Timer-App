import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/chat_room.dart';

String _formatMessageTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Widget _buildProfileAvatar(Map<String, dynamic>? user, {double radius = 20}) {
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
            errorBuilder: (c, e, s) => const Icon(Icons.person, size: 16),
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
    return CircleAvatar(radius: radius, child: const Icon(Icons.person, size: 16));
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

class ChatScreen extends StatefulWidget {
  final int roomId;
  final Map<String, dynamic> otherUser;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  Timer? _refreshTimer;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadMessages(isInitial: true);
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false, bool isInitial = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final response = await ApiService.fetchChatMessages(roomId: widget.roomId);

    if (!silent) setState(() => _isLoading = false);

    if (response.success && response.data != null) {
      setState(() {
        _messages = response.data!.reversed.toList(); // Most recent at bottom
      });
      
      // Only scroll to bottom on first load
      if (_isFirstLoad) {
        _isFirstLoad = false;
        // Wait for the frame to build, then scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } else if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final response = await ApiService.sendChatMessage(
      roomId: widget.roomId,
      content: text,
    );

    setState(() => _isSending = false);

    if (response.success) {
      // Reload all messages to ensure consistency
      await _loadMessages(silent: true);
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Restore the message text if it failed
      _messageController.text = text;
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 213, 240, 255),
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await ApiService.deleteChatMessage(
      roomId: widget.roomId,
      messageId: message.id,
    );

    if (response.success) {
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.otherUser['name']?.toString() ??
        widget.otherUser['email']?.toString() ??
        'User';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 31, 143, 189),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color.fromARGB(255, 31, 143, 189).withAlpha(150),
        title: Row(
          children: [
            _buildProfileAvatar(widget.otherUser, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadMessages(),
          ),
        ],
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

          // Content
          Column(
            children: [
              // Messages List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'No messages yet\nStart the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.isMe;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: isMe
                                      ? () => _deleteMessage(message)
                                      : null,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color.fromARGB(255, 31, 143, 189)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.content,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black87,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatMessageTime(message.createdAt),
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // Input Area
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color.fromARGB(255, 31, 143, 189),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
