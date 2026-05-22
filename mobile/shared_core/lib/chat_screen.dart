import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';

class ChatScreen extends StatefulWidget {
  final String jobId;
  final String userId;

  const ChatScreen({super.key, required this.jobId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late WebSocketChannel _channel;
  final List<ChatMessage> _messages = [];
  bool _isOtherUserTyping = false;
  DateTime? _lastTypingTime;

  @override
  void initState() {
    super.initState();
    // Using 10.0.2.2 for Android emulator to access localhost
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.16.50:8080/api/v1/communication/ws'),
    );

    _channel.stream.listen((data) {
      final json = jsonDecode(data);
      if (json['content'] == 'TYPING') {
        if (json['sender_id'] != widget.userId) {
          setState(() => _isOtherUserTyping = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isOtherUserTyping = false);
          });
        }
        return;
      }

      final msg = ChatMessage.fromJson(json);
      if (msg.jobId == widget.jobId) {
        setState(() {
          _messages.add(msg);
          _isOtherUserTyping = false;
        });
      }
    });
  }

  void _onTextChanged(String text) {
    if (_lastTypingTime == null || DateTime.now().difference(_lastTypingTime!) > const Duration(seconds: 1)) {
      _lastTypingTime = DateTime.now();
      _channel.sink.add(jsonEncode({
        'type': 'TYPING',
        'job_id': widget.jobId,
        'sender_id': widget.userId,
        'content': 'TYPING',
      }));
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final msg = ChatMessage(
        jobId: widget.jobId,
        senderId: widget.userId,
        content: _messageController.text,
        timestamp: DateTime.now(),
      );
      final json = msg.toJson();
      json['type'] = 'MESSAGE';
      _channel.sink.add(jsonEncode(json));
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                final isMe = msg.senderId == widget.userId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.indigo : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isOtherUserTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Typing...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    decoration: const InputDecoration(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
