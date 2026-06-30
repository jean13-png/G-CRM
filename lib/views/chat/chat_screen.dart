import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';

class ChatScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const ChatScreen({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      db.markMessagesAsRead(widget.agentId);
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final messages = db.getChatMessages(widget.agentId);
    final String currentUserId = db.currentUserRole == 'enterprise'
        ? (db.currentEnterprise?.id ?? '')
        : (db.currentAgent?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agentName),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 64, color: AppTheme.textLight.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucun message pour le moment.",
                            style: TextStyle(color: AppTheme.textLight, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUserId;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? AppTheme.primaryColor : Colors.grey.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isMe ? Colors.white70 : AppTheme.secondaryColor,
                                    ),
                                  ),
                                if (!isMe) const SizedBox(height: 4),
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppTheme.textDark,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: isMe ? Colors.white60 : Colors.black38,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Écrire un message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                    onPressed: () async {
                      final text = _messageController.text.trim();
                      if (text.isEmpty) return;
                      _messageController.clear();
                      await db.sendChatMessage(
                        agentId: widget.agentId,
                        content: text,
                      );
                    },
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
