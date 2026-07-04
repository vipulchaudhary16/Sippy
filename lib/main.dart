import 'package:flutter/material.dart';
import 'overlay/overlay_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureOverlayWindow();
  runApp(const PocApp());
}

class PocApp extends StatelessWidget {
  const PocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SlidingBox(),
      ),
    );
  }
}

class SlidingBox extends StatefulWidget {
  const SlidingBox({super.key});

  @override
  State<SlidingBox> createState() => _SlidingBoxState();
}

class _SlidingBoxState extends State<SlidingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value * (width * 0.5);
        return Stack(children: [
          Positioned(
            left: x,
            bottom: 80,
            child: Container(width: 120, height: 220, color: Colors.teal),
          ),
        ]);
      },
    );
  }
}
