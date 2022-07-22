import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
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

  late String filePath;

  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();


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
              ElevatedButton(onPressed: _isRecording ? null : startRecording, child: Text("녹음 시작")),
              const SizedBox(width:16),
              ElevatedButton(onPressed: _isRecording ? stopRecording : null, child: Text("녹음 중지")),
            ],
          ),
          const SizedBox(height: 22),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                });
                if (_isPlaying) {
                  startPlaying();
                } else {
                  stopPlaying();
                }
              },
              child: Text(_isPlaying ? "중지" : "재생")),
        ],
      ),
    );
  }

  void initializer() async {
    filePath = '/sdcard/Download/temp.wav';
    _recordingSession = FlutterSoundRecorder();
    await _recordingSession.openAudioSession(
        focus: AudioFocus.requestFocusAndStopOthers,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker);
    await _recordingSession.setSubscriptionDuration(const Duration(
        milliseconds: 10));
    await initializeDateFormatting();
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> startRecording() async {
    setState(() {
      _isRecording = true;
    });
    Directory directory = Directory(dirname(filePath));
    if (!directory.existsSync()) {
      directory.createSync();
    }
    _recordingSession.openAudioSession();
    await _recordingSession.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
    );
  }

  Future<String?> stopRecording() async {
    setState(() {
      _isRecording = false;
    });
    _recordingSession.closeAudioSession();
    return await _recordingSession.stopRecorder();
  }

  Future<void> startPlaying() async {
    recordingPlayer.open(
      Audio.file(filePath),
      autoStart: true,
      showNotification: true,
    );
    recordingPlayer.playlistAudioFinished.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> stopPlaying() async {
    recordingPlayer.stop();
  }

  Future<List<int>> getPeakLevels(String _pathAudio) async {
    File outputFile = File(
        '/data/user/0/com.flutter.shoutout/cache/1-flutter_sound_example.txt');

    await _flutterFFmpeg
        .execute(
        "-i '$_pathAudio' -af aresample=16000,asetnsamples=16000,astats=reset=1:metadata=1,ametadata=print:key='lavfi.astats.Overall.Peak_level':file=${outputFile.path} -f null -")
        .then((rc) => print("FFmpeg process exited with rc $rc"));

    List<int> wave = [];

    await outputFile
        .openRead()
        .map(utf8.decode)
        .transform(const LineSplitter())
        .forEach((l) {
      if (l.startsWith("frame")) return;
      double value = double.tryParse(l.split("=").last) ?? 0;
      wave.add(70 + value.toInt());
    });

    return wave;
  }
}
