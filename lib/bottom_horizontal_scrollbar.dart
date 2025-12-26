import 'package:flutter/material.dart';

class BottomHorizontalScrollbar extends StatelessWidget {
  final ScrollController controller;
  final double width;

  const BottomHorizontalScrollbar({
    super.key,
    required this.controller,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only show if content is wider than container
        if (width <= constraints.maxWidth) return const SizedBox.shrink();

        return Container(
          height: 15, // Height of the scrollbar area
          margin: const EdgeInsets.only(bottom: 5),
          child: RawScrollbar(
            controller: controller,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 8,
            interactive: true, // IMPORTANT: Allows dragging
            radius: const Radius.circular(10),
            thumbColor: Colors.cyanAccent.withOpacity(0.5),
            trackColor: Colors.white10,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              // This is the "dummy" content that the scrollbar measures
              child: SizedBox(
                width: width, 
                height: 15,
              ),
            ),
          ),
        );
      },
    );
  }
}