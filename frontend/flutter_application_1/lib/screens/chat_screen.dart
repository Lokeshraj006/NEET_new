import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/chat_message.dart';
import 'package:flutter_application_1/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessageModel> _messages = [];
  final ChatService _service = ChatService();
  String? _sessionId;
  bool _detailedMode = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessageModel(
        text:
            "Hi, I am your NEET-based bot. Ask me physics, chemistry, or biology questions, and let's make learning fun.",
        isUser: false,
      ),
    );
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessageModel(text: text, isUser: true));
      _sending = true;
    });
    _controller.clear();

    try {
      final res = await _service.sendMessage(
        text,
        history: _messages,
        sessionId: _sessionId,
        detailed: _detailedMode,
      );
      final reply = res['reply'] as String? ?? 'No reply';
      setState(() {
        _messages.add(ChatMessageModel(text: reply, isUser: false));
        _sessionId = res['session_id'] as String? ?? _sessionId;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _messages.add(
          ChatMessageModel(
            text: msg.isEmpty ? 'Something went wrong. Please try again.' : msg,
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        centerTitle: true,
        actions: [
          Row(
            children: [
              const Text('Detailed', style: TextStyle(fontSize: 12)),
              Switch(
                value: _detailedMode,
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _detailedMode = v),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) =>
                  ChatMessageWidget(message: _messages[i]),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                          ),
                          cursorColor: Colors.black87,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Ask NEET questions...',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.black87,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _detailedMode ? 'Mode: Detailed' : 'Mode: Concise',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
