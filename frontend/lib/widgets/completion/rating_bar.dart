import 'package:flutter/material.dart';

class InteractiveRatingBar extends StatefulWidget {
  final int initialRating;
  final bool isDark;
  final ValueChanged<int>? onRatingChanged;
  final double iconSize;

  const InteractiveRatingBar({
    super.key,
    this.initialRating = 4,
    required this.isDark,
    this.onRatingChanged,
    this.iconSize = 10.0,
  });

  @override
  State<InteractiveRatingBar> createState() => _InteractiveRatingBarState();
}

class _InteractiveRatingBarState extends State<InteractiveRatingBar> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            if (widget.onRatingChanged != null) {
              setState(() {
                _rating = index + 1;
              });
              widget.onRatingChanged!(_rating);
            }
          },
          child: Icon(
            Icons.star,
            size: widget.iconSize,
            color: index < _rating 
                ? const Color(0xFF4ADE80) 
                : (widget.isDark ? Colors.white24 : Colors.black12),
          ),
        );
      }),
    );
  }
}
