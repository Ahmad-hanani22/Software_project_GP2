import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<dynamic> _messages = [];
  String? _myId;
  Timer? _timer;
  bool _isSending = false;
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Map<String, bool> _playingMessages = {}; // Track which audio is playing

  @override
  void initState() {
    super.initState();
    _loadMyIdAndFetch();
    _markMessagesAsRead();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchMessages(scroll: false);
        _markMessagesAsRead();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/chats/read');
      await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'senderId': widget.receiverId}),
      );
    } catch (e) {
      print("Error marking read: $e");
    }
  }

  Future<void> _loadMyIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myId = prefs.getString('userId'));
    _fetchMessages(scroll: true);
  }

  Future<void> _fetchMessages({bool scroll = false}) async {
    final (ok, data) = await ApiService.getConversation(widget.receiverId);
    if (mounted && ok) {
      // Sort messages: newest first (reverse chronological for display)
      final sortedMessages = List.from(data);
      sortedMessages.sort((a, b) {
        final dateA = DateTime.parse(a['createdAt'] ?? '');
        final dateB = DateTime.parse(b['createdAt'] ?? '');
        return dateB.compareTo(dateA); // Newest first
      });

      setState(() {
        _messages = sortedMessages.reversed
            .toList(); // Reverse again for bottom-up display
      });
      if (scroll) _scrollToBottom();
    }
  }

  Future<void> _sendMessage({String? imageUrl, String? audioUrl}) async {
    final text = _msgController.text.trim();
    if (text.isEmpty && imageUrl == null && audioUrl == null) return;

    _msgController.clear();
    setState(() => _isSending = true);

    // Add temporary message
    setState(() {
      _messages.add({
        'senderId': _myId,
        'message': text.isNotEmpty
            ? text
            : (imageUrl != null ? '📷 Image' : '🎤 Voice message'),
        'attachments': imageUrl != null
            ? [imageUrl]
            : (audioUrl != null ? [audioUrl] : null),
        'createdAt': DateTime.now().toIso8601String(),
        'temp': true,
      });
    });
    _scrollToBottom();

    // Prepare attachments
    List<String> attachments = [];
    if (imageUrl != null) attachments.add(imageUrl);
    if (audioUrl != null) attachments.add(audioUrl);

    final (ok, _) = await ApiService.sendMessage(
      receiverId: widget.receiverId,
      message: text,
      attachments: attachments.isNotEmpty ? attachments : null,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (ok) {
        _fetchMessages();
      } else {
        // Remove temporary message on error
        setState(() {
          _messages.removeWhere((m) => m['temp'] == true);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send message")),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Upload image
      final (ok, url) = await ApiService.uploadImage(image);
      if (ok && url != null) {
        await _sendMessage(imageUrl: url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload image")),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final path = await _getRecordingPath();
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _isRecording) {
            setState(() {
              _recordingDuration = Duration(seconds: timer.tick);
            });
          }
        });
      }
    } catch (e) {
      print("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
      });

      if (send && path != null) {
        // Upload audio file
        final file = File(path);
        final (ok, url) = await ApiService.uploadAudio(file);
        if (ok && url != null) {
          await _sendMessage(audioUrl: url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload audio")),
          );
        }
      }

      setState(() {
        _recordingDuration = Duration.zero;
        _recordingPath = null;
      });
    } catch (e) {
      print("Error stopping recording: $e");
    }
  }

  Future<String> _getRecordingPath() async {
    final Directory tempDir = Directory.systemTemp;
    final String fileName =
        'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${tempDir.path}/$fileName';
  }

  Future<void> _playAudio(String audioUrl) async {
    final key = audioUrl;

    if (_playingMessages[key] == true) {
      // Stop playing
      await _audioPlayer.stop();
      setState(() {
        _playingMessages[key] = false;
      });
    } else {
      // Start playing
      setState(() {
        _playingMessages[key] = true;
      });
      await _audioPlayer.play(UrlSource(audioUrl));

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playingMessages[key] = false;
          });
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.receiverName.isNotEmpty
                    ? widget.receiverName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Online', // يمكن إضافة حالة الاتصال لاحقاً
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true, // Start from bottom
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[
                    _messages.length - 1 - index]; // Reverse for display
                final bool isMe =
                    (msg['senderId'].toString() == _myId.toString());
                final bool isNew = msg['isRead'] == false && !isMe;
                final bool isTemp = msg['temp'] == true;
                final List<dynamic>? attachments =
                    msg['attachments'] as List<dynamic>?;

                return _buildMessageBubble(
                    msg, isMe, isNew, isTemp, attachments);
              },
            ),
          ),
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.mic, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recording: ${_formatDuration(_recordingDuration)}',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _stopRecording(send: false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _stopRecording(send: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Image picker button
                IconButton(
                  icon:
                      const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
                  onPressed: _pickAndSendImage,
                  tooltip: 'Send image',
                ),
                // Voice record button
                GestureDetector(
                  onLongPress: _startRecording,
                  onLongPressUp: () {
                    if (_isRecording) {
                      _stopRecording(send: true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: _isRecording ? Colors.white : Colors.grey.shade700,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                CircleAvatar(
                  backgroundColor: const Color(0xFF2E7D32),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isSending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    bool isNew,
    bool isTemp,
    List<dynamic>? attachments,
  ) {
    final messageText = msg['message'] ?? '';
    final createdAt = msg['createdAt'] != null
        ? DateTime.parse(msg['createdAt'])
        : DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isNew && !isMe
              ? const Color(0xFF2E7D32)
                  .withOpacity(0.9) // Highlight new messages
              : isMe
                  ? const Color(0xFF2E7D32)
                  : Colors.grey[300],
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : null,
            bottomLeft: !isMe ? const Radius.circular(4) : null,
          ),
          boxShadow: isNew && !isMe
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachments (Images)
            if (attachments != null && attachments.isNotEmpty)
              ...attachments.map((att) {
                if (att.toString().contains('image') ||
                    att.toString().startsWith('http')) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      att.toString(),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
                  );
                } else if (att.toString().contains('audio') ||
                    att.toString().endsWith('.m4a') ||
                    att.toString().endsWith('.mp3')) {
                  // Audio message
                  final isPlaying = _playingMessages[att.toString()] ?? false;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_circle : Icons.play_circle,
                            color: isMe ? Colors.white : Colors.black87,
                            size: 36,
                          ),
                          onPressed: () => _playAudio(att.toString()),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice message',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '00:00', // Duration would be stored in message metadata if needed
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList(),

            // Message text
            if (messageText.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(
                    attachments != null && attachments.isNotEmpty ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messageText,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (isMe && msg['isRead'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all,
                              size: 14, color: Colors.white70),
                        ],
                        if (isTemp) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
