// 通用小部件。所有取色都走 Pal，不再直接读全局背景——
// v1.1「看不清字」的根因就是各处直接读 Tok.xxxOf(appState.bg)。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../state/app_state.dart';
import 'glass.dart';
import 'pal.dart';
import 'theme.dart';
import 'tokens.dart';

// 页面统一只 import 这一个文件就够：玻璃组件从这里透出
export 'glass.dart';

/// 面板：经典皮肤=实色卡片，全息皮肤=玻璃。
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color; // 需要指定底色时才传（嵌在弹窗里用）
  final VoidCallback? onTap;
  final double radius;
  final bool glow;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.radius = Tok.radiusLiquid,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!Pal.isHolo) {
      // 经典：白卡 + 1px 线，圆角 16（v1.0 的样子）。
      // ⚠ 卡片底色必须画在 Material 上，不能用 Container(BoxDecoration)：
      //   ListTile / InkWell 把水波纹画在最近的 Material 祖先上，
      //   中间夹一层有底色的 DecoratedBox 就会抛
      //   "ListTile background color or ink splashes may be invisible"。
      final r = BorderRadius.circular(Ck.radius);
      return Material(
        color: color ?? Theme.of(context).cardColor,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: Pal.line(context)),
          ),
          child: Padding(
            padding: padding,
            child: onTap == null
                ? child
                : InkWell(
                    onTap: onTap,
                    borderRadius: r,
                    child: child,
                  ),
          ),
        ),
      );
    }

    if (color != null) {
      // 全息里指定了底色 = 不想叠玻璃（弹窗内用）
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Tok.glassEdge),
        ),
        child: child,
      );
    }
    return GlassPanel(
      padding: padding,
      onTap: onTap,
      radius: radius,
      glow: glow,
      child: child,
    );
  }
}

/// 四角 HUD 角标：全息皮肤的标志性装饰（经典皮肤不要，太花）
class HudCorners extends StatelessWidget {
  final Widget child;
  final Color? color;
  const HudCorners({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    if (!Pal.isHolo) return child;
    final c = (color ?? Tok.accentOf(appState.bg)).withAlpha(120);
    Widget corner({required bool left, required bool top}) => Positioned(
          left: left ? 8 : null,
          right: left ? null : 8,
          top: top ? 8 : null,
          bottom: top ? null : 8,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              border: Border(
                left: left ? BorderSide(color: c) : BorderSide.none,
                right: left ? BorderSide.none : BorderSide(color: c),
                top: top ? BorderSide(color: c) : BorderSide.none,
                bottom: top ? BorderSide.none : BorderSide(color: c),
              ),
            ),
          ),
        );
    return Stack(children: [
      child,
      corner(left: true, top: true),
      corner(left: false, top: true),
      corner(left: true, top: false),
      corner(left: false, top: false),
    ]);
  }
}

/// 金额显示：等宽数字，避免列表里抖动
class MoneyText extends StatelessWidget {
  final int cents;
  final double size;
  final FontWeight weight;
  final Color? color;
  final bool withSymbol;
  final bool accent; // 正向数值

  const MoneyText(
    this.cents, {
    super.key,
    this.size = 16,
    this.weight = FontWeight.w600,
    this.color,
    this.withSymbol = true,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = withSymbol ? yuanGrouped(cents) : yuanPlain(cents);
    final c = color ?? (accent ? Pal.money(context) : Pal.hi(context));
    // 发光只在全息深色底上用：经典皮肤的光晕会把数字糊掉
    final glow = accent && Pal.isHolo && !Tok.isLight(appState.bg)
        ? [Shadow(color: Tok.accentMint.withAlpha(70), blurRadius: 12)]
        : null;
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: c,
        fontFeatures: tabularFigures,
        letterSpacing: -0.4,
        shadows: glow,
      ),
    );
  }
}

/// 小标签
class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const Pill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Pal.accent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(Pal.isHolo ? 26 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withAlpha(Pal.isHolo ? 60 : 46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }
}

