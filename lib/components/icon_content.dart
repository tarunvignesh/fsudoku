import 'package:flutter/material.dart';
import 'package:bmi_calculator/constants.dart';

class IconContent extends StatelessWidget {
  IconContent({this.icon, this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        direction: Axis.vertical,
        //  spacing: 8.0, // gap between adjacent chips
        //  runSpacing: 4.0, // ga
        //  mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(child: Icon(icon, size: 80.0)),
          Text(
            label,
            style: kLabelTextStyle,
          )
        ],
      ),
    );
  }
}
