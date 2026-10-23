// 我的：款号速查 + 备份 + 外观。
//
// 备份放在显眼位置是刻意的：这个 App 的数据只存在这一台手机上，
// 手机丢了/换机/卸载，账就没了。所以备份不能藏在三层菜单里。
//
// 外观区的信息层次（从外到内）：
//   1. 皮肤（经典 / 全息）—— 先决定用哪套设计语言
//   2. 经典 → 明暗（跟随系统 / 浅色 / 深色）
//      全息 → 背景 × 玻璃厚度 × 按钮形态
// 为什么要这个层次：全息那套是为横向宽屏设计的，搬到手机竖屏上小字会糊；
// 所以它是"可选风格"而不是"默认风格"，两层开关也避免了调出矛盾配色。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/day.dart';
import '../core/money.dart';
import '../core/photos.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'entry_page.dart';
import 'pal.dart';
import 'theme.dart';
import 'tokens.dart';
import 'widgets.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  List<StyleSum> _styles = [];

  /// 菲票照片目录当前占用（字节）。删记录/删照片后要刷新。
  int _photoBytes = 0;

  /// 滑块拖动中的本地值。拖一次会触发几十个 onChanged，
  /// 每个都写库太重；所以拖动时只改内存里的 glassA（面板立刻变透），
  /// 松手才落库。
  double? _dragGlass;

  @override
  void initState() {
    super.initState();
    appState.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    appState.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final s = await appState.repo.allStyles();
    final bytes = await Photos.totalBytes();
    if (!mounted) return;
    setState(() {
      _styles = s;
      _photoBytes = bytes;
    });
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _copyBackup() async {
    final json = await appState.repo.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _toast('备份已复制，建议粘贴到微信「文件传输助手」存一份');
  }

  Future<void> _restoreBackup() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _toast('剪贴板里没有内容');
      return;
    }
    if (!text.startsWith('{')) {
      _toast('剪贴板里不是备份内容');
      return;
    }
    try {
      final n = await appState.repo.importJson(text);
      appState.touch();
      if (!mounted) return;
      _toast(n > 0 ? '已导入 $n 条（重复的会自动跳过）' : '没有新记录，可能已经导入过了');
    } on FormatException catch (e) {
      _toast('$e');
    } catch (e) {
      _toast('导入失败：格式不对');
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部数据？'),
        content: const Text('所有计件和加班记录都会删除，不能恢复。\n建议先复制一份备份。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Pal.danger(c)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appState.repo.clearAll();
      appState.touch();
      if (mounted) _toast('已清空');
    }
  }

  /// 清理不再被任何记录引用的菲票照片。
  ///
  /// 为什么会有孤儿：删记录/改记录时故意不删照片文件（防误删丢凭证），
  /// 文件就留在了目录里。这个入口把它们扫出来，列清楚让用户确认再删——
  /// 列清楚是重点：工人看不懂 "1729526400000.jpg"，看得懂 "10月21日 拍的照片 · 240KB"。
  Future<void> _cleanPhotos() async {
    final referenced = await appState.repo.allPhotoNames();
    final orphans = await Photos.orphans(referenced);
    if (!mounted) return;
    if (orphans.isEmpty) {
      _toast('没有多余的照片，照片和记录都对得上');
      return;
    }
    final totalBytes = orphans.fold<int>(0, (a, f) => a + f.lengthSync());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('清理 ${orphans.length} 张多余的照片？'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '这些照片已经没有对应的计件记录了（删记录时照片会保留，防误删）。'
                '共占用 ${_fmtBytes(totalBytes)}。',
                style: TextStyle(fontSize: 12.5, color: Pal.dim(c), height: 1.5),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: orphans.map((f) {
                    final m = f.statSync().modified;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${m.month}月${m.day}日 ${_two(m.hour)}:${_two(m.minute)}'
                        ' · ${_fmtBytes(f.lengthSync())}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Pal.danger(c)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final f in orphans) {
        if (f.existsSync()) f.deleteSync();
      }
      final bytes = await Photos.totalBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
      _toast('已清理，腾出 ${_fmtBytes(totalBytes)}');
    }
  }

  /// 点款号看这个款具体记了哪些扎。
  ///
  /// 为什么需要：工人月底对不上账时，问题几乎总是"某一扎漏记了"或"单价记错了"。
  /// 只看汇总（件数 + 金额）回答不了"哪一扎没记"，必须能看到逐笔明细，
  /// 再拿菲票一张张划。
  Future<void> _openStyle(StyleSum s) async {
    final records = await appState.repo.workOfStyle(s.styleNo);
    if (!mounted) return;
    final muted = Pal.dim(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.styleNo,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${s.qty} 件 · 单价 ${s.priceLabel} 元 · 共 ${yuanGrouped(s.amount)}',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                const EmptyState(title: '这个款没有记录')
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: records.map((r) {
                      final d = parseYmd(r.workDate);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            PhotoMark(r.photo.isNotEmpty),
                            Expanded(
                              child: Text('${cnDay(d)} ${weekdayCn(d)}',
                                  style: const TextStyle(fontSize: 14.5)),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (r.bundleNo.isNotEmpty) '扎 ${r.bundleNo}',
                            if (r.size.isNotEmpty) '码 ${r.size}',
                            if (r.operation.isNotEmpty) r.operation,
                            '${r.qty} 件 × ${yuanCsv(r.unitPrice)}',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        trailing: MoneyText(r.amount, size: 15, weight: FontWeight.w700),
                        onTap: () {
                          Navigator.pop(c);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EntryPage(editing: r),
                          ));
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final accent = Pal.accent(context);
    final danger = Pal.danger(context);
    final total = _styles.fold<int>(0, (a, b) => a + b.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        flexibleSpace: const GlassHeader(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SectionHeader('数据安全', trailing: '数据只在你这台手机上'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.copy_all_outlined, color: accent),
                  title: const Text('复制一份备份'),
                  subtitle: const Text('生成一段文本，粘到微信收藏或文件传输助手'),
                  onTap: _copyBackup,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: Pal.line(context)),
                ListTile(
                  leading: Icon(Icons.content_paste_go, color: accent),
                  title: const Text('从剪贴板恢复'),
                  subtitle: const Text('换手机、重装 App 后，把备份粘回来'),
                  onTap: _restoreBackup,
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: Pal.line(context)),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: danger),
                  title: Text('清空全部数据', style: TextStyle(color: danger)),
                  onTap: _clearAll,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          SectionHeader('菲票照片', trailing: '跟着计件记录一起拍'),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.photo_library_outlined, color: accent),
              title: const Text('清理不再引用的照片'),
              subtitle: Text(
                _photoBytes > 0
                    ? '当前占用 ${_fmtBytes(_photoBytes)}。删记录时照片会留着防误删，对不上账的从这里清。'
                    : '还没有拍过菲票照片',
              ),
              onTap: _cleanPhotos,
            ),
          ),

          const SizedBox(height: 22),
          SectionHeader('款号速查', trailing: _styles.isEmpty ? null : '点款号看明细'),
          if (_styles.isEmpty)
            const EmptyState(
              title: '还没有款号',
              subtitle: '记满几笔之后，这里能查每个款的单价',
              icon: Icons.style_outlined,
            )
          else
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < _styles.length; i++) ...[
                    InkWell(
                      onTap: () => _openStyle(_styles[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(_styles[i].styleNo,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Pal.hi(context),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.chevron_right,
                                          size: 16, color: Pal.dim(context)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_styles[i].qty} 件 · 单价 ${_styles[i].priceLabel} 元',
                                    style: TextStyle(
                                        fontSize: 12.5, color: Pal.dim(context)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            MoneyText(_styles[i].amount,
                                size: 16, weight: FontWeight.w700),
                          ],
                        ),
                      ),
                    ),
                    if (i != _styles.length - 1)
                      Divider(height: 1, indent: 14, endIndent: 14,
                          color: Pal.line(context)),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 22),
          SectionHeader('外观', trailing: '立刻生效'),
          Panel(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('皮肤'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final s in Skin.values) ...[
                      Expanded(
                        child: _SkinSwatch(
                          skin: s,
                          selected: appState.skin == s,
                          onTap: () => appState.setSkin(s),
                        ),
                      ),
                      if (s != Skin.values.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  appState.skin == Skin.classic
                      ? '经典：白底卡片，字最清楚，适合在车间强光下看。'
                      : '全息：渐变底 + 玻璃卡片 + 宝石按钮，好看但小字对比度低一些。',
                  style: TextStyle(fontSize: 11.5, color: muted, height: 1.5),
                ),

                // 经典皮肤：明暗跟随系统
                if (!Pal.isHolo) ...[
                  const SizedBox(height: 20),
                  const _Label('明暗'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in ThemeMode.values)
                        GlassChip(
                          label: _modeName(m),
                          icon: switch (m) {
                            ThemeMode.system => Icons.brightness_auto_outlined,
                            ThemeMode.light => Icons.light_mode_outlined,
                            ThemeMode.dark => Icons.dark_mode_outlined,
                          },
                          selected: appState.classicMode == m,
                          onTap: () => appState.setClassicMode(m),
                        ),
                    ],
                  ),
                ],

                // 全息皮肤：三参数
                if (Pal.isHolo) ...[
                  const SizedBox(height: 20),
                  const _Label('背景'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final t in BgTheme.values) ...[
                        Expanded(
                          child: _BgSwatch(
                            theme: t,
                            selected: appState.bg == t,
                            onTap: () => appState.setBg(t),
                          ),
                        ),
                        if (t != BgTheme.values.last) const SizedBox(width: 10),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const _Label('玻璃厚度'),
                      const Spacer(),
                      Text(
                        '${((_dragGlass ?? appState.glassA) * 100).round()}%',
                        style: TextStyle(
                            fontSize: 12.5, color: accent, fontFeatures: tabularFigures),
                      ),
                    ],
                  ),
                  Slider(
                    value: _dragGlass ?? appState.glassA,
                    min: 0.6,
                    max: 1,
                    divisions: 8,
                    onChanged: (v) {
                      // 只改内存：面板重绘立刻变透，不写库
                      appState.glassA = v;
                      setState(() => _dragGlass = v);
                    },
                    onChangeEnd: (v) {
                      setState(() => _dragGlass = null);
                      appState.setGlass(v);
                    },
                  ),
                  Text(
                    '往左更透、看得见背景的紫；往右更厚、字更清楚。'
                    '白天站在窗边建议往右，晚上往左。',
                    style: TextStyle(fontSize: 11.5, color: muted, height: 1.5),
                  ),

                  const SizedBox(height: 18),
                  const _Label('按钮形态'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in BtnStyle.values)
                        GlassChip(
                          label: _btnName(s),
                          selected: appState.btn == s,
                          onTap: () => appState.setBtn(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 给一个实物样例：四套形态光看名字分不出差别
                  GemButton(
                    label: '样例按钮',
                    icon: Icons.touch_app_outlined,
                    height: 46,
                    onPressed: () {},
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('计件本 v1.4.0',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Pal.hi(context))),
                const SizedBox(height: 6),
                Text(
                  '纯离线记账本：不联网、不要账号、不上传任何数据。\n'
                  '金额一律按「分」存整数，所以不会出现月底差一两分钱的情况。\n'
                  '数据只在本机，请定期「复制一份备份」存到微信里。',
                  style: TextStyle(fontSize: 12.5, color: muted, height: 1.65),
                ),
                if (total != 0) ...[
                  const SizedBox(height: 8),
                  Text('累计收入 ${yuanGrouped(total)}',
                      style: TextStyle(fontSize: 12.5, color: muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtBytes(int b) => b >= 1024 * 1024
    ? '${(b / 1024 / 1024).toStringAsFixed(1)} MB'
    : '${(b / 1024).round()} KB';

String _two(int n) => n.toString().padLeft(2, '0');

String _modeName(ThemeMode m) => switch (m) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };

String _btnName(BtnStyle s) => switch (s) {
      BtnStyle.gem => '宝石',
      BtnStyle.glass => '玻璃',
      BtnStyle.ghost => '描边',
      BtnStyle.pill => '胶囊',
    };

String _bgName(BgTheme t) => switch (t) {
      BgTheme.twilight => '暮光紫',
      BgTheme.ink => '墨黑',
      BgTheme.paper => '纸白',
    };

String _skinName(Skin s) => switch (s) {
      Skin.classic => '经典',
      Skin.holo => '全息',
    };

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12 * 11.5,
        color: Pal.dim(context),
      ),
    );
  }
}

/// 皮肤选项：直接画那套皮肤的真实观感，选的是"看得到的颜色"而不是名字
class _SkinSwatch extends StatelessWidget {
  final Skin skin;
  final bool selected;
  final VoidCallback onTap;

  const _SkinSwatch({required this.skin, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Pal.accent(context);
    final holo = skin == Skin.holo;

    // 缩略预览：经典=白卡+青绿条；全息=紫渐变+玻璃块
    final preview = DecoratedBox(
      decoration: BoxDecoration(
        gradient: holo
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Tok.bgAbyss, Tok.bgMid, Tok.bgWarm],
              )
            : null,
        color: holo ? null : Ck.lightBg,
        borderRadius: BorderRadius.circular(Ck.radius - 4),
        border: Border.all(color: selected ? accent : Pal.line(context), width: selected ? 1.6 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 两条"文字"，一粗一细，模拟真实信息密度
            Container(
              height: 7,
              decoration: BoxDecoration(
                color: holo ? Tok.crystalHi : Ck.lightTxHi,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            FractionallySizedBox(
              widthFactor: 0.62,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: (holo ? Tok.txMid : Ck.lightTxDim).withAlpha(180),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              decoration: BoxDecoration(
                gradient: holo ? Tok.gemGradient : null,
                color: holo ? null : Ck.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(height: 62, child: preview),
          const SizedBox(height: 5),
          Text(
            _skinName(skin),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Pal.hi(context) : Pal.dim(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景选项：直接画那套渐变本身，选的是"看得到的颜色"而不是名字
class _BgSwatch extends StatelessWidget {
  final BgTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _BgSwatch({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final spec = BgSpec.of(theme);
    final accent = Pal.accent(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: spec.stops,
                stops: spec.positions,
              ),
              borderRadius: BorderRadius.circular(Tok.radiusSoft + 2),
              border: Border.all(
                color: selected ? accent : Tok.line,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: accent.withAlpha(60), blurRadius: 14, spreadRadius: -3)]
                  : null,
            ),
            child: selected
                ? Center(
                    child: Icon(Icons.check_circle_rounded,
                        size: 20,
                        color: spec.dark ? Tok.crystalHi : Tok.accentDeep),
                  )
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            _bgName(theme),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Pal.hi(context) : Pal.dim(context),
            ),
          ),
        ],
      ),
    );
  }
}