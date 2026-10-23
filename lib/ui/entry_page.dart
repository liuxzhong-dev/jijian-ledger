// 记一笔：整个 App 最关键的页面。
//
// 设计目标只有一个：让熟练工在 3 秒内记完一扎。
// 为此做了三件事：
// 1) 只让用户填「原始字段」——本款收入、总收入、本月总收入都由程序算，
//    用户永远不需要心算（截图里那四行手算出错率最高）。
// 2) 单价记忆：输入款号后自动带出上次单价，只改件数就能保存。
// 3) 保存即返回主页。**连续录入不靠"留在页面上"**，而是靠主页那颗
//    「再记一扎」浮标：它带着上一扎的款号/单价/码进来，只需要填扎号和件数。
//
// 为什么不再给「保存并继续」和「记完返回」两颗按钮：
// 两颗都写库、差别只在跳不跳页，而名字都像"完成"——用户根本猜不出区别，
// 实际用起来是"记完一扎发现没别的要记，还得再点一下返回"。
// 一颗按钮，名字和结果对齐（保存 = 存好并回去），另一条路交给系统返回手势。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/day.dart';
import '../core/money.dart';
import '../core/photos.dart';
import '../core/sizes.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'photo_view_page.dart';
import 'theme.dart';
import 'pal.dart';
import 'widgets.dart';

class EntryPage extends StatefulWidget {
  /// 传入记录 = 编辑模式；不传 = 新增
  final WorkRecord? editing;
  final DateTime? initialDate;

  /// 「再记一扎」用的预填：只带款号/单价/码，不带扎号和件数
  final WorkRecord? prefill;

  const EntryPage({super.key, this.editing, this.initialDate, this.prefill});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _style = TextEditingController();
  final _bundle = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _operation = TextEditingController();
  final _note = TextEditingController();
  final _customSize = TextEditingController();
  final _qtyFocus = FocusNode();
  final _bundleFocus = FocusNode();

  late DateTime _date;
  String _size = '';
  /// 菲票照片文件名（不含目录）；空 = 没拍。
  /// 只在「编辑既有记录」时带入——「再记一扎」**不沿用**上一扎的照片，
  /// 因为每一扎的菲票都不一样，沿用就是张冠李戴。
  String _photo = '';
  bool _priceTouched = false; // 用户手改过单价后，不再自动覆盖
  bool _showMore = false;
  bool _showAllSizes = false; // 展开大码 / 数字码
  int? _lastPrice; // 该款号上次单价
  int _bundleDupQty = 0; // 同扎号今日已记件数

