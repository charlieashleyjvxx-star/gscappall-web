import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF9A620D);
  static const learning = Color(0xFF2F6D50);
  static const information = Color(0xFF376B7A);
  static const canvas = Color(0xFFF7F5F1);
  static const surface = Color(0xFFFFFBF5);
  static const outline = Color(0xFFE2DDD5);
  static const ink = Color(0xFF25211C);
}

abstract final class AppSpacing {
  static const xSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const xLarge = 24.0;
  static const xxLarge = 32.0;
}

abstract final class AppRadii {
  static const control = 10.0;
  static const card = 12.0;
  static const feature = 16.0;
}

abstract final class AppLayout {
  static const compactWidth = 390.0;
  static const contentMaxWidth = 1180.0;
  static const readingMaxWidth = 820.0;
}
