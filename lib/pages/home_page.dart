import 'package:flutter/material.dart';
import 'package:mlkit_text_recognition_v2_app/pages/camera_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日本語OCRアプリ'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      return const CameraPage();
                    }),
                  );
                },
                child: const Text('読み取り開始'))
          ],
        ),
      ),
    );
  }
}
