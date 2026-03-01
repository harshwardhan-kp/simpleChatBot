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
      title: 'harshGPT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
    List<Map<String, String>> groqMessages = [];
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
          "harshGPT",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      "Say something to start chatting!",
                      style: TextStyle(color: Colors.grey),
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
                                ? Colors.deepPurple
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
                  Text("harshGPT is thinking...", style: TextStyle(color: Colors.grey)),
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
                  backgroundColor: Colors.deepPurple,
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
}
