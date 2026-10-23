// 设计令牌。两套皮肤并存：
//
//   Skin.classic —— 经典（等于 v1.0 的样子，默认）：纯色卡片、扁平按钮、跟随系统明暗。
//                   色值不是凭记忆写的，是从 v1.0 的 theme.dart 原文里取回来的。
//   Skin.holo    —— 全息（爪 Pro 那套）：分层渐变背景 + 玻璃面板 + 宝石按钮。
//
// 为什么保留两套而不是二选一：全息那套是为横向宽屏设计的，搬到手机竖屏上，
// 渐变最亮的粉紫段会铺满整个表单区，灰色小字直接糊死（v1.1 真机截图证据）。
// 与其硬调一个两头不讨好的方案，不如让皮肤可换、默认给最稳的那套。
//
// ⚠ 一条硬规矩（全息皮肤）：紫底上的高光不能用白色，白高光在紫底上发灰发蓝，
//   必须用粉紫 #D9C2F0 才像晶体透光。这条是爪 Pro 用四轮改色换来的。

import 'package:flutter/material.dart';

/// 皮肤
enum Skin { classic, holo }

/// 三套内置背景（对应爪 Pro 的 data-bg，仅全息皮肤可用）
enum BgTheme { twilight, ink, paper }

/// 四种主按钮形态（对应爪 Pro 的 data-btn，仅全息皮肤可用）
enum BtnStyle { gem, glass, ghost, pill }

/// 经典皮肤的令牌：**数值取自 v1.0 的 theme.dart 原文**，不是重新配色。
///
/// 选色理由（当时写的，一并保留）：主色用深青绿而不是红色——红色在记账语境里
/// 天然等于"亏损"，而这本账是"我挣了多少"，用红会让人心理上不适。
/// 琥珀色只用于"需要你看一眼"的提示，不做装饰。
class Ck {
  static const primary = Color(0xFF0E7A63);
  static const primaryDark = Color(0xFF57C4A6);
  static const amber = Color(0xFFC2760A);
  static const amberLight = Color(0xFFE8A94A);

  static const lightBg = Color(0xFFF4F6F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightLine = Color(0xFFE2E7E5);

  static const darkBg = Color(0xFF0F1413);
  static const darkCard = Color(0xFF1A211F);
  static const darkLine = Color(0xFF2A3331);

  // 文字三级。v1.0 的次要文字是 #7B8783（白底 3.9:1，偏浅），这次按可读性提深一档
  static const lightTxHi = Color(0xFF16201D);
  static const lightTxMid = Color(0xFF3C4A46);
  static const lightTxDim = Color(0xFF5F6B67); // 白底 5.2:1
  static const darkTxHi = Color(0xFFFFFFFF);
  static const darkTxMid = Color(0xFFC3CCC9);
  static const darkTxDim = Color(0xFF96A29E); // 深底 5.6:1

  static const radius = 16.0;
  static const gap = 12.0;
}

class Tok {
  // ---------- 暮光紫背景六段 ----------
  // ⚠ 相对爪 Pro 原值整体压暗了一档：手机上这段渐变是竖着铺满全屏的，
  //   原值最亮的 #C08BB8 会让面板外的文字全部失守。
  static const bgVoid = Color(0xFF2B1F4E);
  static const bgAbyss = Color(0xFF3E2C66);
  static const bgMid = Color(0xFF5C3F87);
  static const bgWarm = Color(0xFF7E5786); // 原 #C08BB8
  static const bgSea = Color(0xFF332862);
  static const bgFoot = Color(0xFF1F1948);

  // ---------- 墨黑背景 ----------
  static const inkTop = Color(0xFF07030F);
  static const inkMid = Color(0xFF100A22);

  // ---------- 纸白背景 ----------
  static const paperTop = Color(0xFFF9F6FD);
  static const paperMid = Color(0xFFECE6F4);
  static const paperLow = Color(0xFFDDD5EC);

  // ---------- 面板本色 ----------
  static const panel = Color(0xFF1A1136);
  static const panelInset = Color(0xFF241753);

  // ---------- 主色 ----------
  static const accent = Color(0xFF9773D2);
  static const accentDeep = Color(0xFF5B2C90);
  static const accentUltra = Color(0xFF2E0F5C);
  static const accentMint = Color(0xFF3EF0C4); // 正向数值（金额）用
  static const crystalHi = Color(0xFFD9C2F0);
  static const crystalLift = Color(0xFFC3A6EC);
  static const alert = Color(0xFFFF2D4B);
  static const spark = Color(0xFFFF9A3C);

  // ---------- 文字 ----------
  static const txHi = Color(0xFFF5F0FF);
  static const txMid = Color(0xFFCBB8E6); // 原 #BDA9DC，提亮一档
  static const txDim = Color(0xFFB3A2CE); // 原 #8A76B0，在亮紫底上只有 1.2:1
  // 纸白主题的深色文字
  static const txHiLight = Color(0xFF2A1B45);
  static const txMidLight = Color(0xFF5B4A78);
  static const txDimLight = Color(0xFF746189);

  // ---------- 尺寸 ----------
  static const radiusLiquid = 18.0;
  static const radiusSoft = 10.0;
  static const glassBlur = 9.0; // CSS 18px ≈ Flutter sigma 9

  // ---------- 玻璃填充（乘透明度系数）----------
  static Color glassFill(double a) => Color.fromRGBO(20, 12, 40, 0.78 * a);
  static Color glassFillMid(double a) => Color.fromRGBO(17, 10, 34, 0.86 * a);
  static Color glassFillLow(double a) => Color.fromRGBO(8, 4, 18, 0.90 * a);

