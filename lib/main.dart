import 'package:flutter/material.dart';
import 'package:recording_test/recorder.dart';

void main() => runApp(RecordingTest());

const String ROOT_PAGE = '/';

class RecordingTest extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recording Test',
      debugShowCheckedModeBanner: false,
      initialRoute: ROOT_PAGE,
      routes: {
        ROOT_PAGE: (context) => Recorder()
      }
    );
  }
}