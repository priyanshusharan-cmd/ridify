import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// WhatsApp-style swipe-to-reply gesture widget.
///
/// Drag a chat bubble to the right to trigger a reply action.
/// Shows a reply arrow that fades/scales in behind the bubble.
/// Snaps back with a spring animation after releasing or triggering.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const double _triggerThreshold = 64.0;   // px to trigger reply
  static const double _maxDrag = 100.0;            // max drag distance

  // ── State ──────────────────────────────────────────────────────────────────
  double _dragOffset = 0.0;
  bool _hasTriggered = false;

  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.addListener(() {
      setState(() => _dragOffset = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_resetController.isAnimating) return;

    setState(() {
      // Only allow right swipe (positive dx)
      _dragOffset += details.delta.dx;
      // Clamp: no left overshoot, rubber-band at max
      if (_dragOffset < 0) _dragOffset = 0;
      if (_dragOffset > _maxDrag) {
        // Rubber-band effect past max
        _dragOffset = _maxDrag + (_dragOffset - _maxDrag) * 0.15;
      }
    });

    // Haptic feedback when crossing the threshold
    if (!_hasTriggered && _dragOffset >= _triggerThreshold) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    } else if (_hasTriggered && _dragOffset < _triggerThreshold) {
      _hasTriggered = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final shouldTrigger = _dragOffset >= _triggerThreshold;

    // Snap back
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);

    _hasTriggered = false;

    if (shouldTrigger) {
      widget.onReply();
    }
  }

  void _onHorizontalDragCancel() {
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);
    _hasTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    // Icon progress: 0.0 → 1.0 as drag approaches the threshold
    final double iconProgress =
        (_dragOffset / _triggerThreshold).clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon — sits behind the bubble, revealed as you drag
          if (_dragOffset > 2)
            Positioned(
              left: math.max(0, _dragOffset - 44),
              top: 0,
              bottom: 12, // account for message bottom margin
              child: Center(
                child: Opacity(
                  opacity: iconProgress,
                  child: Transform.scale(
                    scale: 0.5 + (iconProgress * 0.5),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _hasTriggered
                            ? (isDark ? Colors.blue[700] : Colors.blue[600])
                            : (isDark ? Colors.grey[700] : Colors.grey[400]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.reply,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // The actual message bubble, translated to the right
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