  static const glassEdge = Color.fromRGBO(195, 166, 236, 0.28);
  static const glassEdgeLit = Color.fromRGBO(217, 194, 240, 0.45);
  static const glassHi = Color.fromRGBO(217, 194, 240, 0.13);

  static const line = Color.fromRGBO(151, 115, 210, 0.20);
  static const lineSoft = Color.fromRGBO(151, 115, 210, 0.09);
  static const grid = Color.fromRGBO(151, 115, 210, 0.05);

  // ---------- 常用渐变 ----------
  /// 斜向镜面反光（对应 --sheen 122deg）
  static const sheen = LinearGradient(
    begin: Alignment(-0.85, -0.53),
    end: Alignment(0.85, 0.53),
    colors: [
      Color.fromRGBO(217, 194, 240, 0.13),
      Color.fromRGBO(217, 194, 240, 0.045),
      Color.fromRGBO(217, 194, 240, 0.0),
    ],
    stops: [0.0, 0.26, 0.52],
  );

  /// 宝石主按钮：顶面受光 → 腰身本色 → 根部压深
  /// 顶面原来从 #D9C2F0 起步，在亮背景上整个按钮发白发灰（"土"的主因之一），
  /// 现在压深并提高饱和度：白字落在腰身段的对比度 6:1 以上。
  static const gemGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFC9AEEA), Color(0xFF8A5BC9), Color(0xFF522189), Color(0xFF2A0C55)],
    stops: [0.0, 0.42, 0.76, 1.0],
  );

  /// 次级按钮：半透明紫填充
  static const subFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.fromRGBO(151, 115, 210, 0.22), Color.fromRGBO(151, 115, 210, 0.08)],
  );

  /// 内槽（输入框）：上暗下亮，做出"凹进去"的感觉
  /// 原来是 rgba(0,0,0,.24)，在亮紫底上几乎看不出边界，加深到 .45
  static const slotFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.fromRGBO(0, 0, 0, 0.45), Color.fromRGBO(217, 194, 240, 0.07)],
  );

  /// 语义红（停止/删除），与皮肤解耦
  static const dangerFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.fromRGBO(255, 45, 75, 0.26), Color.fromRGBO(255, 45, 75, 0.08)],
  );

  // ---------- 主题相关取色 ----------
  static bool isLight(BgTheme t) => t == BgTheme.paper;
  static Color txHiOf(BgTheme t) => isLight(t) ? txHiLight : txHi;
  static Color txMidOf(BgTheme t) => isLight(t) ? txMidLight : txMid;
  static Color txDimOf(BgTheme t) => isLight(t) ? txDimLight : txDim;
  static Color accentOf(BgTheme t) => isLight(t) ? accentDeep : crystalLift;

  /// 面板背景（纸白主题用浅色玻璃，深色主题用暗玻璃）
  static List<Color> panelFill(BgTheme t, double a) => isLight(t)
      ? [const Color.fromRGBO(255, 255, 255, 0.86), const Color.fromRGBO(250, 246, 255, 0.92)]
      : [glassFill(a), glassFillMid(a), glassFillLow(a)];

  static Color panelOpaque(BgTheme t) => isLight(t) ? const Color(0xFFF3EEFA) : const Color(0xFF1A1136);
}

/// 背景参数（对应 body[data-bg] 的压暗三件套）
class BgSpec {
  final List<Color> stops;
  final List<double> positions;
  final double ovA; // 极光整层强度
  final Color dimTop, dimMid, dimBot, dimVig;
  final bool dark;

  const BgSpec({
    required this.stops,
    required this.positions,
    required this.ovA,
    required this.dimTop,
    required this.dimMid,
    required this.dimBot,
    required this.dimVig,
    required this.dark,
  });

  /// 全息皮肤下，页面里"不在面板上"的文字直接压在这层背景上。
  /// 所以压暗强度不是审美问题，是可读性问题——见 test/contrast_test.dart。
  static BgSpec of(BgTheme t) => switch (t) {
        BgTheme.twilight => const BgSpec(
            stops: [Tok.bgVoid, Tok.bgAbyss, Tok.bgMid, Tok.bgWarm, Tok.bgSea, Tok.bgFoot],
            positions: [0, 0.26, 0.48, 0.62, 0.88, 1],
            ovA: 0.30,
            dimTop: Color.fromRGBO(11, 6, 32, 0.34),
            dimMid: Color.fromRGBO(11, 6, 32, 0.24),
            dimBot: Color.fromRGBO(11, 6, 32, 0.50),
            dimVig: Color.fromRGBO(11, 6, 32, 0.46),
            dark: true,
          ),
        BgTheme.ink => const BgSpec(
            stops: [Tok.inkTop, Tok.inkMid, Tok.inkTop],
            positions: [0, 0.55, 1],
            ovA: 1,
            dimTop: Color.fromRGBO(11, 6, 32, 0.12),
            dimMid: Color.fromRGBO(11, 6, 32, 0.06),
            dimBot: Color.fromRGBO(11, 6, 32, 0.20),
            dimVig: Color.fromRGBO(11, 6, 32, 0.30),
            dark: true,
          ),
        BgTheme.paper => const BgSpec(
            stops: [Tok.paperTop, Tok.paperMid, Tok.paperLow],
            positions: [0, 0.55, 1],
            ovA: 0.32,
            dimTop: Color.fromRGBO(11, 6, 32, 0.03),
            dimMid: Color.fromRGBO(11, 6, 32, 0.02),
            dimBot: Color.fromRGBO(11, 6, 32, 0.05),
            dimVig: Color.fromRGBO(11, 6, 32, 0.05),
            dark: false,
          ),
      };
}
