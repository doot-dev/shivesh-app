import 'package:flutter/material.dart';

extension BuildContextExtension on BuildContext {
  double get height => MediaQuery.of(this).size.height;
  double get width => MediaQuery.of(this).size.width;
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode =>
      MediaQuery.of(this).platformBrightness == Brightness.dark;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isTablet => width > 420;
  bool get isDesktop => width > 620;
  bool get isSmallMobile => width < 280;
  double heightPercentage(double percentage) => height * percentage / 100;
  double widthPercentage(double percentage) => width * percentage / 100;
}
