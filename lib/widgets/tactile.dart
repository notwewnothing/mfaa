import 'package:flutter/widgets.dart';

class Tactile extends StatefulWidget {
  const Tactile({super.key, required this.child, this.pressedScale = 0.96});

  final Widget child;
  final double pressedScale;

  @override
  State<Tactile> createState() => _TactileState();
}

// present day ... presenent time ...
class _TactileState extends State<Tactile> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
