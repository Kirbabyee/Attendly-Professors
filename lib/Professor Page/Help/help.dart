import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:professor/Professor%20Page/professor_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_handler.dart';
import 'FAQs.dart';

class Help extends StatefulWidget {
  const Help({super.key});

  @override
  State<Help> createState() => _HelpState();
}

class _HelpState extends State<Help> {
  final List<Map<String, String>> _chatHistory = [
    {
      'role': 'ai',
      'text': 'Hello! I am **Lyra AI**, your Attendly support assistant. 🤖\n\n'
          'How can I help you today with our network-based attendance system? ✨'
    },
  ];

  Future<void> _showSuccessModal() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Request Submitted',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Your support request has been successfully submitted.\n\n'
              'Our support team will review your concern and get back to you as soon as possible.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004280),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitSupportRequest() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in subject and message.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final supabase = Supabase.instance.client;
      final student = await ProfessorSession.get(); 

      final uid = supabase.auth.currentUser?.id;
      final email = supabase.auth.currentUser?.email;

      final firstName = student?['first_name']?.toString().trim() ?? '';
      final lastName = student?['last_name']?.toString().trim() ?? '';
      final fullName = '$firstName $lastName'.trim();

      await supabase.from('support_requests').insert({
        'user_id': uid,
        'user_name': fullName.isEmpty ? 'Unknown' : fullName,
        'email': email,
        'subject': subject,
        'message': message,
        'status': 'open',
      });

      if (!mounted) return;

      _subjectCtrl.clear();
      _messageCtrl.clear();

      await _showSuccessModal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: ${ErrorHandler.getMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }


  int expandedIndex = -1; 

  final List<FAQs> faqs = [
    FAQs(
        category: 'Class Session',
        question: 'Why I can\'t start my class session?',
        answer: 'Make sure you have internet. And start class button will be enabled 10 minutes before the schedule.'
    ),
    FAQs(
        category: 'Attendance History',
        question: 'Why I can\'t see my attendance history?',
        answer: 'Make sure you have at least a student enrolled to your class'
    ),
    FAQs(
        category: 'Notification',
        question: 'Why am I not receiving class reminders?',
        answer: 'Check that notifications are enabled in both the app settings and your device system settings.'
    ),
    FAQs(
        category: 'Account',
        question: 'How do I reset my password?',
        answer: 'Go to Settings > Security & Privacy > Change Password. You will need to enter your current password and then create a new one. Make sure your new password is strong and unique.'
    ),
  ];