  int _bundleCheckToken = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _date = e != null ? parseYmd(e.workDate) : (widget.initialDate ?? DateTime.now());
    if (e != null) {
      _style.text = e.styleNo;
      _bundle.text = e.bundleNo;
      _size = e.size;
      _photo = e.photo;
      _qty.text = e.qty.toString();
      _price.text = yuanCsv(e.unitPrice);
      _operation.text = e.operation;
      _note.text = e.note;
      _priceTouched = true;
      _showMore = e.operation.isNotEmpty || e.note.isNotEmpty;
    } else if (widget.prefill != null) {
      // 「再记一扎」：款号/单价/码沿用上一扎，扎号和件数留空
      final p = widget.prefill!;
      _style.text = p.styleNo;
      _size = p.size;
      _price.text = yuanCsv(p.unitPrice);
      _priceTouched = true;
    }
    _qty.addListener(_onFormChanged);
    _price.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _style.dispose();
    _bundle.dispose();
    _qty.dispose();
    _price.dispose();
    _operation.dispose();
    _note.dispose();
    _customSize.dispose();
    _qtyFocus.dispose();
    _bundleFocus.dispose();
    super.dispose();
  }

  int get _qtyValue => int.tryParse(_qty.text.trim()) ?? 0;
  int get _priceValue => parseYuanToCents(_price.text) ?? 0;
  int get _amount => _qtyValue * _priceValue;

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onStyleChanged(String v) async {
    _priceTouched = false;
    final last = await appState.repo.lastPriceOfStyle(v);
    if (!mounted) return;
    setState(() {
      _lastPrice = last;
      if (last != null && !_priceTouched && _price.text.trim().isEmpty) {
        _price.text = yuanCsv(last);
      }
    });
  }

  Future<void> _onBundleChanged(String v) async {
    final token = ++_bundleCheckToken;
    if (v.trim().isEmpty) {
      setState(() => _bundleDupQty = 0);
      return;
    }
    final q = await appState.repo.qtyOfBundleOnDay(ymd(_date), v);
    // 丢掉过期结果：用户快速输入时，后发的查询可能先返回
    if (!mounted || token != _bundleCheckToken) return;
    setState(() => _bundleDupQty = q);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) {
      setState(() => _date = picked);
      _onBundleChanged(_bundle.text);
    }
  }

  /// 当前应该显示哪些码。
  ///
  /// 顺序 = 记忆的自定义码 → 常用 →（展开了才显示）更多。
  /// 另外兜一个底：老数据里的码（比如 v1.0 记的 "7XL" 或手填的特殊写法）
  /// 不在任何内置列表里，也必须出现在选项里并选中，否则用户一编辑就丢了。
  List<String> _sizeOptions() {
    final out = <String>[];
    void add(String s) {
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }

    for (final s in appState.customSizes) {
      add(s);
    }
    for (final s in Sizes.common) {
      add(s);
    }
    if (_showAllSizes) {
      for (final s in Sizes.more) {
        add(s);
      }
    }
    add(_size); // 老数据 / 当前值兜底
    return out;
  }

  /// 自定义码：厂里菲票上印什么就填什么。
  /// 上限 8 个字符（菲票上偶尔有 "XXXL(180)" 这种写法）。
  Future<void> _pickCustomSize() async {
    _customSize.clear();
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('自定义码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '菲票上印的码是什么就填什么，比如 7XL、3XL、170/88A。\n'
              '填过的码会记住，下次直接点。',
              style: TextStyle(fontSize: 12.5, color: Pal.dim(c), height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customSize,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: Sizes.maxLen,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '例如 7XL',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(c, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(c, _customSize.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    final s = picked?.trim() ?? '';
    if (s.isEmpty) return;
    // 和内置码撞车就直接选中，不占记忆位
    if (Sizes.builtin.contains(s)) {
      setState(() => _size = s);
      return;
    }
    await appState.addCustomSize(s);
    if (!mounted) return;
    setState(() {
      _size = s;
      _showAllSizes = true; // 让它立刻可见
    });
  }

  // ---------------- 菲票照片 ----------------

  /// 拍/选菲票。弹底部选择（当场拍 / 从相册补选）——
  /// 有的工人习惯下班前把白天拍的票一起补录，相册入口是给他们留的。
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final name = await Photos.pickAndSave(source);
      if (name.isEmpty || !mounted) return;
      setState(() => _photo = name);
    } on PlatformException catch (e) {
      if (!mounted) return;
      // 相机被占用/没有相机/拒绝权限——说人话，不把异常码甩给工人
      final denied = e.code == 'camera_access_denied' || e.code == 'photo_access_denied';
      _toast(denied ? '没有相机/相册权限，去系统设置里打开' : '拍照没成功，再试一次');
    }
  }

  /// 看大图（能缩放——工人拍菲票就是为了看清手写数字）
  void _openPhoto() {
    if (_photo.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PhotoViewPage(photoName: _photo),
    ));
  }

  /// 删照片走确认：菲票原件拍花了，这张图就是唯一凭证，
  /// 误触一下没了，工人得去翻垃圾桶。和删记录同一个安全等级。
  Future<void> _removePhoto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删掉这张菲票照片？'),
        content: const Text('删除后不可恢复。这条记录会保留，只是以后看不到这张票。'),
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
    if (ok != true) return;
    final name = _photo;
    setState(() => _photo = '');
    await Photos.remove(name);
  }

  /// 菲票照片区。
  ///
  /// 放在款号/扎号后面：工人记账时就捏着菲票，顺手拍是三秒的事；
  /// 放到详情页让"事后补拍"才是负担。打印的票拍清楚能照着填，
  /// 手写的票拍下来，月底对不上账时至少有据可查。
  Widget _photoArea() {
    final dim = Pal.dim(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('菲票',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w500, color: dim)),
            const SizedBox(width: 8),
            Text('拍一张存底，对账时看得见',
                style: TextStyle(fontSize: 11.5, color: dim)),
          ],
        ),
        const SizedBox(height: 8),
        if (_photo.isEmpty)
          _photoButton(
            icon: Icons.photo_camera_outlined,
            label: '拍菲票',
            onTap: _pickPhoto,
            fullWidth: true,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图：点一下看大图
              GestureDetector(
                onTap: _openPhoto,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: FutureBuilder<File?>(
                      future: Photos.file(_photo),
                      builder: (ctx, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return Container(color: Pal.line(ctx));
                        }
                        final f = snap.data;
                        if (f == null) {
                          // 文件名在、文件不在（换机/清理过/只有备份里的名字）
                          return Container(
                            color: Pal.line(ctx),
                            child: Icon(Icons.image_not_supported_outlined,
                                color: Pal.dim(ctx)),
                          );
                        }
                        return Image.file(
                          f,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Pal.line(ctx),
                            child: Icon(Icons.broken_image_outlined,
                                color: Pal.dim(ctx)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _photoButton(
                      icon: Icons.camera_alt_outlined,
                      label: '换一张',
                      onTap: _pickPhoto,
                    ),
                    const SizedBox(height: 8),
                    _photoButton(
                      icon: Icons.delete_outline,
                      label: '删掉照片',
                      onTap: _removePhoto,
                      danger: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 照片区的小按钮。和「更多码 / 自定义」那两颗文字按钮同一视觉语言
  /// （都是次级操作：描边 + 主题色，不抢主按钮）。
  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool fullWidth = false,
    bool danger = false,
  }) {
    final color = danger ? Pal.danger(context) : Pal.accent(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final style = _style.text.trim();
    if (style.isEmpty) {
      _toast('请先填款号');
      return;
    }
    if (_qtyValue <= 0) {
      _toast('件数要大于 0');
      _qtyFocus.requestFocus();
      return;
    }
    if (_qtyValue > 999) {
      _toast('一件扎一般不会超过 999 件，请检查');
      return;
    }
    if (_priceValue <= 0) {
      _toast('单价要大于 0');
      return;
    }

    final record = WorkRecord(
      id: widget.editing?.id,
      workDate: ymd(_date),
      styleNo: style,
      bundleNo: _bundle.text.trim(),
      size: _size,
      operation: _operation.text.trim(),
      note: _note.text.trim(),
      qty: _qtyValue,
      unitPrice: _priceValue,
      createdAt: widget.editing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      photo: _photo,
    );

    // 先抓住 messenger：pop 之后这个页面的 context 就失效了。
    // ScaffoldMessenger 是 App 级的，所以提示会跟着落到返回后的主页上。
    final messenger = ScaffoldMessenger.of(context);

    if (widget.editing != null) {
      await appState.repo.updateWork(record);
      appState.touch();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('已修改'),
          duration: Duration(milliseconds: 1400),
        ));
      Navigator.of(context).pop(true);
      return;
    }

    await appState.repo.addWork(record);
    appState.touch();

    // 多查一次今日合计：保存完就回主页了，把结果直接写进提示里，
    // 用户不用自己回去看一眼才知道今天累计多少。
    final dayTotal = await appState.repo.dayTotal(ymd(_date));
    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '已记 ${record.qty} 件 ${yuanGrouped(record.amount)} · 今日 ${yuanGrouped(dayTotal.total)}',
        ),
        duration: const Duration(milliseconds: 1800),
      ));
    Navigator.of(context).pop(true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1600)));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后不可恢复（有备份的话可以恢复）。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Pal.danger(context)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && widget.editing?.id != null) {
      await appState.repo.deleteWork(widget.editing!.id!);
      appState.touch();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final isEdit = widget.editing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '修改记录' : '记一笔'),
        flexibleSpace: const GlassHeader(),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // 日期 + 本次累计
            Row(
              children: [
                GlassChip(
                  icon: Icons.event,
                  label: '${cnDay(_date)} ${weekdayCn(_date)}',
                  onTap: _pickDate,
                ),
                const Spacer(),
                if (widget.prefill != null)
                  Text('沿用上一扎的款号/单价',
                      style: TextStyle(fontSize: 11.5, color: muted)),
              ],
            ),
            const SizedBox(height: 16),

            BigField(
              controller: _style,
              label: '款号',
              hint: '例如 A1234（字母/数字/符号）',
              // 预填了款号就直接从扎号开始填，少一次点按
              autofocus: !isEdit && widget.prefill == null,
              maxLength: 30,
              onChanged: _onStyleChanged,
              onSubmitted: () => _bundleFocus.requestFocus(),
            ),
            const SizedBox(height: 14),

            BigField(
              controller: _bundle,
              label: '扎号',
              hint: '菲票上的数字',
              autofocus: !isEdit && widget.prefill != null,
              keyboard: TextInputType.number,
              maxLength: 12,
              onChanged: _onBundleChanged,
              onSubmitted: () => _qtyFocus.requestFocus(),
              helper: _bundleDupQty > 0
                  ? '注意：这一扎今天已经记过 $_bundleDupQty 件，别重复计'
                  : null,
              helperWarn: _bundleDupQty > 0,
            ),
            const SizedBox(height: 14),

            // 菲票照片：拍一张存底。见 _photoArea 的注释。
            _photoArea(),
            const SizedBox(height: 14),

            // 码。
            // 为什么是三块而不是一长串：内销厂常用码就 6 个，一屏全展开反而更难找；
            // 外贸大码（XXXL 到 12XL）和童装数字码（90~170）平时用不到，收在「更多」里。
            // 兜底是「自定义」——厂里菲票上怎么印就怎么填，填过的会记住，下次直接点。
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('码',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500, color: muted)),
                    const Spacer(),
                    // 展开/收起大码
                    GestureDetector(
                      onTap: () => setState(() => _showAllSizes = !_showAllSizes),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                                _showAllSizes ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                                color: Pal.accent(context)),
                            const SizedBox(width: 2),
                            Text(_showAllSizes ? '收起' : '更多码',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Pal.accent(context))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 自定义码
                    GestureDetector(
                      onTap: _pickCustomSize,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 15, color: Pal.accent(context)),
                            const SizedBox(width: 2),
                            Text('自定义',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Pal.accent(context))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sizeOptions().map((s) {
                    final on = _size == s;
                    // 记住的自定义码带删除按钮；其他码点一下就选中
                    final remembered = appState.customSizes.contains(s);
                    return GlassChip(
                      label: s,
                      icon: remembered ? Icons.bookmark : null,
                      selected: on,
                      trailing: remembered
                          ? GestureDetector(
                              onTap: () => appState.removeCustomSize(s),
                              child: Icon(Icons.close,
                                  size: 13, color: Pal.dim(context)),
                            )
                          : null,
                      onTap: () => setState(() => _size = on ? '' : s),
                    );
                  }).toList(),
                ),
                // 自定义码输入中：底部已由弹窗处理
              ],
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BigField(
                    controller: _qty,
                    label: '件数',
                    hint: '1-999',
                    unit: '件',
                    keyboard: TextInputType.number,
                    maxLength: 3,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: () => FocusScope.of(context).unfocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BigField(
                    controller: _price,
                    label: '单价',
                    hint: '0.00',
                    unit: '元',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 9,
                    onChanged: (_) {
                      _priceTouched = true;
                      setState(() {});
                    },
                    helper: _lastPrice != null ? '上次 ${yuanCsv(_lastPrice!)} 元' : null,
                  ),
                ),
              ],
            ),

            // 更多：工序、备注。默认收起，因为九成记录用不上
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showMore = !_showMore),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_showMore ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: muted),
                    const SizedBox(width: 4),
                    Text('工序 / 备注（可不填）',
                        style: TextStyle(fontSize: 13, color: muted)),
                  ],
                ),
              ),
            ),
            if (_showMore) ...[
              const SizedBox(height: 8),
              BigField(
                controller: _operation,
                label: '工序',
                hint: '例如 上袖 / 锁边 / 整件',
                maxLength: 20,
              ),
              const SizedBox(height: 14),
              BigField(
                controller: _note,
                label: '备注',
                hint: '例如 返工、补件',
                maxLength: 60,
              ),
            ],

            const SizedBox(height: 20),

            // 实时小计：这是把用户从手算里解放出来的那一步
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Text('这一笔',
                      style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  Text(
                    _qtyValue > 0 && _priceValue > 0 ? '$_qtyValue × ${yuanCsv(_priceValue)}' : '填件数和单价',
                    style: TextStyle(fontSize: 13, color: muted, fontFeatures: tabularFigures),
                  ),
                  const Spacer(),
                  MoneyText(_amount,
                      size: 26,
                      weight: FontWeight.w700,
                      accent: _amount > 0,
                      color: _amount > 0 ? null : muted),
                ],
              ),
            ),
          ],
        ),
      ),
      // 一颗按钮：保存 = 存好并返回主页。
      // 想连记下一扎，回主页点「再记一扎」就行——款号/单价都带着，
      // 只需要填扎号和件数，比留在页面上还少一步"确认要记哪一款"。
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GemButton(
          label: isEdit ? '保存修改' : '保存',
          icon: isEdit ? Icons.check : Icons.done,
          onPressed: _save,
        ),
      ),
    );
  }
}
