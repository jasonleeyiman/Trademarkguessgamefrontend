import 'package:flutter/material.dart';
import 'admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:async';
class PlayerPage extends StatefulWidget{
  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}
class _PlayerScreenState extends State<PlayerPage>{
  List<QuestionUnit> levels=[];
  List<String> playerAnswer=List.filled(10,'');
  int? _expandedLevelIndex;
  String _username="Loading...";
  Timer? _timer;
  int _remainingTimeMinutes=0;
  int _remainingTime=0;
  int _passScore=0;
  bool isFinished=false;
  List<dynamic> passedLevel=[];
  @override
  void initState(){
    super.initState();
    _loadQuestionUnits();
    _loadUsername();
    _loadGameRules();
  }
  void startCountdown(String unitName){
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer){
      setState(() {
        if(_remainingTime>0){
          _remainingTime--;
        }else{
          _timer?.cancel();
          _submitAnswer(unitName);
        }
      });
    });
  }
  Future<void> _modifyPlayer(String unitName) async{
    final apiUrl=Uri.parse('http://localhost:3000/modify/player/pass');
    final prefs=await SharedPreferences.getInstance();
    final token=prefs.getString('authToken');
    try{
      final response=await http.put(
        apiUrl,
        headers:{
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode({
          'unitName': unitName
        }),
      );
      if(response.statusCode==200){
        setState(() {
          passedLevel.add(unitName);
        });
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update with error code: ${response.statusCode}')),
        );
      }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error $e. Please try again later.')),
      );
    }
  }
  Future<void> _loadGameRules() async{
    final apiUrl=Uri.parse('http://localhost:3000/fetch/game/rules');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    try{
      final response=await http.get(
        apiUrl,
        headers:{
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if(response.statusCode==201){
        final result = jsonDecode(response.body)['result'][0];
        setState(() {
          _remainingTimeMinutes=result['timePeriod'];
          _remainingTime=_remainingTimeMinutes*60;
          _passScore=result['correctRate'];
        });
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load question units. Please check the console.')
          ),
        );
      }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error $e. Please try again later.')),
      );
    }
  }
  Future<void> _loadQuestionUnits() async{
    final apiUrl=Uri.parse('http://localhost:3000/api/users/fetch/question');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    try{
      final response=await http.get(
        apiUrl,
        headers:{
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if(response.statusCode==201){
        final List<dynamic> unitJsonList = jsonDecode(response.body)['result'];
        setState(() {
          levels = unitJsonList
              .map((unitJson) => QuestionUnit.fromJson(unitJson))
              .toList();
        });
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load question units. Please check the console.')
          ),
        );
      }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error $e. Please try again later.')),
      );
    }
  }
  Future<void> _loadUsername() async{
    final prefs = await SharedPreferences.getInstance();
    final token=prefs.getString('authToken');
    if(token!=null){
      try{
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        setState((){
          _username=decodedToken['firstName'] ?? 'User';
          passedLevel=decodedToken['pass'];
        });
      }catch(e){
        _redirectToLogin();
      }
    }else{
      _redirectToLogin();
    }
  }
  void _redirectToLogin(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      Navigator.pushReplacementNamed(context, '/');
    });
  }
  Future<void> _logout() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    Navigator.pushReplacementNamed(context, '/');
  }
  Future<void> _submitAnswer(String unitName) async{
    final apiUrl=Uri.parse('http://localhost:3000/calculate/result/${unitName}');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    try{
      final response=await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
        body: jsonEncode({
          'answer': playerAnswer
        }),
      );
      if(response.statusCode==200){
        if(jsonDecode(response.body)['score']>_passScore){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Congradulates! You succeed')),
          );
          _modifyPlayer(unitName);
        }else{
          _showRetryDialog(unitName);
        }
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit with error code: ${response.statusCode}')),
        );
      }      
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error $e. Please try again later.')),
      );
    }
  }
  void _showRetryDialog(String unitName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Try Again?'),
        content: Text('You did not pass the test. Would you like to reattempt?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              setState(() {
                // Reset answers if they choose to reattempt
                playerAnswer = List.filled(10, '');
                _remainingTime = _remainingTimeMinutes * 60; // Reset countdown
                startCountdown(unitName); // Restart countdown
              });
            },
            child: Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              setState(() {
                _expandedLevelIndex = null; // Collapse questions
              });
            },
            child: Text('Don\'t Retry'),
          ),
        ],
      );
    },
  );
}
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hi! $_username'),
            ElevatedButton(
              onPressed: _logout,
              child: Text('Logout'),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        itemCount: levels.length,
        itemBuilder: (context, index){
          final level=levels[index];
          isFinished=passedLevel.contains(level.unitName);
          return Card(
            margin: EdgeInsets.all(8.0),
            child: Column(
              children: [
                ListTile(
                  title: Text(isFinished? '${level.unitName} (finished)': level.unitName),
                  onTap: (){
                    setState((){
                      if(_expandedLevelIndex==index){
                        _expandedLevelIndex = null;
                      }else{
                        _expandedLevelIndex = index;
                        startCountdown(level.unitName);
                      }
                    });
                  },
                ),
                if (_expandedLevelIndex == index&&!isFinished)
                  Column(
                    children: [
                      for(int i=0; i<level.questions.length; i++)
                        QuestionWidget(
                          question: level.questions[i],
                          onAnswerChanged: (String answer) {
                            setState(() {
                              playerAnswer[i]=answer;
                            });
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _remainingTime > 0
                          ?ElevatedButton(
                            onPressed: (){
                              _timer?.cancel();
                              _submitAnswer(level.unitName);
                            }, 
                            child: Text("Submit Level"),
                          )
                          :ElevatedButton(
                            onPressed: (){
                              setState(() {
                                _remainingTime=_remainingTimeMinutes*60;
                                startCountdown(level.unitName);
                              });
                            }, 
                            child: Text("Restart"),
                          )
                      ),
                      Text("Time remaining: $_remainingTime seconds"),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
class QuestionWidget extends StatelessWidget {
  final Question question;
  final ValueChanged<String> onAnswerChanged;
  QuestionWidget({required this.question, required this.onAnswerChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              question.imagePath,
              width: 300,
              height: 300,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 300,
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.red),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: "Your Answer",
              border: OutlineInputBorder(),
            ),
            onChanged: onAnswerChanged,
          ),
        ],
      ),
    );
  }
}