  Widget helpCard({
    required int index,
    required String category,
    required String question,
    required String answer,
  }) {
    final bool isExpanded = expandedIndex == index;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * .9,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * .03, vertical: screenHeight * .005),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA9CBF9)),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(color: Color(0xFF004280), fontSize: screenHeight * .012),
                      ),
                    ),
                    SizedBox(height: screenHeight * .012),
                    Text(
                      question,
                      style: TextStyle(fontSize: screenHeight * .017, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      expandedIndex = isExpanded ? -1 : index;
                    });
                  },
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ],
          ),

          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                padding: EdgeInsets.only(top: screenHeight * .014),
                child: Text(
                  answer,
                  style: TextStyle(fontSize: screenHeight * .015, color: Colors.black87),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  void _openLyraChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LyraChatBot(faqs: faqs, chatHistory: _chatHistory),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openLyraChat,
        backgroundColor: const Color(0xFF004280),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: screenHeight * .12,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * .08),
              decoration: const BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: const Color(0x30FFFFFF),
                    ),
                    child: Icon(
                      CupertinoIcons.question_circle,
                      color: Colors.white,
                      size: screenHeight * .06,
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    height: screenHeight * .06,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Help & Support',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: screenHeight * .018,
                          ),
                        ),
                        SizedBox(height: screenHeight * .01),
                        Text(
                          'Get answers and assistance',
                          style: TextStyle(
                            fontSize: screenHeight * .014,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    ...faqs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final faq = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: helpCard(
                          index: index,
                          category: faq.category,
                          question: faq.question,
                          answer: faq.answer,
                        ),
                      );
                    }).toList(),

                    Container(
                      width: screenWidth * .9,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Support',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenHeight * .019
                            ),
                          ),
                          SizedBox(height: screenHeight * .023,),
                          Container(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Subject',
                                  style: TextStyle(
                                    fontSize: screenHeight * .017,
                                  ),
                                ),
                                const SizedBox(height: 5,),
                                Center(
                                  child: SizedBox(
                                      width: screenWidth * .7,
                                      height: screenHeight * .033,
                                      child: TextField(
                                        controller: _subjectCtrl,
                                        style: TextStyle(fontSize: screenHeight * .012),
                                        textAlignVertical: TextAlignVertical.center,
                                        decoration: InputDecoration(
                                          hintText: 'Brief description of your issue',
                                          hintStyle: TextStyle(fontSize: screenHeight * .012),
                                          contentPadding: const EdgeInsets.all(5),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.grey),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.grey),
                                          ),
                                        ),
                                      )
                                  ),
                                ),
                                SizedBox(height: screenHeight * .023,),
                                Text(
                                  'Message',
                                  style: TextStyle(
                                      fontSize: screenHeight * .017
                                  ),
                                ),
                                const SizedBox(height: 5,),
                                Center(
                                  child: SizedBox(
                                      width: screenWidth * .7,
                                      height: screenHeight * .13,
                                      child: TextField(
                                        controller: _messageCtrl,
                                        textAlignVertical: TextAlignVertical.top,
                                        keyboardType: TextInputType.multiline,
                                        maxLines: null,
                                        expands: true,
                                        style: TextStyle(fontSize: screenHeight * .012),
                                        decoration: InputDecoration(
                                          hintText: 'Describe your issue in detail...',
                                          hintStyle: TextStyle(fontSize: screenHeight * .012),
                                          contentPadding: const EdgeInsets.all(5),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.grey),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.grey),
                                          ),
                                        ),
                                      )
                                  ),
                                ),
                                SizedBox(height: screenHeight * .023,),
                                Center(
                                    child: OutlinedButton(
                                      onPressed: _sending ? null : _submitSupportRequest,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: const Color(0xFF004280),
                                        side: const BorderSide(color: Color(0xFF004280)),
                                      ),
                                      child: Text(
                                        _sending ? 'Submitting...' : 'Submit Request',
                                        style: TextStyle(
                                          fontSize: screenHeight * .013,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * .023,),
                    Text(
                      'Support Hours\n'
                          'Monday - Friday: 8:00 AM - 6:00 PM\n'
                          'Saturday - Sunday: Closed\n'
                          'For urgent issues outside business hours\n'
                          'please email support@university.edu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenHeight * .015,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: screenHeight * .023,),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LyraChatBot extends StatefulWidget {
  final List<FAQs> faqs;
  final List<Map<String, String>> chatHistory;
  const LyraChatBot({super.key, required this.faqs, required this.chatHistory});

  @override
  State<LyraChatBot> createState() => _LyraChatBotState();
}

class _LyraChatBotState extends State<LyraChatBot> {
  final _chatCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
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

  void _handleSend() {
    final query = _chatCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      widget.chatHistory.add({'role': 'user', 'text': query});
      _chatCtrl.clear();
    });
    _scrollToBottom();

    _generateResponse(query);
  }
  bool _isTyping = false;
  Future<void> _generateResponse(String query) async {
    if (_isTyping) return;

    setState(() => _isTyping = true);

    try {
      const apiKey = "AIzaSyBAxryTzCTtCtvX6bXiZqQu5YI26_OLLww";

      final history = widget.chatHistory.map((m) {
        final role = m['role'] == 'ai' ? 'assistant' : 'user';
        return "$role: ${m['text']}";
      }).join("\n");

      final faqContext = widget.faqs.map((f) => "Q: ${f.question}\nA: ${f.answer}").join("\n\n");

      final prompt = '''
        You are Lyra AI, the official assistant for the Attendly Professor app.
        
        Your task is to help users by answering their questions based on the Frequently Asked Questions (FAQs) and core app functionalities provided below.
        
        FAQ KNOWLEDGE BASE:
        $faqContext
        
        CORE APP FUNCTIONALITIES:
        - Create Class: Click the "+" button in the Dashboard, fill in class details (Course, Section, Schedule, Room), and save.
        - Start Class: Find the class in the Dashboard, click the arrow icon to open the class session, and click "Start Session". Note: Only possible 10 mins before or during the schedule.
        - Accept Students: In your classes, you can accept student's join request in the pending section by clicking the "Accept" button.
        - Mark Attendance: In an active session, you can manually mark students as Present or Absent by toggling their status in the student list.
        - End Class: In the active session screen, click the "End Session" button to finalize attendance records and close the session.
        - Notifications: In settings PUSH NOTIFICATIONS must be on in order to receive notifications. And notification's permission must me allowed.
        
        GENERAL APP INFO:
        - Attendly Professor: App for professors to manage classes and track attendance using classroom Wi-Fi.
        - Requirements: Classroom Wi-Fi connection and Internet.
        - Features: View schedules, mark attendance, check records, view notifications.
        
        CONSTRAINTS:
        - Always answer in bullet points for instructions or multiple pieces of information.
        - Keep answers concise and polite.
        - ONLY answer questions about the Attendly Professor app.
        - If a question is NOT about Attendly Professor or cannot be answered using the FAQs/App Info, respond exactly with:
          "I'm sorry, I am only trained to assist with Attendly Professor app concerns. How can I help you with your attendance today?"
        - If a question contains profanity, respond with: 
          "I am programmed to be a helpful and safe assistant. I cannot respond to prompts containing profanity or offensive language."
        
        CONVERSATION HISTORY:
        $history
        
        USER'S QUESTION:
        $query
        
        LYRA AI RESPONSE:
        ''';

      GenerateContentResponse response;
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash', 
          apiKey: apiKey,
        );
        response = await model.generateContent([
          Content.text(prompt),
        ]);
      } catch (e) {
        debugPrint("Primary model gemini-2.5-flash failed, falling back to gemini-flash-latest: $e");
        final model = GenerativeModel(
          model: 'gemini-flash-latest',
          apiKey: apiKey,
        );
        response = await model.generateContent([
          Content.text(prompt),
        ]);
      }

      final aiText = response.text?.trim();

      if (!mounted) return;

      setState(() {
        widget.chatHistory.add({
          'role': 'ai',
          'text': aiText?.isNotEmpty == true
              ? aiText!
              : "Sorry, I couldn't generate a response."
        });

        _isTyping = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint("GEMINI ERROR: $e");

      if (!mounted) return;

      setState(() {
        widget.chatHistory.add({
          'role': 'ai',
          'text': "⚠️ Error connecting to AI. Please try again."
        });

        _isTyping = false;
      });

      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xFF004280),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Lyra AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Attendly Assistant', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                )
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _isTyping ? widget.chatHistory.length + 1 : widget.chatHistory.length,
              itemBuilder: (context, index) {
                if (index == widget.chatHistory.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10, left: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "Lyra is thinking...",
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                final msg = widget.chatHistory[index];
                final isAi = msg['role'] == 'ai';
                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isAi ? Colors.grey[100] : const Color(0xFF004280),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: Radius.circular(isAi ? 0 : 15),
                        bottomRight: Radius.circular(isAi ? 15 : 0),
                      ),
                    ),
                    child: _FormattedText(
                      text: msg['text'] ?? "",
                      textColor: isAi ? Colors.black87 : Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              left: 10,
              right: 10,
              top: 5,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF004280),
                  child: IconButton(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _FormattedText extends StatelessWidget {
  final String text;
  final Color textColor;

  const _FormattedText({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    List<TextSpan> spans = [];
    final lines = text.split('\n');

    for (var line in lines) {
      if (line.startsWith('### ')) {
        spans.add(TextSpan(
          text: '${line.substring(4)}\n',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        ));
      } else if (line.startsWith('* ') || line.startsWith('- ')) {
        spans.add(TextSpan(text: '  • ', style: TextStyle(color: textColor)));
        _parseBold(line.substring(2) + '\n', spans);
      } else {
        _parseBold(line + '\n', spans);
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, height: 1.4, color: textColor),
        children: spans,
      ),
    );
  }

  void _parseBold(String line, List<TextSpan> spans) {
    final parts = line.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: parts[i]));
      }
    }
  }
}
