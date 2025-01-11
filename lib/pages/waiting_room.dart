import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:convert';

final String bearerToken = dotenv.env['BEARER_TOKEN']!;





Future<int?> getWaitingRoomId(int userId) async {
  final url =  'https:
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $bearerToken'
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      
      return data['waiting_room_id']; 
    } else {
      
      print('Error fetching waiting room: ${response.body}');
      return null;
    }
  } catch (e) {
    print('Exception in getWaitingRoomId: $e');
    return null;
  }
}





Future<int?> getLeagueRoomId(int userId) async {
  final url =
      'https:
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $bearerToken',
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      
      return data['league_room_id'];
    } else {
      print('Error fetching league room: ${response.body}');
      return null;
    }
  } catch (e) {
    print('Exception in getLeagueRoomId: $e');
    return null;
  }
}





Future<int?> createWaitingRoom(int userId) async {
  final url =
      'https:
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $bearerToken',
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      
      
      
      
      
      return data['waiting_room_id'];
    } else {
      print('Error creating waiting room: ${response.body}');
      return null;
    }
  } catch (e) {
    print('Exception in createWaitingRoom: $e');
    return null;
  }
}





Future<bool> joinWaitingRoom(int userId, int waitingRoomId) async {
  final url =
      'https:
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $bearerToken',
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'userId': userId,
        'waitingRoomId': waitingRoomId,
      }),
    );

    
    if (response.statusCode == 200 || response.statusCode == 201) {
      
      
      
      return true;
    } else {
      print('Error joining waiting room: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Exception in joinWaitingRoom: $e');
    return false;
  }
}



Future<List<String>> fetchWaitingRoomUsers(int waitingRoomId) async {
  
  
  
  return ['User 1', 'User 2', 'User 3'];
}

class WaitingRoomScreen extends StatefulWidget {
  final int userId;
  const WaitingRoomScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _WaitingRoomScreenState createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  bool _isLoading = true;

  int? _waitingRoomId;
  int? _leagueRoomId;
  List<String> _waitingRoomUsers = [];

  
  final TextEditingController _waitingRoomIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeLogic();
  }

  Future<void> _initializeLogic() async {
    setState(() {
      _isLoading = true;
    });

    
    int? fetchedWaitingRoomId = await getWaitingRoomId(widget.userId);

    if (fetchedWaitingRoomId != null) {
      
      _waitingRoomId = fetchedWaitingRoomId;

      
      _waitingRoomUsers = await fetchWaitingRoomUsers(fetchedWaitingRoomId);
    } else {
      
      int? fetchedLeagueRoomId = await getLeagueRoomId(widget.userId);
      if (fetchedLeagueRoomId != null) {
        
        _leagueRoomId = fetchedLeagueRoomId;
      } else {
        
        _leagueRoomId = null;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  
  Future<void> _handleCreateWaitingRoom() async {
    setState(() => _isLoading = true);
    int? newWaitingRoomId = await createWaitingRoom(widget.userId);
    if (newWaitingRoomId != null) {
      _waitingRoomId = newWaitingRoomId;
      
      _waitingRoomUsers = await fetchWaitingRoomUsers(_waitingRoomId!);
    }
    setState(() => _isLoading = false);
  }

  
  Future<void> _handleJoinWaitingRoom() async {
    final inputText = _waitingRoomIdController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a waiting_room_id."))
      );
      return;
    }

    
    int? waitingRoomIdToJoin = int.tryParse(inputText);
    if (waitingRoomIdToJoin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid waiting_room_id format."))
      );
      return;
    }

    setState(() => _isLoading = true);
    bool success = await joinWaitingRoom(widget.userId, waitingRoomIdToJoin);
    if (success) {
      
      _waitingRoomId = waitingRoomIdToJoin;
      _waitingRoomUsers = await fetchWaitingRoomUsers(_waitingRoomId!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to join waiting room."))
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(title: const Text("Waiting Room Logic")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    
    if (_waitingRoomId != null) {
      return _buildWaitingRoomView();
    }

    
    if (_leagueRoomId != null) {
      
      return Center(
        child: Text(
          "You already in League room (ID: $_leagueRoomId). Can't join waiting room.",
          textAlign: TextAlign.center,
        ),
      );
    }

    
    return _buildCreateJoinOptions();
  }

  Widget _buildWaitingRoomView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            "Waiting room ID: $_waitingRoomId",
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _waitingRoomUsers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_waitingRoomUsers[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateJoinOptions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _handleCreateWaitingRoom,
            child: const Text("Create Waiting Room"),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _waitingRoomIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Enter Waiting Room ID to join",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _handleJoinWaitingRoom,
            child: const Text("Join Waiting Room"),
          ),
        ],
      ),
    );
  }
}
