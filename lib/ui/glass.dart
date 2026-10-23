// 两套皮肤的按钮 / 顶栏 / 底栏 / 浮标。
//
// 全息皮肤照爪 Pro 的配方：填充是「三段渐变 + 内棱线 + 斜向 sheen」，
// 单色半透明看起来像磨砂塑料，只有加上顶边高光线和斜向反光，才像一块立起来的玻璃。
//
// 经典皮肤一律走 Material 原生控件（FilledButton / OutlinedButton / FAB），
// 不做任何自绘——自绘是"有设计语言"时才值得付的代价，v1.0 的诉求是稳。

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'pal.dart';
import 'tokens.dart';

/// 顶栏玻璃（放在 AppBar.flexibleSpace 里）；经典皮肤不要这层，返回空
class GlassHeader extends StatelessWidget {
  const GlassHeader({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Pal.isHolo) return const SizedBox.shrink();
    final light = Tok.isLight(appState.bg);
    final top = light ? const Color.fromRGBO(255, 255, 255, 0.72) : const Color.fromRGBO(38, 22, 72, 0.62);
    final bot = light ? const Color.fromRGBO(246, 241, 253, 0.66) : const Color.fromRGBO(14, 7, 24, 0.58);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bot],
            ),
            border: Border(bottom: BorderSide(color: light ? Tok.lineSoft : Tok.glassEdge)),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 1,
              color: light ? const Color.fromRGBO(120, 92, 170, 0.10) : const Color.fromRGBO(217, 194, 240, 0.14),
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃面板：全息皮肤的容器语言
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool glow; // 重要面板加一层外发光

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = Tok.radiusLiquid,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final light = Tok.isLight(appState.bg);
    final r = BorderRadius.circular(radius);
    final fills = Tok.panelFill(appState.bg, appState.glassA);

    final inner = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fills.length == 2 ? [fills[0], fills[0], fills[1]] : fills,
          stops: const [0, 0.46, 1],
        ),
        border: Border.all(color: light ? const Color.fromRGBO(120, 92, 170, 0.18) : Tok.glassEdge),
        borderRadius: r,
      ),
      child: Stack(
        children: [
          // 斜向镜面反光（常显但极淡）
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: light
                      ? const LinearGradient(
                          begin: Alignment(-0.85, -0.53),
                          end: Alignment(0.85, 0.53),
                          colors: [Color.fromRGBO(255, 255, 255, 0.55), Color.fromRGBO(255, 255, 255, 0.0)],
                          stops: [0.0, 0.5],
                        )
                      : Tok.sheen,
                ),
              ),
            ),
          ),
          // 顶边受光高光线：全息面板最标志性的一笔
          Positioned(
            top: 0,
            left: radius,
            right: radius,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    light ? const Color.fromRGBO(150, 120, 200, 0.35) : Tok.glassEdgeLit,
                    light ? const Color.fromRGBO(150, 120, 200, 0.35) : Tok.glassEdgeLit,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // 水波纹必须画在最近的 Material 上。面板主体是 DecoratedBox，
          // 不给一层透明 Material 的话，里面任何 ListTile / InkWell 都会抛
          // "ListTile background color or ink splashes may be invisible"。
          Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );

    final shadowed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: light ? const Color.fromRGBO(90, 60, 130, 0.14) : const Color.fromRGBO(6, 2, 20, 0.60),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          if (glow)
            BoxShadow(
              color: Tok.accent.withAlpha(30),
              blurRadius: 20,
              spreadRadius: -6,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: Tok.glassBlur * (0.6 + 0.4 * appState.glassA),
            sigmaY: Tok.glassBlur * (0.6 + 0.4 * appState.glassA),
          ),
          child: inner,
        ),
      ),
    );

    if (onTap == null) return shadowed;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: shadowed);
  }
}

/// 主按钮：经典=实心 FilledButton；全息=宝石/玻璃/描边/胶囊四形态
class GemButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool danger;
  final double height;
  final bool expand;

  const GemButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.danger = false,
    this.height = 52,
    this.expand = true,
  });

  @override
  State<GemButton> createState() => _GemButtonState();
}

