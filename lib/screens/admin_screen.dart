import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class AdminPage extends StatefulWidget{
  @override
  _AdminScreenState createState() => _AdminScreenState(); 
}
class _AdminScreenState extends State<AdminPage>{
  int _selectedIndex=0;
  final PageController _pageController = PageController();
  String _username="Loading...";
  @override
  void initState(){
    super.initState();
    _loadUsername();
  }
  Future<void> _loadUsername() async{
    final prefs = await SharedPreferences.getInstance();
    final token=prefs.getString('authToken');
    if(token!=null){
      try{
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        setState((){
          _username=decodedToken['firstName'] ?? 'User';
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
      body: Column(
        children: [
          NavigationBar( // Add the navigation bar
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.question_answer),
                label: 'Question Bank',
              ),
              NavigationDestination(
                icon: Icon(Icons.rule),
                label: 'Game Rules',
              ),
              NavigationDestination(
                icon: Icon(Icons.people),
                label: 'Players Data',
              ),
            ],
          ),
          Expanded( // Use Expanded to take up remaining space
            child: _getPage(_selectedIndex), // Function to get the correct page
          ),
        ],
      ),
    );
  }
  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return QuestionBankPage();
      case 1:
        return GameRulesPage();
      case 2:
        return PlayersDataPage();
      default:
        return QuestionBankPage(); // Default to QuestionBankPage
    }
  }
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
class Question{
  String imagePath;
  String correctAnswer;
  String questionText;
  Question({
    required this.imagePath,
    required this.correctAnswer,
    this.questionText='Guess the trademark',
  });
  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'correctAnswer': correctAnswer,
    'questionText': questionText,
  };
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      imagePath: json['imagePath'],
      correctAnswer: json['correctAnswer'],
      questionText: json['questionText'] ??
        'Guess the trademark', // Provide a default value if questionText is null
    );
  }
}
class QuestionUnit{
  List<Question> questions;
  String unitName;
  QuestionUnit({
    required this.questions,
    required this.unitName,
  });
  Map<String, dynamic> toJson() => {
    'unitName': unitName,
    'questions': questions.map((question) => question.toJson()).toList(),
  };
  factory QuestionUnit.fromJson(Map<String, dynamic> json) {
    return QuestionUnit(
      unitName: json['unitName'],
      questions: (json['questions'] as List)
        .map((questionJson) => Question.fromJson(questionJson))
        .toList(),
    );
  }
}
class QuestionBankPage extends StatefulWidget {
  @override
  _QuestionBankPageState createState() => _QuestionBankPageState();
}
class _QuestionBankPageState extends State<QuestionBankPage>{
  List<QuestionUnit> _questionUnits = [];
  bool _isCreatingNewUnit=false;
  final _formKey = GlobalKey<FormState>();
  final _unitNameController = TextEditingController();
  List<TextEditingController> _answerControllers =List.generate(10, (index) => TextEditingController());
  List<TextEditingController> _imageControllers = List.generate(10, (index) => TextEditingController());
  @override
  void initState(){
    super.initState();
    _loadQuestionUnits();
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
          _questionUnits = unitJsonList
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {                  
                setState(() {
                  _isCreatingNewUnit = !_isCreatingNewUnit;
                });
              },
              child: Text(_isCreatingNewUnit? 'Hide New Unit Form': 'Create New Question Unit'),
            ),
            SizedBox(height: 8),
            Expanded(
              child: _isCreatingNewUnit
                  ? _buildNewUnitForm()
                  : _buildQuestionUnitsList(),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildQuestionUnitsList() {
    return ListView.builder(
      itemCount: _questionUnits.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            title: Text(_questionUnits[index].unitName),
            subtitle: Text(
                '${_questionUnits[index].questions.length} questions'),
          ),
        );
      },
    );
  }
  Widget _buildNewUnitForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _unitNameController,
              decoration: InputDecoration(labelText: 'Unit Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a unit name';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          for (int i = 0; i < 10; i++) 
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildQuestionForm(i),
              ),
            ),
            
          // Save button at the bottom
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _saveNewUnit();
                }
              },
              child: Text('Save Unit'),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildQuestionForm(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${index + 1}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _imageControllers[index],
          decoration: InputDecoration(labelText: 'Image Link'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the image link';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _answerControllers[index],
          decoration: InputDecoration(labelText: 'Correct Answer'),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the correct answer';
            }
            return null;
          },
        ),
      ],
    );
  }
  Future<void> _saveNewUnit() async{
    if(_formKey.currentState!.validate()){
      List<Question> questions=[];
      for(int i=0; i<10; i++){
        questions.add(Question(
          imagePath: _imageControllers[i].text,
          correctAnswer: _answerControllers[i].text,
        ));
      }
      QuestionUnit newUnit = QuestionUnit(

        questions: questions,
        unitName: _unitNameController.text,
      );
      final unitJson = jsonEncode(newUnit.toJson());
      final apiUrl = Uri.parse('http://192.168.128.59:3000/api/users/release/question');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      try{
        final response = await http.post(
          apiUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': '$token',
          },
          body: unitJson,
        );
        if(response.statusCode==201){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Question unit saved successfully!')),
          );
          setState((){
            _questionUnits.add(newUnit);
            _isCreatingNewUnit=false;
          });
          _unitNameController.clear();
          for (var controller in _answerControllers) {
            controller.clear();
          }
          for(var controller in _imageControllers){
            controller.clear();
          }
          _loadQuestionUnits();
        }else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save question unit. Please check the console.')
            ),
          );
        }
      }catch(e){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error $e. Please try again later.')),
        );
      }
    }
  }
  @override
  void dispose() {
    _unitNameController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
class GameRulesPage extends StatefulWidget {
  @override
  _GameRulesPageState createState() => _GameRulesPageState();
}
class _GameRulesPageState extends State<GameRulesPage>{
  final _formKey = GlobalKey<FormState>();
  final _timePeriodController=TextEditingController();
  final _correctRateController=TextEditingController();
  bool isFirstSet=false;
  String ruleId='';
  @override
  void initState(){
    super.initState();
    _loadGameRules();
  }
  Future<void> _loadGameRules() async{
    final apiUri=Uri.parse('http://192.168.128.59:3000/api/users/fetch/rules');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    try{
      final response=await http.get(
        apiUri,
        headers:{
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if(response.statusCode==201){
        final data = jsonDecode(response.body)['result'];
        if(data.length!=0){
          ruleId=data[0]['_id'];
          isFirstSet=false;
          _timePeriodController.text = data[0]['timePeriod'].toString();
          _correctRateController.text = data[0]['correctRate'].toString();
        }else{
          isFirstSet=true;
          _timePeriodController.text = '';
          _correctRateController.text = '';
        }
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load game rules: ${response.statusCode}')),
        );
      }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error $e. Please try again later.')),
      );
    }
  }
  Future<void> _saveGameRules()async{
    if(_formKey.currentState!.validate()){
      _formKey.currentState!.save();
      final prefs = await SharedPreferences.getInstance();
      final token=prefs.getString('authToken');
      final timePeriodStr=_timePeriodController.text;
      final correctRateStr=_correctRateController.text;
      int? timePeriod = timePeriodStr.isNotEmpty ? int.tryParse(timePeriodStr) : null;
      int? correctRate = correctRateStr.isNotEmpty ?int.tryParse(correctRateStr) : null;
      if(isFirstSet){
        final response=await http.post(
          Uri.parse('http://192.168.128.59:3000/api/users/set/rules'),
          headers:{
            'Content-Type': 'application/json',
            'Authorization': '$token',
          },
          body: jsonEncode({
            'timePeriod': timePeriod,
            'correctRate': correctRate,
          }),
        );
        if(response.statusCode==201){
          Map<String, dynamic> jsonData = jsonDecode(response.body);
          setState(() {
            isFirstSet=false;
            ruleId=jsonData['id'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game rules saved!')),
          );
        }else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save game rules.')),
          );
        }
      }else{
        final response=await http.put(
          Uri.parse('http://192.168.128.59:3000/api/users/modify/rules/${ruleId}'),
          headers:{
            'Content-Type': 'application/json',
            'Authorization': '$token',
          },
          body: jsonEncode({
            'timePeriod': timePeriod,
            'correctRate': correctRate,
          }),
        );
        if(response.statusCode==201){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game rules saved!')),
          );
        }else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save game rules.')),
          );
        }
      }
    }
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Game Rules Configuration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _timePeriodController,
                decoration: InputDecoration(labelText: 'Time Period (minutes)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _correctRateController,
                decoration: InputDecoration(labelText: 'Correct Rate (0 - 100)%'),
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final rate = int.tryParse(value);
                    if (rate == null || rate < 0 || rate > 100) {
                      return 'Correct rate must be between 0 and 100';
                    }
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _saveGameRules,
                child: Text('Save Rules'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  void dispose(){
    _timePeriodController.dispose();
    _correctRateController.dispose();
    super.dispose();
  }
}
class PlayersDataPage extends StatefulWidget {
  @override
  _PlayersDataPageState createState()=>_PlayersDataPageState();
}
class _PlayersDataPageState extends State<PlayersDataPage>{
  List<dynamic> players = [];
  @override
  void initState(){
    super.initState();
    fetchPlayers();
  }
  Future<void> fetchPlayers() async{
    final apiUri=Uri.parse('http://192.168.128.59:3000/api/users/player/information');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    try{
      final response=await http.get(
        apiUri,
        headers:{
          'Content-Type': 'application/json',
          'Authorization': '$token',
        },
      );
      if(response.statusCode==201){
        setState(() {
          players=jsonDecode(response.body)['result'];
        });
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load player imformation: ${response.statusCode}.')),
        );
      }
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error $e. Please try again later.')),
      );
    }
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Players Data')),
      body: players.isEmpty
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('First Name')),
              DataColumn(label: Text('Last Name')),
              DataColumn(label: Text('Pass')),
            ],
            rows: players.map((player) => DataRow(cells: [
              DataCell(Text(player['email'] ?? '')), // Handle null values
              DataCell(Text(player['firstName'] ?? '')),
              DataCell(Text(player['lastName'] ?? '')),
              DataCell(Text(player['pass'].length.toString() ?? '0')), // Ensure pass is a string
            ])).toList(),
          ),
        ),
    );
  }
}