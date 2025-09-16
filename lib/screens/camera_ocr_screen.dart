import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CameraOcrScreen extends StatefulWidget {
  const CameraOcrScreen({super.key});
  @override
  State<CameraOcrScreen> createState() => _CameraOcrScreenState();
}

class _CameraOcrScreenState extends State<CameraOcrScreen> {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cameras = await availableCameras();
    final cam = cameras.first;
    _controller = CameraController(cam, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndOcr() async {
    if (!(_controller?.value.isInitialized ?? false)) return;
    final file = await _controller!.takePicture();
    final input = InputImage.fromFilePath(file.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(input);
    await recognizer.close();

    final raw = result.text;
    final best = _extractBestDrugName(raw);
    if (!mounted) return;

    // Return the best guess (or full text) to HomePage
    Navigator.pop(context, best.isNotEmpty ? best : raw);
  }

  String _extractBestDrugName(String text) {
    // Simple heuristic
    final lines = text.split('\n');
    final counts = <String,int>{};
    final reg = RegExp(r'([A-Z][A-Za-z0-9\-]+(?:\s+[A-Z][A-Za-z0-9\-]+)*)');
    for (final l in lines) {
      final cleaned = l.trim().replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), '');
      final m = reg.firstMatch(cleaned);
      if (m != null) {
        final cand = m.group(1)!.trim();
        if (cand.length >= 3) {
          counts[cand] = (counts[cand] ?? 0) + 1;
        }
      }
    }
    final sorted = counts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return sorted.isNotEmpty ? sorted.first.key : '';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Label')),
      body: CameraPreview(_controller!),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureAndOcr,
        child: const Icon(Icons.check),
      ),
    );
  }
}
