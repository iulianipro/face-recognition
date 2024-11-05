import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
  List<Face> detectedFaces = [];
  String debugText = "Initializing...";

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(cameras[0], ResolutionPreset.high);
    _initializeControllerFuture = _cameraController.initialize();

    // Start image stream
    _cameraController.startImageStream((CameraImage image) {
      processCameraImage(image);
    });
  }

  Future<void> processCameraImage(CameraImage image) async {
    try {
      if (image.format == ImageFormatGroup.yuv420) {
        final width = image.width;
        final height = image.height;

        final bytes = _getNV21Bytes(image);
        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: width,
          ),
        );

        final List<Face> faces = await faceDetector.processImage(inputImage);

        setState(() {
          detectedFaces = faces;
          debugText = "Detected ${faces.length} face(s)";
        });
      } else {
        setState(() {
          debugText = "Unsupported image format: ${image.format}";
        });
      }
    } catch (e) {
      setState(() {
        debugText = "Error processing image: $e";
      });
    }
  }

  Uint8List _getNV21Bytes(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final List<int> nv21Bytes = List.filled(width * height * 3 ~/ 2, 0);

    int index = 0;
    for (final plane in image.planes) {
      if (index == 0) {
        nv21Bytes.setRange(0, plane.bytes.length, plane.bytes);
      }
      index++;
    }

    int uvIndex = width * height;
    for (int y = 0; y < height ~/ 2; y++) {
      for (int x = 0; x < width ~/ 2; x++) {
        if (image.planes.length >= 2) {
          nv21Bytes[uvIndex++] = image.planes[1].bytes[x + y * image.planes[1].bytesPerRow];
          nv21Bytes[uvIndex++] = image.planes[2].bytes[x + y * image.planes[2].bytesPerRow];
        }
      }
    }

    return Uint8List.fromList(nv21Bytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Face Recognition App'),
            ),
            body: Stack(
              children: [
                CameraPreview(_cameraController),
                CustomPaint(
                  painter: EmojiPainter(detectedFaces),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Text(
                      debugText,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    faceDetector.close();
    super.dispose();
  }
}

class EmojiPainter extends CustomPainter {
  final List<Face> faces;

  EmojiPainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in faces) {
      final rect = face.boundingBox;
      final emojiRect = Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height);

      // Draw a rectangle around the detected face for debugging
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(rect, paint);

      // Draw the emoji
      String emoji = _determineEmoji(face);
      _drawEmoji(canvas, emojiRect, emoji);
    }
  }

  String _determineEmoji(Face face) {
    return '😊'; // Set a default emoji
  }

  void _drawEmoji(Canvas canvas, Rect rect, String emoji) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: rect.height,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(rect.left, rect.top)); // Adjust emoji position
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
