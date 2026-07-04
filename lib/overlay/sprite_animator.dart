import 'dart:async';
import 'package:flutter/material.dart';

enum CharacterState { idle, walking, sipping }

class SpriteFrames {
  static const Map<CharacterState, List<String>> frames = {
    CharacterState.idle: ['assets/character/idle_0.png'],
    CharacterState.walking: [
      'assets/character/walk_0.png',
      'assets/character/walk_1.png',
      'assets/character/walk_2.png',
      'assets/character/walk_3.png',
    ],
    CharacterState.sipping: [
      'assets/character/sip_0.png',
      'assets/character/sip_1.png',
    ],
  };
}

class SpriteAnimator extends StatefulWidget {
  final CharacterState state;
  final double fps;
  const SpriteAnimator({super.key, required this.state, this.fps = 8});

  @override
  State<SpriteAnimator> createState() => _SpriteAnimatorState();
}

class _SpriteAnimatorState extends State<SpriteAnimator> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  @override
  void didUpdateWidget(SpriteAnimator old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state || old.fps != widget.fps) {
      _index = 0;
      _startCycle();
    }
  }

  void _startCycle() {
    _timer?.cancel();
    final frames = SpriteFrames.frames[widget.state]!;
    if (frames.length <= 1) return;
    final period = Duration(milliseconds: (1000 / widget.fps).round());
    _timer = Timer.periodic(period, (_) {
      setState(() => _index = (_index + 1) % frames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = SpriteFrames.frames[widget.state]!;
    return Image.asset(frames[_index % frames.length],
        width: 120, height: 220, gaplessPlayback: true);
  }
}
