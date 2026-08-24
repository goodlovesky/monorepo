import 'package:flutter/material.dart';

abstract final class AppColors {
  // 通用色（不依赖主题）
  static const blue = Color(0xFF237FD5);
  static const orange = Color(0xFFFFA20F);
  static const green = Color(0xFF2AD364);
  static const red = Colors.redAccent;

  // 深色
  static const darkBackground = Color(0xFF101010);
  static const darkCard = Color(0xFF202020);
  static const darkCardElevated = Color(0xFF2D2D2D);
  static const darkText = Color(0xFFF4F4F4);
  static const darkMuted = Color(0xFFA7A7A7);
  static const darkDivider = Color(0xFF6C6C6C);

  // 浅色
  static const lightBackground = Color(0xFFF6F7FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardElevated = Color(0xFFEDEFF5);
  static const lightText = Color(0xFF1A1B22);
  static const lightMuted = Color(0xFF6B7280);
  static const lightDivider = Color(0xFFE2E5EC);

  // 向后兼容别名（指向深色版本，老代码如 help_about_pages.dart 仍可用）。
  static const background = darkBackground;
  static const card = darkCard;
  static const cardElevated = darkCardElevated;
  static const text = darkText;
  static const muted = darkMuted;
  static const divider = darkDivider;
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark
      ? (
          background: AppColors.darkBackground,
          card: AppColors.darkCard,
          cardElevated: AppColors.darkCardElevated,
          text: AppColors.darkText,
          muted: AppColors.darkMuted,
          divider: AppColors.darkDivider,
        )
      : (
          background: AppColors.lightBackground,
          card: AppColors.lightCard,
          cardElevated: AppColors.lightCardElevated,
          text: AppColors.lightText,
          muted: AppColors.lightMuted,
          divider: AppColors.lightDivider,
        );
  final colorScheme = isDark
      ? ColorScheme.dark(
          primary: AppColors.blue,
          surface: palette.card,
          onSurface: palette.text,
        )
      : ColorScheme.light(
          primary: AppColors.blue,
          surface: palette.card,
          onSurface: palette.text,
        );
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    colorScheme: colorScheme,
    fontFamily: 'ClashSerif',
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'ClashSerif',
        fontSize: 19,
        letterSpacing: 3,
        color: palette.text,
      ),
    ),
    dividerColor: palette.divider,
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontFamily: 'ClashSerif',
        fontSize: 27,
        letterSpacing: 2,
        color: palette.text,
      ),
      titleLarge: TextStyle(
        fontFamily: 'ClashSerif',
        fontSize: 22,
        letterSpacing: 2,
        color: palette.text,
      ),
      titleMedium: TextStyle(
        fontFamily: 'ClashSerif',
        fontSize: 18,
        letterSpacing: 1.5,
        color: palette.text,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'ClashSerif',
        fontSize: 17,
        letterSpacing: 1.2,
        color: palette.text,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'ClashSerif',
        fontSize: 15,
        letterSpacing: 1,
        color: palette.text,
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      PaletteExtension(
        background: palette.background,
        card: palette.card,
        cardElevated: palette.cardElevated,
        text: palette.text,
        muted: palette.muted,
        divider: palette.divider,
      ),
    ],
  );
}

/// 语义化调色板扩展：让代码能读 `Theme.of(context).extension<PaletteExtension>()`。
@immutable
class PaletteExtension extends ThemeExtension<PaletteExtension> {
  final Color background;
  final Color card;
  final Color cardElevated;
  final Color text;
  final Color muted;
  final Color divider;

  const PaletteExtension({
    required this.background,
    required this.card,
    required this.cardElevated,
    required this.text,
    required this.muted,
    required this.divider,
  });

  @override
  PaletteExtension copyWith({
    Color? background,
    Color? card,
    Color? cardElevated,
    Color? text,
    Color? muted,
    Color? divider,
  }) => PaletteExtension(
    background: background ?? this.background,
    card: card ?? this.card,
    cardElevated: cardElevated ?? this.cardElevated,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    divider: divider ?? this.divider,
  );

  @override
  PaletteExtension lerp(ThemeExtension<PaletteExtension>? other, double t) {
    if (other is! PaletteExtension) return this;
    return PaletteExtension(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
