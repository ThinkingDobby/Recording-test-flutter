import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

class Recorder extends StatefulWidget {
  @override
  State createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> {
  late FlutterSoundRecorder _recordingSession;
  final recordingPlayer = AssetsAudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;

  late String _storagePath;
  late String _filePathForRecord;
  String _selectedFile = '-1';

  List<String> _fileList = <String>[];

  @override
  void initState() {
    super.initState();
    initializer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recording Test")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                  onPressed: _isRecording ? null : startRecording,
                  child: Text("녹음 시작")),
              const SizedBox(width: 16),
              ElevatedButton(
                  onPressed: _isRecording ? stopRecording : null,
                  child: Text("녹음 중지")),
            ],
          ),
          const SizedBox(height: 22),
          const SizedBox(height: 32),
          Flexible(
              flex: 1,
              fit: FlexFit.tight,
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: _fileList.length,
                itemBuilder: (context, i) => _setListItemBuilder(context, i),
              )),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 32),
                  child: ElevatedButton(
                      onPressed: () {
                        if (_fileList.isNotEmpty) {
                          setState(() {
                            _isPlaying = !_isPlaying;
                          });
                          print("test: $_isPlaying, $_selectedFile");
                          if (_isPlaying) {
                            startPlaying();
                          } else {
                            stopPlaying();
                          }
                        }
                      },
                      child: Text(_isPlaying ? "중지" : "음성 재생"))),
              Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 32),
                  child: ElevatedButton(
                      onPressed: () {
                        deleteFiles();
                        setState(() {
                          _fileList = loadFiles();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.redAccent
                      ),
                      child: Text("전체 삭제")))
            ],
          )
        ],
      ),
    );
  }

  void initializer() async {
    _storagePath = '/sdcard/Download';
    setState(() {
      _fileList = loadFiles();
    });
    if (_fileList.isNotEmpty) {
      _selectedFile = _fileList[0];
    }


    _recordingSession = FlutterSoundRecorder();
    await _recordingSession.openAudioSession(
        focus: AudioFocus.requestFocusAndStopOthers,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker);
    await _recordingSession
        .setSubscriptionDuration(const Duration(milliseconds: 10));
    await initializeDateFormatting();
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  List<String> loadFiles() {
    List<String> files = <String>[];

    var dir = Directory(_storagePath).listSync();
    for (var file in dir) {
      if (checkExtWav(file.path)) {
        files.add(getFilenameFromPath(file.path));
      }
    }

    files.sort();
    _filePathForRecord = '$_storagePath/temp${files.length + 1}.wav';

    return files;
  }

  bool checkExtWav(String fileName) {
    if (fileName.substring(fileName.length - 3) == "wav") {
      return true;
    } else {
      return false;
    }
  }

  String getFilenameFromPath(String filePath) {
    int idx = filePath.lastIndexOf('/') + 1;
    return filePath.substring(idx);
  }

  RadioListTile _setListItemBuilder(BuildContext context, int i) {
    return RadioListTile(
        title: Text(_fileList[i]),
        value: _fileList[i],
        groupValue: _selectedFile,
        onChanged: (val) {
          setState(() {
            _selectedFile = _fileList[i];
          });
        });
  }

  Future<void> startRecording() async {
    setState(() {
      _isRecording = true;
    });
    print("filePathForRecording: $_filePathForRecord");
    Directory directory = Directory(dirname(_filePathForRecord));
    if (!directory.existsSync()) {
      directory.createSync();
    }
    _recordingSession.openAudioSession();
    await _recordingSession.startRecorder(
      toFile: _filePathForRecord,
      codec: Codec.pcm16WAV,
    );
  }

  Future<String?> stopRecording() async {
    setState(() {
      _isRecording = false;
    });
    _recordingSession.closeAudioSession();

    setState(() {
      bool first = _fileList.isEmpty ? true : false;
      _fileList = loadFiles();
      if (first) {
        _selectedFile = _fileList[0];
      }
    });
    return await _recordingSession.stopRecorder();
  }

  Future<void> startPlaying() async {
    recordingPlayer.open(
      Audio.file('$_storagePath/$_selectedFile'),
      autoStart: true,
      showNotification: true,
    );
    print("filePathForPlaying $_storagePath/$_selectedFile");
    recordingPlayer.playlistAudioFinished.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> stopPlaying() async {
    recordingPlayer.stop();
  }

  deleteFiles() {
    var dir = Directory(_storagePath).listSync();
    for (var file in dir) {
      if (checkExtWav(file.path)) {
        file.delete();
      }
    }
  }
}