class _GemButtonState extends State<GemButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (!Pal.isHolo) return _classic(context);

    final light = Tok.isLight(appState.bg);
    final variant = widget.danger ? BtnStyle.gem : appState.btn;
    final disabled = widget.onPressed == null;

    // 形态决定三件事：填充、描边、文字色
    late final Gradient? fill;
    late final Color border;
    late final Color textColor;
    late final double radius;
    var glow = 0.0;

    if (widget.danger) {
      fill = Tok.dangerFill;
      border = const Color.fromRGBO(255, 45, 75, 0.48);
      textColor = const Color(0xFFFFD2DA);
      radius = 12;
      glow = 0.18;
    } else {
      switch (variant) {
        case BtnStyle.gem:
          fill = Tok.gemGradient;
          border = const Color.fromRGBO(217, 194, 240, 0.55);
          // 紫底上不用纯白：爪 Pro 四轮改色换来的一条规矩
          textColor = const Color(0xFFFDF8FF);
          radius = 12;
          glow = 0.42;
        case BtnStyle.pill:
          fill = Tok.gemGradient;
          border = const Color.fromRGBO(217, 194, 240, 0.45);
          textColor = const Color(0xFFFDF8FF);
          radius = 999;
          glow = 0.34;
        case BtnStyle.glass:
          fill = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color.fromRGBO(217, 194, 240, 0.24),
              const Color.fromRGBO(151, 115, 210, 0.10),
            ],
          );
          border = Tok.glassEdgeLit;
          textColor = light ? Tok.accentDeep : Tok.crystalHi;
          radius = 12;
          glow = 0.16;
        case BtnStyle.ghost:
          fill = null;
          border = const Color.fromRGBO(151, 115, 210, 0.55);
          textColor = light ? Tok.accentDeep : Tok.crystalLift;
          radius = 12;
          glow = 0;
      }
    }

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: disabled ? null : fill,
        color: disabled
            ? (light ? const Color.fromRGBO(0, 0, 0, 0.06) : const Color.fromRGBO(255, 255, 255, 0.06))
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: disabled ? Tok.lineSoft : border),
        boxShadow: [
          // 外发光：宝石按钮的"能量感"来自这一层
          if (!disabled && glow > 0 && !_down)
            BoxShadow(color: Tok.accent.withAlpha((255 * glow).round()), blurRadius: 22, spreadRadius: -4),
          // 顶棱高光 + 底部压深：模拟一块切好的晶体
          if (!disabled)
            const BoxShadow(
              color: Color.fromRGBO(217, 194, 240, 0.40),
              blurRadius: 0,
              offset: Offset(0, 0.8),
              spreadRadius: 0,
            ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18, color: disabled ? Tok.txDim : textColor),
              const SizedBox(width: 7),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.04 * 15.5,
                color: disabled ? Tok.txDim : textColor,
                shadows: variant == BtnStyle.gem || variant == BtnStyle.pill || widget.danger
                    ? const [Shadow(color: Color.fromRGBO(20, 4, 48, 0.55), offset: Offset(0, 1), blurRadius: 2)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );

    final sized = widget.expand ? SizedBox(width: double.infinity, height: widget.height, child: body) : body;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled ? null : (_) => setState(() => _down = false),
      onTapCancel: disabled ? null : () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 90),
        offset: _down ? const Offset(0, 0.02) : Offset.zero,
        child: sized,
      ),
    );
  }

  Widget _classic(BuildContext context) {
    final bg = widget.danger ? const Color(0xFFB3261E) : Theme.of(context).colorScheme.primary;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 19, color: Colors.white),
          const SizedBox(width: 7),
        ],
        Text(widget.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
    final btn = FilledButton(
      onPressed: widget.onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        minimumSize: Size(0, widget.height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: child,
    );
    return widget.expand
        ? SizedBox(width: double.infinity, height: widget.height, child: btn)
        : SizedBox(height: widget.height, child: btn);
  }
}

/// 次级按钮：全息=半透明紫；经典=描边按钮
class SubButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;

  const SubButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 52,
    this.expand = false,
  });

  @override
  State<SubButton> createState() => _SubButtonState();
}

