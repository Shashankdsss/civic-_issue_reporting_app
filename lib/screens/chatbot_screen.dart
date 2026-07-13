import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// IMPORTANT: Replace this with your actual Gemini API Key from Google AI Studio
const String geminiApiKey = 'AIzaSyBiZwsaK3te5T2qNpCxPX94OFItUnXYTXM';

class ChatMessage {
  final String text;
  final bool isUser;
  
  ChatMessage({required this.text, required this.isUser});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  late final GenerativeModel _model;
  late final ChatSession _chat;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initChatbot();
  }

  void _initChatbot() {
    // Add initial greeting
    _messages.add(
      ChatMessage(
        text: "Hello! I am your CivicConnect Assistant. I can help you categorize your issues, provide safety tips, or answer questions about civic reporting. How can I help you today?",
        isUser: false,
      ),
    );

    // Initialize the Gemini Model
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey,
      systemInstruction: Content.system(
        "You are a helpful, professional, and empathetic Civic Assistant for an app called 'CivicConnect'. "
        "Your job is to help citizens report civic issues (like Potholes, Water Leakage, Garbage, Drainage, Street Lights) "
        "and guide them in an emergency (SOS for accidents). "
        "Keep your answers concise, well-formatted, and easy to read. "
        "If a user describes a problem, tell them which category they should use to report it."
      ),
    );
    
    // Start chat session
    _chat = _model.startChat();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (geminiApiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY') {
      _showErrorDialog();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final responseText = response.text;
      
      if (responseText != null) {
        setState(() {
          _messages.add(ChatMessage(text: responseText, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I am having trouble connecting right now. Please try again later. ($e)",
          isUser: false,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
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

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("API Key Required", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "To use the AI Chatbot, you must paste your Gemini API key into the code.\n\n"
          "Open lib/screens/chatbot_screen.dart and replace 'REPLACE_WITH_YOUR_GEMINI_API_KEY' with your actual key.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            Text("Civic Assistant", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text("Assistant is thinking...", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isUser
            ? Text(
                message.text,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              )
            : MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.poppins(color: const Color(0xFF1E293B), fontSize: 14),
                  strong: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Ask me anything...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
