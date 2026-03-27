import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CloudboxTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF2D5F8A),
    textTheme: GoogleFonts.interTextTheme(),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFF2D5F8A),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}
