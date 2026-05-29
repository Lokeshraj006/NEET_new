import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/widgets/chat_bubble.dart';
import 'package:flutter_application_1/core/widgets/custom_card.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
import 'package:flutter_application_1/widgets/chat_message.dart';
import 'package:flutter_application_1/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  final ChatService _service = ChatService();
  String? _sessionId;
  // detailed mode removed

  bool _sending = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessageModel(
        text:
            "Hi, I am your NEET medical AI assistant. Ask physics, chemistry, or biology questions and I’ll keep the explanation clear.",
        isUser: false,
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final requestHistory = List<ChatMessageModel>.from(_messages)
      ..add(ChatMessageModel(text: text, isUser: true));
    final thinkingMessage = ChatMessageModel(text: 'Thinking...', isUser: false);
    setState(() {
      _messages.add(ChatMessageModel(text: text, isUser: true));
      _messages.add(thinkingMessage);
      _sending = true;
    });
    _scrollToBottom();
    _controller.clear();

    try {
      final res = await _service.sendMessage(
        text,
        history: requestHistory,
        sessionId: _sessionId,

      );
      final reply = res['reply'] as String? ?? 'No reply';
      setState(() {
        final thinkingIndex = _messages.indexOf(thinkingMessage);
        if (thinkingIndex >= 0) {
          _messages[thinkingIndex] = ChatMessageModel(text: reply, isUser: false);
        } else {
          _messages.add(ChatMessageModel(text: reply, isUser: false));
        }
        _sessionId = res['session_id'] as String? ?? _sessionId;
      });
      _scrollToBottom();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        final errorIndex = _messages.indexOf(thinkingMessage);
        final errorMessage = ChatMessageModel(
          text: msg.isEmpty ? 'Something went wrong. Please try again.' : msg,
          isUser: false,
        );
        if (errorIndex >= 0) {
          _messages[errorIndex] = errorMessage;
        } else {
          _messages.add(errorMessage);
        }
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final message = _messages[i];
                return ChatBubble(text: message.text, isUser: message.isUser);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: CustomCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Ask NEET questions...',
                              prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _sending ? null : _send,
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 2,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}
