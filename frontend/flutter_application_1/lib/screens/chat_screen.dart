import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
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
  final List<ChatMessageModel> _messages = [];
  final ChatService _service = ChatService();
  final List<String> _suggestions = const [
    'which hormone produce calcium in blood',
    'what is mitochondria',
    'explain animal kingdom detaily',
  ];
  String? _sessionId;
  bool _detailedMode = false;
  bool _sending = false;

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
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  'Detailed',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Switch(
                  value: _detailedMode,
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _detailedMode = value),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                    // horizontal scrollable suggestion chips near composer
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 8),
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final suggestion = _suggestions[idx];
                            return ActionChip(
                              label: Text(suggestion),
                              onPressed: _sending
                                  ? null
                                  : () {
                                      _controller.text = suggestion;
                                      _send();
                                    },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        Text(
                          _detailedMode ? 'Mode: Detailed' : 'Mode: Concise',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_sending)
                          Text(
                            'Generating reply...',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
