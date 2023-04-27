import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'globals.dart';
import 'package:intl/intl.dart';

class Data {
  List<Voto> votiList = [];
  List<Materia> materieList = [];
  List<PresenzaAssenza> presenzeList = [];
  String jsonString = "";
  bool valid = false;
  int requestStatus = 0;
  String requestBody = "";
  String username;
  String password;
  bool fromCred;

  Data()
      : fromCred = false,
        password = "",
        username = "";
  Data.fromCredentials(this.username, this.password) : fromCred = true;
  Data.fromDisc()
      : fromCred = false,
        password = "",
        username = "";

  Future<void> initialize() async {
    if (fromCred) {
      await _APIconnection(username, password);
      jsonString = requestBody;
      if (requestStatus == 200) {
        _convertJSON();
        await _saveCredentials(username, password);
        await _saveDataToDisc();
      } else {
        valid = false;
      }
    } else {
      await _readDataFromDisc();
      _convertJSON();
    }
    globalData = this;
  }

  void _convertJSON() {
    valid = true;
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    jsonMap['voti'].forEach((key, value) {
      votiList.add(Voto(key, value));
    });
    jsonMap['calendario'].forEach((element) {
      String nomeMateria = element['title'];
      DateTime inizio = DateTime.parse(element['start']);
      DateTime fine = DateTime.parse(element['end']);
      int sede = int.parse(element['AltraSede']);
      String aula = element['aula'];
      Materia materia = Materia(sede, fine, inizio, nomeMateria, aula);
      materieList.add(materia);
    });
    materieList.sort((a, b) => a.inizio.compareTo(b.inizio));
    jsonMap['presenze_assenze'].forEach((element) {
      String materia = element['materia'];
      int presenza = element['ore_presenza'];
      int assenza = element['ore_assenza'];
      DateTime data = DateTime.parse(
          element['date'].replaceAll('/', '-').split('-').reversed.join());
      DateTime inizio = DateFormat('HH:mm').parse(element['ora_inizio']);
      DateTime fine = DateFormat('HH:mm').parse(element['ora_fine']);
      PresenzaAssenza pres_ass =
          PresenzaAssenza(materia, presenza, assenza, data, inizio, fine);
      presenzeList.add(pres_ass);
    });
  }

  Future<void> _APIconnection(String username, String password) async {
    final response = await http.post(
      Uri.parse('https://flask-api-scraper.vercel.app'),
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    requestStatus = response.statusCode;
    requestBody = response.body;
  }

  Future<void> _saveDataToDisc() async {
    final path = await getApplicationDocumentsDirectory();
    final file = File('${path.path}/data.json');
    await file.writeAsString(jsonString);
  }

  Future<void> _readDataFromDisc() async {
    final path = await getApplicationDocumentsDirectory();
    final file = File('${path.path}/data.json');
    final String content = await file.readAsString();
    jsonString = content;
  }

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  Future<void> _saveCredentials(String username, String password) async {
    final storage = FlutterSecureStorage(aOptions: _getAndroidOptions());
    await storage.write(key: 'username', value: username);
    await storage.write(key: 'password', value: password);
  }

  Voto? checkGradesDifference(Data oldData) {
    Data newData = this;

    // Create a set of all the grades in oldData
    Set<Voto> oldGrades = Set<Voto>.from(oldData.votiList);
    // Check if each grade in newData is already in oldGrades
    for (Voto newGrade in newData.votiList) {
      if (!oldGrades.contains(newGrade)) {
        // If a new grade is found, return it
        return newGrade;
      }
    }
    // If no new grades are found, return null
    return null;
  }
}

class Voto {
  String nomeMateria;
  int voto;

  Voto(this.nomeMateria, this.voto);
}

class Materia {
  int sede;
  DateTime fine;
  DateTime inizio;
  String nomeMateria;
  String aula;

  Materia(this.sede, this.fine, this.inizio, this.nomeMateria, this.aula);
}

class PresenzaAssenza {
  String materia;
  int ore_presenza;
  int ore_assenza;
  DateTime data;
  DateTime inizio;
  DateTime fine;

  PresenzaAssenza(this.materia, this.ore_presenza, this.ore_assenza, this.data,
      this.inizio, this.fine);
}
