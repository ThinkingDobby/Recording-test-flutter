import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

class Recorder extends StatefulWidget {
  @override
  State createState() => _RecorderState();
}

class _RecorderState extends State<Recorder> {
  // 녹음 위한 객체 저장
  late FlutterSoundRecorder _recordingSession;

  // 재생 위한 객체 저장
  final recordingPlayer = AssetsAudioPlayer();

  // 상태 저장
  bool _isRecording = false;
  bool _isPlaying = false;

  //  저장소 경로
  late String _storagePath;

  // 녹음 위한 파일 경로 (저장소 경로 + 파일명)
  late String _filePathForRecord;

  // 재생 위해 선택된 파일
  String _selectedFile = '-1';

  // 파일 이름 저장할 리스트
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
          // 녹음 관련
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                // 녹음 중일 때는 비활성화, 녹음 중이 아니면 녹음 시작
                  onPressed: _isRecording ? null : startRecording,
                  child: const Text("녹음 시작")),
              const SizedBox(width: 16),
              ElevatedButton(
                // 녹음 중이 아닐 때는 비활성화, 녹음 중이면 녹음 중지
                  onPressed: _isRecording ? stopRecording : null,
                  child: const Text("녹음 중지")),
            ],
          ),
          const SizedBox(height: 22),
          const SizedBox(height: 32),
          // 파일 리스트
          Expanded(
              flex: 1,
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: _fileList.length,
                itemBuilder: (context, i) => _setListItemBuilder(context, i),
              )),
          // 재생 관련
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 32),
                  child: ElevatedButton(
                      onPressed: () {
                        if (_fileList.isNotEmpty) {
                          // print("test: $_isPlaying, $_selectedFile");
                          if (!_isPlaying) {
                            // 재생 중이 아니면 재생
                            startPlaying();
                          } else {
                            // 재생 중이면 재생 중지
                            stopPlaying();
                          }

                          setState(() {
                            _isPlaying = !_isPlaying;
                          });
                        }
                      },
                      child: Text(_isPlaying ? "재생 중지" : "음성 재생"))),
              Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 32),
                  child: ElevatedButton(
                      onPressed: () async {
                        // 녹음한 파일 모두 삭제
                        await deleteFiles();
                        setState(() {
                          _fileList = loadFiles();
                        });
                      },
                      style:
                          ElevatedButton.styleFrom(primary: Colors.redAccent),
                      child: const Text("전체 삭제")))
            ],
          )
        ],
      ),
    );
  }

  void initializer() async {
    // 내부저장소 경로 로드
    var docsDir = await getApplicationDocumentsDirectory();
    _storagePath = docsDir.path;
    setState(() {
      // 파일 리스트 초기화
      _fileList = loadFiles();
    });
    if (_fileList.isNotEmpty) {
      _selectedFile = _fileList[0];
    }

    // 녹음 위한 FlutterSoundRecorder 객체 설정
    setRecordingSession();
  }

  List<String> loadFiles() {
    List<String> files = <String>[];

    var dir = Directory(_storagePath).listSync();
    for (var file in dir) {
      // 확장자 검사
      if (checkExtWav(file.path)) {
        files.add(getFilenameFromPath(file.path));
      }
    }

    // 다음 파일명 설정
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

  setRecordingSession() async {
    // 객체 설정
    _recordingSession = FlutterSoundRecorder();
    await _recordingSession.openAudioSession(
        focus: AudioFocus.requestFocusAndStopOthers,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker);
    await _recordingSession
        .setSubscriptionDuration(const Duration(milliseconds: 10));
    await initializeDateFormatting();

    // 권한 요청
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> startRecording() async {
    setState(() {
      _isRecording = true;
    });
    // print("filePathForRecording: $_filePathForRecord");
    Directory directory = Directory(dirname(_filePathForRecord));
    if (!directory.existsSync()) {
      directory.createSync();
    }
    _recordingSession.openAudioSession();
    // 녹음 시작
    await _recordingSession.startRecorder(
      toFile: _filePathForRecord,
      codec: Codec.pcm16WAV,
    );
  }

  Future<String?> stopRecording() async {
    setState(() {
      _isRecording = false;
    });
    // 녹음 중지
    _recordingSession.closeAudioSession();

    setState(() {
      bool first = _fileList.isEmpty ? true : false;
      // 파일 리스트 갱신
      _fileList = loadFiles();
      if (first) {
        _selectedFile = _fileList[0];
      }
    });
    return await _recordingSession.stopRecorder();
  }

  Future<void> startPlaying() async {
    // 재생
    recordingPlayer.open(
      Audio.file('$_storagePath/$_selectedFile'),
      autoStart: true,
      showNotification: true,
    );
    // print("filePathForPlaying $_storagePath/$_selectedFile");
    recordingPlayer.playlistAudioFinished.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> stopPlaying() async {
    // 재생 중지
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
