

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserModel>(context, listen: false);
      if (user.id == 0) {
        
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _logout() async {
    final user = Provider.of<UserModel>(context, listen: false);
    final userId = user.id; 

    if (userId == 0) {
      
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    
    final logoutSuccess = await _authService.userLogout(context, userId);

    if (logoutSuccess) {
      user.clearUser(); 
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout, 
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/waiting_room');
              },
              child: const Text('Go to Waiting Room'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/challenges');
              },
              child: const Text('View Challenges'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/active_run');
              },
              child: const Text('Start Run'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/league_room');
              },
              child: const Text('Go to League Room'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
              child: const Text('View History'),
            ),
          ],
        ),
      ),
    );
  }
}
