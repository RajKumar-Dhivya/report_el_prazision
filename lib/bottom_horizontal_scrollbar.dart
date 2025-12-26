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

        return Theme(
          data: ThemeData(
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.cyanAccent.withOpacity(0.8)),
              trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
              trackVisibility: WidgetStateProperty.all(true),
              thickness: WidgetStateProperty.all(8.0),
              radius: const Radius.circular(10),
            ),
          ),
          child: Container(
            height: 20, // Increased slightly to make it easier to grab
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: RawScrollbar(
              controller: controller,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              interactive: true, 
              radius: const Radius.circular(10),
              // Updated colors to match your Table Scrollbar exactly
              thumbColor: Colors.cyanAccent.withOpacity(0.8), 
              trackColor: Colors.white.withOpacity(0.1),
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                // Measure against the same width as your data content
                child: SizedBox(
                  width: width, 
                  height: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}