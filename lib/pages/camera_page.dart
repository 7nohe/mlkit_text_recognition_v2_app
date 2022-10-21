import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mlkit_text_recognition_v2_app/utils/camera.dart';

List<CameraDescription> cameras = [];

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraState();
}

class _CameraState extends State<CameraPage> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.japanese);
  bool isReady = false;
  bool skipScanning = false;
  bool isScanned = false;
  RecognizedText? _recognizedText;
  Size? absoluteImageSize;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  _processImage(CameraImage availableImage) async {
    if (!mounted || skipScanning) return;
    setState(() {
      skipScanning = true;
    });

    final inputImage = convert(
      camera: cameras[0],
      cameraImage: availableImage,
    );

    _recognizedText = await _textRecognizer.processImage(inputImage);
    if (!mounted) return;
    setState(() {
      skipScanning = false;
      absoluteImageSize = inputImage.inputImageData?.size;
    });
    if (_recognizedText != null && _recognizedText!.text.isNotEmpty) {
      _controller.stopImageStream();
      setState(() {
        isScanned = true;
      });
    }
  }

  Future<void> _setup() async {
    cameras = await availableCameras();

    _controller = CameraController(cameras[0], ResolutionPreset.max);

    await _controller.initialize().catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });

    if (!mounted) {
      return;
    }

    setState(() {
      isReady = true;
    });

    _controller.startImageStream(_processImage);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !isReady || !_controller.value.isInitialized;

    if (isLoading) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('テキスト読み取り画面'),
          ),
          body: Column(
              children: const [Center(child: CircularProgressIndicator())]));
    }
    final Size imageSize = Size(
      _controller.value.previewSize!.width,
      _controller.value.previewSize!.height,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('テキスト読み取り画面'),
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: 6 / 9,
              child: Stack(
                children: [
                  ClipRect(
                    child: Transform.scale(
                      scale: _controller.value.aspectRatio * 6 / 9,
                      child: Center(
                        child: CameraPreview(_controller),
                      ),
                    ),
                  ),
                  Container(
                    height: imageSize.height,
                    width: imageSize.width,
                    decoration: ShapeDecoration(
                      shape: CustomShapeBorder(
                        blocks: _recognizedText?.blocks,
                        absoluteImageSize: absoluteImageSize,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        isScanned
            ? ElevatedButton(
                child: const Text('再度読み取る'),
                onPressed: () {
                  setState(() {
                    isScanned = false;
                    _recognizedText = null;
                  });
                  _controller.startImageStream(_processImage);
                },
              )
            : const Text('読み込み中'),
      ]),
    );
  }
}

class CustomShapeBorder extends ShapeBorder {
  const CustomShapeBorder({this.blocks, this.absoluteImageSize});
  final List<TextBlock>? blocks;
  final Size? absoluteImageSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(20);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) async {
    final backgroundPaint = Paint();
    final double scaleX =
        absoluteImageSize != null ? rect.width / absoluteImageSize!.width : 1;
    final double scaleY =
        absoluteImageSize != null ? rect.height / absoluteImageSize!.height : 1;

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..restore();

    if (blocks == null && blocks != null && blocks!.isEmpty) return;

    // 描画するBoxのスタイル
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    paint.color = Colors.lightBlue;

    // 描画するTextのスタイル
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 12,
    );

    // 各ブロックのBoxtとTextを描画
    blocks?.forEach((block) {
      // Blockの描画
      final blockRect = Rect.fromLTWH(
          block.boundingBox.left,
          block.boundingBox.top,
          block.boundingBox.width,
          block.boundingBox.height);
      canvas.drawRect(
          Rect.fromLTRB(
            blockRect.left * scaleX + rect.left,
            blockRect.top * scaleY + rect.top,
            blockRect.right * scaleX + rect.left,
            blockRect.bottom * scaleY + rect.top,
          ),
          paint);

      // Textの描画
      final textSpan = TextSpan(
        text: block.text,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(
        minWidth: 0,
        maxWidth: rect.width,
      );
      final dx = block.boundingBox.left * scaleX + rect.left;
      final dy = block.boundingBox.top * scaleY + rect.top;
      final offset = Offset(dx, dy);
      textPainter.paint(canvas, offset);
    });
  }

  @override
  ShapeBorder scale(double t) {
    return CustomShapeBorder(absoluteImageSize: absoluteImageSize);
  }
}
