import 'package:flutter/material.dart'; 
import 'custom_toolbarShape.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  late String title;
  CustomAppBar({super.key, required this.title});
  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
            color: Colors.transparent,
            child: Stack(fit: StackFit.loose, children: <Widget>[
              Container(
                  color: const Color.fromARGB(255, 57, 127, 206),
                  width: MediaQuery.of(context).size.width,
                  height: 100,
                  child: const CustomPaint(
                    painter: CustomToolbarShape(
                        lineColor: Color.fromARGB(255, 38, 78, 208)),
                  )),
              Align(
                  alignment: const Alignment(0.1, 0.4),
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500),
                  )),
 
            ])));
  }
}