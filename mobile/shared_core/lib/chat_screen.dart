import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'config.dart';
import 'models.dart';
import 'network_service.dart';

class ChatScreen extends StatefulWidget {
  final String jobId;
  final String userId;

  const ChatScreen({super.key, required this.jobId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  WebSocketChannel? _channel;
  final List<ChatMessage> _messages = [];
  bool _isOtherUserTyping = false;
  DateTime? _lastTypingTime;
  bool _isLoading = true;

  final Dio _dio = NetworkService().dio;

  @override
  void initState() {
    super.initState();
    _fetchHistoryAndConnect();
  }

  Future<void> _fetchHistoryAndConnect() async {
    final token = await AuthService().getToken();
    try {
      final response = await _dio.get('/communication/chat/history/${widget.jobId}');
      if (response.statusCode == 200) {
        final List historyData = response.data;
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(historyData.map((json) => ChatMessage.fromJson(json)));
          });
        }
      }
    } catch (e) {
      print('Failed to load chat history: $e');
    }

    // Connect WebSocket — uses the dedicated ws/wss base URL from AppConfig
    final wsUrl = '${AppConfig.wsBaseUrl}/communication/chat/ws?jobId=${widget.jobId}&token=${token ?? ""}';

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      if (mounted) {
        setState(() {
          _channel = channel;
        });
      }

      channel.stream.listen((data) {
        if (!mounted) return;
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
      }, onError: (err) {
        print('WS Stream error: $err');
      }, onDone: () {
        print('WS Stream done');
      });
    } catch (e) {
      print('Failed to connect to WS: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onTextChanged(String text) {
    if (_channel != null && (_lastTypingTime == null || DateTime.now().difference(_lastTypingTime!) > const Duration(seconds: 1))) {
      _lastTypingTime = DateTime.now();
      _channel!.sink.add(jsonEncode({
        'type': 'TYPING',
        'job_id': widget.jobId,
        'sender_id': widget.userId,
        'content': 'TYPING',
      }));
    }
  }

  void _sendMessage() {
    if (_channel != null && _messageController.text.isNotEmpty) {
      final msg = ChatMessage(
        jobId: widget.jobId,
        senderId: widget.userId,
        content: _messageController.text,
        timestamp: DateTime.now(),
      );
      final json = msg.toJson();
      json['type'] = 'MESSAGE';
      _channel!.sink.add(jsonEncode(json));
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Chat')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      if (msg.senderId == 'SYSTEM') {
                        return Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg.content == 'JOB_CANCELLED' ? '--- JOB CANCELLED ---' : msg.content,
                              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
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