/// 区块标题：宽字距小字 + 左侧色条
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionHeader(this.title, {super.key, this.trailing, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Pal.accent(context).withAlpha(190),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: Pal.isHolo ? 1.75 : 0.9,
                color: Pal.dim(context),
              )),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(trailing!,
                  style: TextStyle(fontSize: 12.5, color: Pal.accent(context))),
            ),
        ],
      ),
    );
  }
}

/// 大号输入框
/// 经典皮肤：白底一条输入格（1px 线 → 聚焦时主色描边）
/// 全息皮肤：内槽（上暗下亮=凹进去），聚焦时描边发光
class BigField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? unit;
  final String? helper;
  final bool helperWarn;
  final TextInputType keyboard;
  final bool autofocus;
  final int maxLength;
  final ValueChanged<String>? onChanged;
  final TextInputAction action;
  final VoidCallback? onSubmitted;
  final bool enabled;

  const BigField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.unit,
    this.helper,
    this.helperWarn = false,
    this.keyboard = TextInputType.text,
    this.autofocus = false,
    this.maxLength = 40,
    this.onChanged,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<BigField> createState() => _BigFieldState();
}

class _BigFieldState extends State<BigField> {
  late final FocusNode _node = FocusNode()..addListener(_onFocus);
  bool _focused = false;

  void _onFocus() {
    if (mounted && _focused != _node.hasFocus) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holo = Pal.isHolo;
    final light = !Pal.isDark(context);
    final accent = Pal.accent(context);
    final isNum = widget.keyboard == TextInputType.number;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.12 * 11.5,
            // 标签压在页面底色上（不在面板里），必须用次级以上的颜色
            color: Pal.mid(context),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          decoration: BoxDecoration(
            gradient: holo
                ? (light
                    ? const LinearGradient(colors: [
                        Color.fromRGBO(255, 255, 255, 0.62),
                        Color.fromRGBO(255, 255, 255, 0.94),
                      ])
                    : Tok.slotFill)
                : null,
            color: holo ? null : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(holo ? Tok.radiusSoft : 12),
            border: Border.all(
              color: _focused
                  ? accent.withAlpha(220)
                  : (holo ? const Color.fromRGBO(217, 194, 240, 0.16) : Pal.line(context)),
              width: _focused ? 1.6 : 1,
            ),
            boxShadow: _focused && holo
                ? [BoxShadow(color: accent.withAlpha(56), blurRadius: 16, spreadRadius: -2)]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _node,
                  keyboardType: widget.keyboard,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  textInputAction: widget.action,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
                  cursorColor: accent,
                  style: TextStyle(
                    fontSize: isNum ? 24 : 19,
                    fontWeight: isNum ? FontWeight.w600 : FontWeight.w500,
                    color: Pal.hi(context),
                    fontFeatures: isNum ? tabularFigures : null,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      fontSize: 15,
                      // 提示文字要能看见，但明显弱于输入值
                      color: Pal.dim(context).withAlpha(holo ? 210 : 255),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                ),
              ),
              if (widget.unit != null)
                Text(widget.unit!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Pal.dim(context),
                      fontWeight: FontWeight.w500,
                    )),
            ],
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Row(
              children: [
                if (widget.helperWarn) ...[
                  Icon(Icons.warning_amber_rounded, size: 13, color: Pal.spark(context)),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    widget.helper!,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.helperWarn ? Pal.spark(context) : Pal.dim(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 空状态
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.receipt_long_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(icon, size: 36, color: muted.withAlpha(170)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w500)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: muted)),
          ],
        ],
      ),
    );
  }
}

/// 「这条记录拍了菲票」的小标记。
///
/// 首页今日列表、月账按天弹窗、款号明细弹窗三处共用——同一个图标同一个
/// 颜色，工人看到就懂"这笔有票"。只表示"拍过"，不表示文件一定还在
/// （换机/清理后文件可能丢），点进去会看到相应的丢失提示。
class PhotoMark extends StatelessWidget {
  final bool hasPhoto;
  const PhotoMark(this.hasPhoto, {super.key});

  @override
  Widget build(BuildContext context) => hasPhoto
      ? Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(Icons.photo_camera_outlined, size: 13, color: Pal.dim(context)),
        )
      : const SizedBox.shrink();
}
