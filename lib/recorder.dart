import 'package:flutter/material.dart';

class Recorder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(onPressed: null, child: Text("녹음 시작")),
              const SizedBox(width:16),
              ElevatedButton(onPressed: null, child: Text("녹음 중지"))
            ],
          ),
          const SizedBox(height: 22),

        ],
      ),
    );
  }
}
