import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatBotPage extends StatefulWidget {
  ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  List messages = [
    {"message": "Hello", "type": "user"},
    {"message": "How can I help you", "type": "assistant"},
  ];
  //String apiKey = dotenv.env['OPENAI_API_KEY']!;
  TextEditingController queryController = TextEditingController();
  ScrollController scrollController = ScrollController();

  Future<http.Response> fetchChatResponse(
      Uri uri, Map<String, String> headers, Map<String, dynamic> prompt,
      {int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      var response =
          await http.post(uri, headers: headers, body: json.encode(prompt));
      if (response.statusCode == 429) {
        attempt++;
        await Future.delayed(
            Duration(seconds: 2 * attempt)); // Exponential backoff
      } else {
        return response;
      }
    }
    throw Exception('Failed to fetch response after $retries retries');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "Chat Bot",
          style: TextStyle(color: Theme.of(context).indicatorColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  bool isUser = messages[index]['type'] == 'user';
                  return Column(
                    children: [
                      ListTile(
                        trailing: isUser ? Icon(Icons.person) : null,
                        leading: !isUser ? Icon(Icons.support_agent) : null,
                        title: Row(
                          children: [
                            SizedBox(
                              width: isUser ? 100 : 0,
                            ),
                            Expanded(
                              child: Container(
                                child: Text(
                                  messages[index]['message'],
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                color: isUser
                                    ? Color.fromARGB(100, 0, 200, 0)
                                    : Colors.white,
                                padding: EdgeInsets.all(10),
                              ),
                            ),
                            SizedBox(
                              width: isUser ? 0 : 100,
                            )
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: queryController,
                    decoration: InputDecoration(
                      suffixIcon: Icon(Icons.visibility),
                      border: OutlineInputBorder(
                          borderSide: BorderSide(
                              width: 1, color: Theme.of(context).primaryColor),
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    String query = queryController.text;
                    var openAiLLMUri =
                        Uri.https("api.openai.com", "/v1/chat/completions");
                    Map<String, String> headers = {
                      "Content-Type": "application/json",
                      "Authorization":
                          "Bearer  sk-proj-1JT8DreCfqCbuhPWIx7vT3BlbkFJn1CIjNT1FbIIkTfIMn8t"
                    };

                    var prompt = {
                      "model": "gpt-3.5-turbo",
                      "messages": [
                        {"role": "user", "content": query}
                      ],
                      "temperature": 0
                    };

                    try {
                      var resp = await fetchChatResponse(
                          openAiLLMUri, headers, prompt);

                      if (resp.statusCode == 200) {
                        var responseBody = resp.body;
                        var llmResponse = json.decode(responseBody);
                        if (llmResponse['choices'] != null &&
                            llmResponse['choices'].isNotEmpty &&
                            llmResponse['choices'][0]['message'] != null &&
                            llmResponse['choices'][0]['message']['content'] !=
                                null) {
                          String responseContent =
                              llmResponse['choices'][0]['message']['content'];
                          setState(() {
                            messages.add({"message": query, "type": "user"});
                            messages.add({
                              "message": responseContent,
                              "type": "assistant"
                            });
                            WidgetsBinding.instance!.addPostFrameCallback((_) {
                              scrollController.animateTo(
                                scrollController.position.maxScrollExtent,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            });
                          });
                        } else {
                          print("Invalid response structure from API");
                        }
                      } else {
                        print("Request failed with status: ${resp.statusCode}");
                      }
                    } catch (err) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Error"),
                            content: Text(
                                "Failed to fetch response after multiple attempts. Please try again later."),
                            actions: [
                              TextButton(
                                child: Text("OK"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                      print("Error during HTTP request: $err");
                    }
                  },
                  icon: Icon(
                    Icons.send,
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
