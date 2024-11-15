

import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String userLoginFunctionUrl = 'https:

  Future<bool> userLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(userLoginFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          
          
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Login successful: ${data['message']}');
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        print('Login failed : ${error['error']}');
        return false;
      }
    } catch (e) {
      print('An unexpected error occurred: $e');
      return false;
    }
  }

  Future<bool> userLogout() async {
    
    
    
    return true;
  }

  Future<bool> signUp(String email, String password) async {
    
    
    return true;
  }
}