class _SubButtonState extends State<SubButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final light = !Pal.isDark(context);

    if (!Pal.isHolo) {
      final btn = OutlinedButton(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, widget.height),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: Pal.line(context)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(widget.label,
            style: TextStyle(fontSize: 15, color: Pal.hi(context), fontWeight: FontWeight.w500)),
      );
      return widget.expand
          ? SizedBox(width: double.infinity, height: widget.height, child: btn)
          : SizedBox(height: widget.height, child: btn);
    }

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: Tok.subFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(151, 115, 210, 0.42)),
        boxShadow: [
          if (!_down)
            const BoxShadow(color: Color.fromRGBO(217, 194, 240, 0.20), blurRadius: 0, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 17, color: light ? Tok.accentDeep : Tok.crystalLift),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: light ? Tok.accentDeep : Tok.crystalLift,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: widget.expand ? SizedBox(width: double.infinity, height: widget.height, child: body) : body,
    );
  }
}

/// 可选小胶囊：替代 Material 的 ChoiceChip。
///
/// 不用系统 Chip 的原因很实际：它自带一层不透明底色和 Material 阴影视差，
/// 压在玻璃面板上像贴了张便签纸；自绘之后能只留描边和一档半透明填充，
/// 选中态才有"点亮"的感觉。
class GlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// 右侧附加控件。用在「记住的自定义码」上放删除按钮：
  /// 记住是方便，但也得能让用户把它去掉，否则记忆只会越攒越乱。
  final Widget? trailing;

  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final holo = Pal.isHolo;
    final light = !Pal.isDark(context);
    final accent = Pal.accent(context);
    final fg = selected ? accent : Pal.mid(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: selected && holo
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent.withAlpha(70), accent.withAlpha(26)],
                )
              : null,
          color: selected
              ? (holo ? null : accent.withAlpha(26))
              : (holo
                  ? (light
                      ? const Color.fromRGBO(255, 255, 255, 0.46)
                      : const Color.fromRGBO(20, 14, 40, 0.55))
                  : Theme.of(context).cardColor),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? accent.withAlpha(170) : Pal.line(context),
            width: selected ? 1.3 : 1,
          ),
          boxShadow: selected && holo
              ? [BoxShadow(color: accent.withAlpha(38), blurRadius: 12, spreadRadius: -2)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 主操作浮标：全息=自绘切面宝石；经典=Material FAB
class GemFab extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const GemFab({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  State<GemFab> createState() => _GemFabState();
}

class _GemFabState extends State<GemFab> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (!Pal.isHolo) {
      return FloatingActionButton.extended(
        onPressed: widget.onPressed,
        icon: Icon(widget.icon),
        label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _down ? 0.96 : 1,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: Tok.gemGradient,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color.fromRGBO(217, 194, 240, 0.55)),
            boxShadow: [
              BoxShadow(
                color: Tok.accent.withAlpha(_down ? 70 : 130),
                blurRadius: _down ? 14 : 26,
                spreadRadius: -4,
              ),
              const BoxShadow(
                color: Color.fromRGBO(6, 2, 20, 0.55),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
              const BoxShadow(
                color: Color.fromRGBO(217, 194, 240, 0.42),
                blurRadius: 0,
                offset: Offset(0, 0.8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 21, color: const Color(0xFFFDF8FF)),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Color(0xFFFDF8FF),
                  shadows: [
                    Shadow(color: Color.fromRGBO(20, 4, 48, 0.55), offset: Offset(0, 1), blurRadius: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底栏玻璃：全息=玻璃壳；经典=直接用 NavigationBar 自己的卡片底
class GlassNavShell extends StatelessWidget {
  final Widget child;
  const GlassNavShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Pal.isHolo) return child;
    final light = Tok.isLight(appState.bg);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: light
                  ? [const Color.fromRGBO(255, 255, 255, 0.78), const Color.fromRGBO(244, 238, 252, 0.86)]
                  : [const Color.fromRGBO(26, 17, 54, 0.72), const Color.fromRGBO(10, 5, 20, 0.82)],
            ),
            border: Border(top: BorderSide(color: light ? Tok.lineSoft : Tok.glassEdge)),
          ),
          child: child,
        ),
      ),
    );
  }
}
