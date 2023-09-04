import 'dart:convert';
import 'dart:io';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/google_speech.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import 'api_constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:async/async.dart' show ChunkedStreamReader;
import 'package:crypto/crypto.dart' show Digest, md5;
import 'package:convert/convert.dart' show AccumulatorSink;
//import 'package:md5_file_checksum/md5_file_checksum.dart';




void main() {
  dotenv.load();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio To Text',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AudioRecognize(),
    );
  }
}

class AudioRecognize extends StatefulWidget {
  
  const AudioRecognize({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AudioRecognizeState();
}

class _AudioRecognizeState extends State<AudioRecognize> {
  bool recognizing = false;
  bool recognizeFinished = false;
  String text = '';

  void recognize() async {
    setState(() {
      recognizing = true;
    });
    WidgetsFlutterBinding.ensureInitialized();
    final result = await FilePicker.platform.pickFiles(type: FileType.video); 
    if (result == null) return;

    final file2 = result.files.first;
    final variavelSuporte = file2.name;
    String testtt = variavelSuporte.replaceAll('.mp4', '.flac');

  
    var shell = Shell();
    if (!((Directory('./filesUpload').existsSync()))) {
      await shell.run('''
        mkdir filesUpload
      ''');
    }

    var list = (List.from(Directory('./filesUpload').listSync())).toString();
    final splitted = list.split(' ');
    var length1 = splitted.length;
    
    final variavelSuporte3 = file2.path;
    var errorBuffer=0;
    if((File('filesUpload/${file2.name}').existsSync())){
      print('Ficheiro repetido. O ficheiro selecionado já se encontra na pasta filesUpload.');
    } else if(length1!=0){
      String variavelSuporte1 = 'filesUpload/${file2.name}';
      await shell.run('''
        ffmpeg -i ${file2.path} filesUpload/$variavelSuporte
      ''');
      var hash = await getFileMD5(variavelSuporte1.toString());
      
      


      
      for(int i=0; i < length1; i++){
        if(i%2 != 0){
          String list2 = splitted[i];
          String list3 = list2.replaceAll('\\', '/');
          String list4 = list3.replaceAll(',', '');
          String list7 = list4.replaceAll("'", '');
          String list8 = list7.replaceAll(']', '');
          


          
          var hashBuffer = await getFileMD5((list8).toString());
          
          if(hash == hashBuffer){
            final fileVariavelSuporte1 = File(variavelSuporte1); 
            await fileVariavelSuporte1.delete();
            print('Ficheiro repetido. O ficheiro selecionado já se encontra na pasta filesUpload.');
            errorBuffer = 1;
            break;
          }
        }
      }
      
      if(errorBuffer == 0){
        await shell.run('''
        ffmpeg -i ${file2.path} filesUpload/$testtt
      ''');
      File sourceFile = File('filesUpload/$testtt');
      await sourceFile.copy('assets/buffer.flac');

      final serviceAccount = ServiceAccount.fromString(
        (await rootBundle.loadString('assets/test_service_account.json')));
      final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
      final config = _getConfig();
      final audio = await _getAudioContent('buffer.flac');
      await speechToText.recognize(config, audio).then((value) {
      setState(() {
        text = value.results
            .map((e) => e.alternatives.first.transcript)
            .join('\n');
      });
    
      }).whenComplete(() => setState(() {
          recognizeFinished = true;
          recognizing = false;
        }));
      }
      
    
    }
    
    
    
  
  }


  RecognitionConfig _getConfig() => RecognitionConfig(
      encoding: AudioEncoding.FLAC,
      model: RecognitionModel.basic,
      enableAutomaticPunctuation: true,
      sampleRateHertz: 16000,
      languageCode: 'en-US');
      //alternativeLanguageCodes: ['fr-FR', 'de-US']);

  Future<String?> getFileChecksum(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return null;
  try {
    final stream = file.openRead();
    final hash = await md5.bind(stream).first;
    return base64.encode(hash.bytes);
  } catch (exception) {
    return null;
  }
}

  Future<Digest> getFileMD5(String path) async {
  final reader = ChunkedStreamReader(File(path).openRead());
  const chunkSize = 4096;
  var output = AccumulatorSink<Digest>();
  var input = md5.startChunkedConversion(output);

  try {
    while (true) {
      final chunk = await reader.readChunk(chunkSize);
      if (chunk.isEmpty) {
        // indicate end of file
        break;
      }
      input.add(chunk);
    }
  } finally {
    
    reader.cancel();
  }

  input.close();

  return output.events.single;
}


  Future<void> _copyFileFromAssets(String name) async {
    var data = await rootBundle.load('assets/$name');
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$name';
    await File(path).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<List<int>> _getAudioContent(String name) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}\\$name';
    if (!File(path).existsSync()) {
      await _copyFileFromAssets(name);
    }
    return File(path).readAsBytesSync().toList();
  }


  final String apiKey = aiToken;
  Future<String> getOpenAIResponse(String input) async{
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'prompt': input, 'max_tokens': 50}),
    );
    if(response.statusCode == 200){
      final data = jsonDecode(response.body);
      return data['choices'][0]['text'];
    } else {
      throw Exception('Failed to load response');
    }
  }

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio To Text'),
        backgroundColor: const Color.fromRGBO(24, 83, 194, 0.87),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            if (recognizeFinished)
              _RecognizeContent(
                text: text,
              ),
              ElevatedButton(
                onPressed: recognizing ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SecondRoute()),
                  );
                } : recognize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(63, 108, 192, 0.70),
              ),
                child: recognizing
                  ? const CircularProgressIndicator()
                  : const Text('Select a .mp4 file'),
            ),
            const SizedBox(
              height: 10.0,
            )      
          ],
        )
        ),
    );
  }
}

class SecondRoute extends StatelessWidget {
  const SecondRoute({super.key});

  final String apiKey = aiToken;
  Future<String> getOpenAIResponse(String input) async{
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'prompt': input, 'max_tokens': 50}),
    );
    if(response.statusCode == 200){
      final data = jsonDecode(response.body);
      return data['choices'][0]['text'];
    } else {
      throw Exception('Failed to load response');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Route'),
      ),
      body: Center(
        child: FutureBuilder<String>(
          future: getOpenAIResponse('Once upon a time'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return Text(snapshot.data ?? 'No response');
            }
            // ignore: dead_code
            ElevatedButton(
            onPressed: (){
              Navigator.pop(context);
            },
            child: const Text('Go back!'),
          );
          },
        ),
      ),
    );
 }
}


class _RecognizeContent extends StatelessWidget {
  final String? text;  

  const _RecognizeContent({Key? key, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          const Text(
            'The text recognized by the Google Speech Api:',
          ),
          const SizedBox(
            height: 16.0,
          ),
          const CircularProgressIndicator(),
          Text(
            text ?? '---',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

