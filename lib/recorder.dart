import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mfcc/mfcc.dart';
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

  late String _filePath;
  late String _ffmpegFilePath;

  final FlutterSoundFFmpeg _flutterFFmpeg = FlutterSoundFFmpeg();
  String _mfccText = "";


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
              ElevatedButton(onPressed: _isRecording ? null : startRecording, child: const Text("녹음 시작")),
              const SizedBox(width:16),
              ElevatedButton(onPressed: _isRecording ? stopRecording : null, child: const Text("녹음 중지")),
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
          const SizedBox(height: 32),
          Text(_mfccText)
        ],
      ),
    );
  }

  void initializer() async {
    _filePath = '/sdcard/Download/temp.wav';
    _ffmpegFilePath = '/sdcard/Download/flutter_sound_test.txt';
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
    Directory directory = Directory(dirname(_filePath));
    if (!directory.existsSync()) {
      directory.createSync();
    }
    _recordingSession.openAudioSession();
    await _recordingSession.startRecorder(
      toFile: _filePath,
      codec: Codec.pcm16WAV,
    );
  }

  Future<String?> stopRecording() async {
    setState(() {
      _isRecording = false;
    });
    await _recordingSession.closeAudioSession();
    var mfcc = getMFCC(await getPeakLevels(_filePath));
    StringBuffer tmp = StringBuffer();
    for (List<double> i in mfcc) {
      tmp.write("$i");
    }
    setState(() {
      _mfccText = tmp.toString();
    });

    return await _recordingSession.stopRecorder();
  }

  Future<void> startPlaying() async {
    recordingPlayer.open(
      Audio.file(_filePath),
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

  Future<List<double>> getPeakLevels(String _pathAudio) async {
    File outputFile = File(_ffmpegFilePath);

    await _flutterFFmpeg
        .execute(
        "-i '$_pathAudio' -af aresample=16000,asetnsamples=16000,astats=reset=1:metadata=1,ametadata=print:key='lavfi.astats.Overall.Peak_level':file=${outputFile.path} -f null -")
        .then((rc) => print("FFmpeg process exited with rc $rc"));

    List<double> wave = [];

    await outputFile
        .openRead()
        .map(utf8.decode)
        .transform(const LineSplitter())
        .forEach((l) {
      if (l.startsWith("frame")) return;
      double value = double.tryParse(l.split("=").last) ?? 0;
      wave.add(70 + value.toDouble());
    });

    return wave;
  }

  List<List<double>> getMFCC(List<double> list) {
    var sampleRate = 16000;
    var windowLength = 1024;
    var windowStride = 512;
    var fftSize = 512;
    var numFilter = 20;
    var numCoefs = 13;
    var features = MFCC.mfccFeats(list, sampleRate, windowLength, windowStride, fftSize, numFilter, numCoefs);

    return features;
  }
}
