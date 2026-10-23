// 主题：两套皮肤各组装一个 ThemeData。
//
// 经典（默认）：等于 v1.0 —— 纯色卡片、实底背景、扁平按钮、跟随系统明暗。
// 全息：爪 Pro 那套 —— Scaffold 背景设透明，真正的背景由 main.dart 的分层画布提供。
//
// 关键区别：全息皮肤必须把 scaffoldBackgroundColor 设成透明，否则玻璃糊在自己的
// 不透明底色上，白做；经典皮肤反过来必须有实色底，否则卡片没有对比。

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 金额用等宽数字（tabular figures）——数字宽度一致，多行金额才会对齐
const tabularFigures = [FontFeature.tabularFigures()];

/// 经典皮肤（v1.0）
ThemeData buildClassicTheme(Brightness b) {
  final isDark = b == Brightness.dark;
  final bg = isDark ? Ck.darkBg : Ck.lightBg;
  final card = isDark ? Ck.darkCard : Ck.lightCard;
  final line = isDark ? Ck.darkLine : Ck.lightLine;
  final txHi = isDark ? Ck.darkTxHi : Ck.lightTxHi;
  final txMid = isDark ? Ck.darkTxMid : Ck.lightTxMid;

  final scheme = ColorScheme.fromSeed(seedColor: Ck.primary, brightness: b).copyWith(
    primary: isDark ? Ck.primaryDark : Ck.primary,
    surface: card,
    error: const Color(0xFFB3261E),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    cardColor: card,
    canvasColor: bg,

    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: txHi,
      ),
      iconTheme: IconThemeData(color: txMid, size: 22),
      actionsIconTheme: IconThemeData(color: txMid, size: 22),
    ),

    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF2A3331) : const Color(0xFF20302C),
      contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: (isDark ? Ck.primaryDark : Ck.primary).withAlpha(28),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: txMid),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: txMid, size: 23)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: isDark ? Ck.darkCard : Colors.white,
      selectedColor: (isDark ? Ck.primaryDark : Ck.primary).withAlpha(28),
      side: BorderSide(color: line),
      labelStyle: TextStyle(fontSize: 14, color: txHi),
      secondaryLabelStyle: TextStyle(fontSize: 14, color: txHi),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      showCheckmark: false,
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: line,
      thumbColor: scheme.primary,
      trackHeight: 3,
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withAlpha(60),
      selectionHandleColor: scheme.primary,
    ),

    listTileTheme: ListTileThemeData(
      textColor: txHi,
      iconColor: txMid,
      subtitleTextStyle: TextStyle(fontSize: 12.5, color: txMid),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: txHi),
      contentTextStyle: TextStyle(fontSize: 14, color: txMid, height: 1.6),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
  );
}

/// 全息皮肤（爪 Pro）
ThemeData buildHoloTheme(BgTheme t) {
  final light = Tok.isLight(t);
  final brightness = light ? Brightness.light : Brightness.dark;
  final accent = Tok.accentOf(t);
  final txHi = Tok.txHiOf(t);
  final txMid = Tok.txMidOf(t);
  final txDim = Tok.txDimOf(t);

  final scheme = ColorScheme.fromSeed(
    seedColor: Tok.accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    secondary: Tok.accentMint,
    error: Tok.alert,
    surface: Tok.panelOpaque(t),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    cardColor: Tok.panelOpaque(t),
    // 透明：让 main.dart 的分层背景透上来
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: txHi,
      ),
      iconTheme: IconThemeData(color: txMid, size: 22),
      actionsIconTheme: IconThemeData(color: txMid, size: 22),
    ),

    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .white
        .apply(bodyColor: txHi, displayColor: txHi),

    dividerTheme: DividerThemeData(
      color: light ? const Color.fromRGBO(120, 92, 170, 0.14) : Tok.line,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? const Color(0xFFF3EEFA) : const Color(0xFF2A1C4A),
      contentTextStyle: TextStyle(fontSize: 13.5, color: txHi),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Tok.glassEdge),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Tok.panelOpaque(t),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tok.radiusLiquid),
        side: const BorderSide(color: Tok.glassEdge),
      ),
      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: txHi),
      contentTextStyle: TextStyle(fontSize: 14, color: txMid, height: 1.6),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Tok.panelOpaque(t),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      dragHandleColor: txDim,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: light
          ? const Color.fromRGBO(255, 255, 255, 0.60)
          : const Color.fromRGBO(26, 17, 54, 0.55),
      selectedColor: accent.withAlpha(46),
      side: const BorderSide(color: Tok.line),
      labelStyle: TextStyle(fontSize: 13.5, color: txHi),
      secondaryLabelStyle: TextStyle(fontSize: 13.5, color: txHi),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      showCheckmark: false,
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: accent.withAlpha(50),
      thumbColor: accent,
      overlayColor: accent.withAlpha(30),
      trackHeight: 3,
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withAlpha(70),
      selectionHandleColor: accent,
    ),

    iconTheme: IconThemeData(color: txMid),

    // NavigationBar 背景由 GlassNavShell 提供，这里只留透明 + 文字色
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accent.withAlpha(40),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: txMid, letterSpacing: 0.4),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: txMid, size: 22)),
    ),

    listTileTheme: ListTileThemeData(
      textColor: txHi,
      iconColor: txMid,
      subtitleTextStyle: TextStyle(fontSize: 12.5, color: txDim),
    ),
  );
}
