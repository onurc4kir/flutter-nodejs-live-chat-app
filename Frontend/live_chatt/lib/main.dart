import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

String uri = 'http://localhost:3000';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LandingScreen(),
    );
  }
}

class LandingScreen extends StatelessWidget {
  LandingScreen({Key key}) : super(key: key);
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 300,
              child: TextField(
                controller: controller,
              ),
            ),
            RaisedButton(
              onPressed: () {
                if (controller.text.trim().length > 3) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        userName: controller.text,
                      ),
                    ),
                  );
                }
              },
              child: Text('Login'),
            ),
            RaisedButton(
              child: Text('fetch data'),
              onPressed: () {
                try {
                  Dio()
                      .get('http://localhost:3000/', options: Options())
                      .then((value) => print(value));
                } catch (e) {
                  print('hata');
                  print(e);
                }
              },
            )
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String userName;
  const ChatPage({Key key, @required this.userName}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String connectionStatus;
  IO.Socket socket;
  StreamController<String> _socketResponse;
  List<Map<String, String>> messages;
  TextEditingController _searchQuery;
  String someoneTyping;
  Timer _debounce;
  @override
  void initState() {
    super.initState();
    messages = [];

    _socketResponse = StreamController();
    _searchQuery = TextEditingController();
    try {
      socket = IO.io(
          uri,
          IO.OptionBuilder()
              .setTransports(['websocket', 'polling']) // for Flutter or Dart VM
              .setQuery({'userName': "${widget.userName}"}) // optional
              .build());
      socket.onDisconnect((data) {
        print('disconnected');
        print(data);
      });

      socket.onConnecting((data) {
        print('trying to connect');
        print(data);
      });

      socket.onConnect((data) {
        print('connectend');
        setState(() {
          connectionStatus = 'Connected';
        });
      });

      socket.on('receive_message', (data) {
        Map<String, dynamic> message = Map<String, dynamic>.from(data);

        setState(() {
          messages.add(
              {'userName': message['userName'], 'message': message['message']});
        });
      });
      socket.on('whoTyping', (data) {
        final whoWriting = Map<String, dynamic>.from(data);
        setState(() {
          someoneTyping = whoWriting.containsKey('userName')
              ? whoWriting['userName'] + ' is typing...'
              : "";
        });
      });
    } catch (e) {
      print(e);
    }

    connectionStatus = 'not connected yet ... ';
  }

  @override
  void dispose() {
    _searchQuery.removeListener(_onSearchChanged);
    _searchQuery.dispose();
    _debounce?.cancel();
    _socketResponse.close();
    super.dispose();
  }

  _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // do something with _searchQuery.text
      socket.emit('typing', false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<String>(
          stream: _socketResponse.stream,
          builder: (context, snapshot) {
            return Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(connectionStatus),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      onChanged: (s) {
                        _onSearchChanged();
                        socket.emit(
                          'typing',
                          true,
                        );
                      },
                      onEditingComplete: () {
                        print('editing completed');
                        socket.emit(
                          'typing',
                          false,
                        );
                      },
                      controller: _searchQuery,
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      onEditingComplete: () {
                        print('editing completed');
                      },
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: TextButton(
                        onPressed: () {
                          if (_searchQuery.text.trim().length > 0) {
                            socket.emit('message', _searchQuery.text);
                          }
                        },
                        child: Text('send message')),
                  ),
                  Text("${someoneTyping}"),
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: 300,
                      child: ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (c, i) {
                            return Text(messages[i]['userName'] +
                                '  ' +
                                messages[i]['message']);
                          }),
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}
