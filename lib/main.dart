import 'dart:convert';
import 'dart:math';

import 'package:chat/db.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:sembast/sembast.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Chat with ChatGPT'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

String randomString() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

OpenAI openAI = OpenAI.instance.build(
    token: "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",
    baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 5)),
    enableLog: true);

class _MyHomePageState extends State<MyHomePage> {
  var store = StoreRef.main();
  var _conversations = {};
  String _selectedConversationId = randomString();
  List<dynamic> _messages = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initializeAsyncData();
  }

  Future<void> _initializeAsyncData() async {
    await DB.load();
    store = StoreRef.main();
    dynamic conversations = await store.record("conversations").get(DB.db);
    if (conversations != null) {
      setState(() {
        conversations.entries.forEach((e) {
          _conversations[e.key] = e.value;
        });
      });
    }
  }

  void _handleSendPressed(types.PartialText message) async {
    _messages.insert(0, {
      "author": "user",
      "createdAt": DateTime.now().millisecondsSinceEpoch,
      "id": randomString(),
      "text": message.text,
    });
    setState(() {
      _messages = _messages;
    });
    if (_conversations[_selectedConversationId] == null) {
      _conversations[_selectedConversationId] = {"title": message.text};
      await store.record("conversations").put(DB.db, _conversations);
      await store.record(_selectedConversationId).put(DB.db, _messages);
    } else {
      await store.record(_selectedConversationId).put(DB.db, _messages);
    }
    // _addMessage(requestMessage);

    final request = ChatCompleteText(messages: [
      ..._messages.reversed.map((e) => Messages(
          role: e["author"] == "user" ? Role.user : Role.assistant,
          content: e["text"])),
      Messages(role: Role.user, content: message.text)
    ], maxToken: 200, model: GptTurboChatModel());

    ChatCTResponse? reposne = await openAI.onChatCompletion(request: request);

    _messages.insert(0, {
      "author": "bot",
      "createdAt": DateTime.now().millisecondsSinceEpoch,
      "id": randomString(),
      "text": reposne?.choices?.last.message?.content ?? "Sorry, I don't know",
    });
    await store.record(_selectedConversationId).put(DB.db, _messages);
    setState(() {
      _messages = _messages;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
            _conversations?[_selectedConversationId]?["title"] ?? widget.title),
      ),
      body: Chat(
        messages: _messages.map<types.Message>((item) {
          return types.TextMessage(
            author: types.User(id: item["author"]),
            createdAt: item["item.createdAt"],
            id: item["id"],
            text: item["text"],
          );
        }).toList(),
        onSendPressed: _handleSendPressed,
        user: const types.User(
          id: "user",
        ),
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(0),
            bottomRight: Radius.circular(0),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              height: 100,
              child: DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedConversationId = randomString();
                      _messages = [];
                    });
                    Navigator.pop(context);
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.ac_unit),
                      SizedBox(width: 5),
                      Text('New Chat'),
                      SizedBox(width: 20),
                      Icon(Icons.edit_calendar),
                    ],
                  ),
                ),
              ),
            ),
            ..._conversations.entries.map((e) {
              return ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.value["title"]),
                    IconButton(
                        onPressed: () {
                          setState(() {
                            _conversations.remove(e.key);
                            if (_selectedConversationId == e.key) {
                              _selectedConversationId = randomString();
                              _messages = [];
                            }
                            (() async {
                              await store
                                  .record("conversations")
                                  .put(DB.db, _conversations);
                              await store.record(e.key).delete(DB.db);
                            })();
                          });
                          store
                              .record("conversations")
                              .put(DB.db, _conversations);
                        },
                        icon: const Icon(Icons.delete)),
                  ],
                ),
                onTap: () {
                  _selectedConversationId = e.key;
                  (() async {
                    dynamic messages = await store
                            .record(_selectedConversationId)
                            .get(DB.db) ??
                        [];
                    setState(() {
                      _messages = messages.map((item) {
                        return {
                          "author": item["author"],
                          "createdAt": item["createdAt"],
                          "id": item["id"],
                          "text": item["text"],
                        };
                      }).toList();
                    });
                    Navigator.pop(context);
                  })();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
