import 'dart:async';
import 'package:flutter/material.dart';
import 'sprite_animator.dart';

class CharacterStage extends StatefulWidget {
  final String message;
  final VoidCallback onDrank;
  final VoidCallback onSnooze;

  const CharacterStage({
    super.key,
    required this.message,
    required this.onDrank,
    required this.onSnooze,
  });

  @override
  State<CharacterStage> createState() => _CharacterStageState();
}

class _CharacterStageState extends State<CharacterStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  CharacterState _state = CharacterState.walking;
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    _walk.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _state = CharacterState.sipping);
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              _state = CharacterState.idle;
              _showPrompt = true;
            });
          }
        });
      }
    });
    _walk.forward();
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final targetX = width * 0.5 - 60;
    return AnimatedBuilder(
      animation: _walk,
      builder: (context, _) {
        final x = _walk.value * targetX;
        return Stack(children: [
          Positioned(
            left: x,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showPrompt) _bubble(),
                SpriteAnimator(state: _state),
                if (_showPrompt) _buttons(),
              ],
            ),
          ),
        ]);
      },
    );
  }

  Widget _bubble() => Container(
        constraints: const BoxConstraints(maxWidth: 240),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black87, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.message,
            style: const TextStyle(color: Colors.black87)),
      );

  Widget _buttons() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            key: const Key('drank-button'),
            onPressed: widget.onDrank,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade400),
            child: const Text('YES, DRANK'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('snooze-button'),
            onPressed: widget.onSnooze,
            child: const Text('SNOOZE'),
          ),
        ],
      );
}
