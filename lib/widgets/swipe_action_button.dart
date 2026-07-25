import 'package:flutter/material.dart';

class SwipeActionButton extends StatefulWidget {
  final bool isTracking;
  final bool isLoading;
  final Future<void> Function() onSwipeComplete;

  const SwipeActionButton({
    super.key,
    required this.isTracking,
    required this.isLoading,
    required this.onSwipeComplete,
  });

  @override
  State<SwipeActionButton> createState() => _SwipeActionButtonState();
}

class _SwipeActionButtonState extends State<SwipeActionButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isFinished = false;

  @override
  void didUpdateWidget(covariant SwipeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTracking != widget.isTracking) {
      setState(() {
        _dragPosition = 0.0;
        _isFinished = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isTracking;

    final Color trackBg = active ? const Color(0xFF450A0A) : const Color(0xFF0F172A);
    final Color trackBorder = active ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFF38BDF8).withValues(alpha: 0.4);
    final Color thumbColor = active ? const Color(0xFFEF4444) : const Color(0xFF38BDF8);
    final Color thumbIconColor = active ? Colors.white : const Color(0xFF0F172A);
    final IconData thumbIcon = active ? Icons.stop_rounded : Icons.play_arrow_rounded;
    final String labelText = active ? 'SWIPE TO STOP TRACKING  >>>' : 'SWIPE TO START TRACKING  >>>';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        const double thumbSize = 52.0;
        final double maxDrag = maxWidth - thumbSize - 8.0;

        return Container(
          height: 60,
          width: maxWidth,
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: trackBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: thumbColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Animated progress fill behind thumb
              Container(
                width: _dragPosition + thumbSize,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: active
                        ? [const Color(0xFF7F1D1D), const Color(0xFFEF4444)]
                        : [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
                  ),
                ),
              ),

              // Center Action Label Text
              Center(
                child: widget.isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: thumbColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            active ? 'Ending Session...' : 'Starting Session...',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      )
                    : Opacity(
                        opacity: (1.0 - (_dragPosition / maxDrag)).clamp(0.2, 1.0),
                        child: Text(
                          labelText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: active ? const Color(0xFFFCA5A5) : const Color(0xFF7DD3FC),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
              ),

              // Draggable Thumb Button
              Positioned(
                left: 4.0 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.isLoading
                      ? null
                      : (details) {
                          setState(() {
                            _dragPosition += details.delta.dx;
                            _dragPosition = _dragPosition.clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: widget.isLoading
                      ? null
                      : (details) async {
                          if (_dragPosition >= maxDrag * 0.75 && !_isFinished) {
                            setState(() {
                              _dragPosition = maxDrag;
                              _isFinished = true;
                            });
                            await widget.onSwipeComplete();
                            if (mounted) {
                              setState(() {
                                _dragPosition = 0.0;
                                _isFinished = false;
                              });
                            }
                          } else {
                            setState(() {
                              _dragPosition = 0.0;
                            });
                          }
                        },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: thumbColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      thumbIcon,
                      color: thumbIconColor,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
