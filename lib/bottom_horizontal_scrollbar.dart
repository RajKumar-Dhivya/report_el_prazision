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

    return Material(

      elevation: 8,

      color: Colors.white,

      child: SizedBox(

        height: 28, // 👈 visible height

        child: Scrollbar(

          controller: controller,

          thumbVisibility: true,

          trackVisibility: true,

          interactive: true,

          child: SingleChildScrollView(

            controller: controller,

            scrollDirection: Axis.horizontal,

            child: Container(

              width: width,   // 🔥 important

              height: 1,

              color: Colors.transparent,

            ),

          ),

        ),

      ),

    );

  }

}

 
