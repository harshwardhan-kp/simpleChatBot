import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load the .env file before the app starts
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'travelGPT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // List that holds all chat messages
  // Each message is a Map with two keys: "role" and "text"
  List<Map<String, String>> messages = [];

  // Controller to read what the user typed
  TextEditingController textController = TextEditingController();

  // ScrollController so we can scroll to the bottom after each message
  ScrollController scrollController = ScrollController();

  // True while waiting for a reply from Groq
  bool isLoading = false;

  // Read API key from the .env file
  String apiKey = dotenv.env['GROQ_APIKEY'] ?? '';

  // System prompt — tells the AI its role
  String systemPrompt =
      "You are a friendly vacation planning assistant. "
      "When a user gives you a country or city name, you help them plan their trip by listing "
      "the top attractions, best time to visit, local food to try, and any travel tips. "
      "Keep your responses clear, organized, and enthusiastic about travel. "
      "If the user asks something unrelated to travel or vacation planning, "
      "politely redirect them and remind them you specialize in vacation planning.";

  // This function sends the message to Groq and gets a reply
  Future<void> sendMessage() async {
    String userText = textController.text.trim();

    // Do nothing if the text field is empty
    if (userText.isEmpty) return;

    // Clear the text field
    textController.clear();

    // Add the user's message to the list and rebuild the UI
    setState(() {
      messages.add({"role": "user", "text": userText});
      isLoading = true;
    });

    scrollToBottom();

    // Build the list of messages in the format Groq expects
    // Always start with the system prompt so the AI knows its role
    List<Map<String, String>> groqMessages = [
      {"role": "system", "content": systemPrompt},
    ];
    for (var msg in messages) {
      groqMessages.add({
        "role": msg["role"]!,
        "content": msg["text"]!,
      });
    }

    // Call the Groq API
    try {
      var response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": groqMessages,
        }),
      );

      if (response.statusCode == 200) {
        // Parse the response JSON
        var data = jsonDecode(response.body);
        String reply = data["choices"][0]["message"]["content"];

        // Add the assistant's reply to the list
        setState(() {
          messages.add({"role": "assistant", "text": reply});
          isLoading = false;
        });
      } else {
        // Show an error message if something went wrong
        setState(() {
          messages.add({"role": "assistant", "text": "Error: ${response.statusCode}"});
          isLoading = false;
        });
      }
    } catch (e) {
      // Show an error message if the request failed
      setState(() {
        messages.add({"role": "assistant", "text": "Failed to connect. Check your internet."});
        isLoading = false;
      });
    }

    scrollToBottom();
  }

  // Scrolls the chat list to the very bottom
  void scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "travelGPT",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Clear chat button
          IconButton(
            icon: Icon(Icons.delete_outline),
            tooltip: "Clear chat",
            onPressed: () {
              setState(() {
                messages = [];
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore, size: 64, color: Colors.orange),
                          SizedBox(height: 16),
                          Text(
                            "travelGPT",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Your Personal Vacation Planner ✈️",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Just type a country or city and I'll help you with:",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 12),
                          Column(
                            children: [
                              _featureItem("🏛️", "Top attractions to visit"),
                              _featureItem("📅", "Best time to visit"),
                              _featureItem("🍜", "Local food to try"),
                              _featureItem("💡", "Travel tips & advice"),
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Try: \"Paris\" or \"Japan\" or \"Bali\"",
                            style: TextStyle(
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var msg = messages[index];
                      bool isUser = msg["role"] == "user";

                      return Align(
                        // User messages on the right, assistant on the left
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 6),
                          padding: EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.orange
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg["text"]!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Loading indicator while waiting for a reply
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text("travelGPT is thinking...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

          // Text input area at the bottom
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: sendMessage,
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  mini: true,
                  child: Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build each feature row in the empty state
  Widget _featureItem(String emoji, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}
