// 加班记录页：一天可能加几个小时，按「时间 × 单价」自动算钱。
//
// 行业的实际习惯是 0.5 小时为单位（1.5h、2h、2.5h），所以上面给了一排
// 常用时长按钮，点一下就能填好，不用切输入法打小数点。

import 'package:flutter/material.dart';

import '../core/day.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'pal.dart';
import 'widgets.dart';

class OvertimePage extends StatefulWidget {
  final OvertimeRecord? editing;
  final DateTime? initialDate;

  const OvertimePage({super.key, this.editing, this.initialDate});

  @override
  State<OvertimePage> createState() => _OvertimePageState();
}

class _OvertimePageState extends State<OvertimePage> {
  static const _quickHours = ['1', '1.5', '2', '2.5', '3', '3.5', '4'];
  final _hours = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  bool _priceTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _date = e != null ? parseYmd(e.workDate) : (widget.initialDate ?? DateTime.now());
    if (e != null) {
      _hours.text = hoursText(e.minutes);
      _price.text = yuanCsv(e.hourPrice);
      _note.text = e.note;
      _priceTouched = true;
    } else {
      _loadLastPrice();
    }
    _hours.addListener(_onChanged);
    _price.addListener(_onChanged);
  }

  Future<void> _loadLastPrice() async {
    final last = await appState.repo.lastOvertimePrice();
    if (!mounted || last == null || _priceTouched) return;
    setState(() => _price.text = yuanCsv(last));
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hours.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _minutes => parseHoursToMinutes(_hours.text) ?? 0;
  int get _priceValue => parseYuanToCents(_price.text) ?? 0;
  int get _amount => (_minutes * _priceValue + 30) ~/ 60;

  Future<void> _save() async {
    if (_minutes <= 0) {
      _toast('请填加班小时数');
      return;
    }
    if (_priceValue <= 0) {
      _toast('请填加班单价（元/小时）');
      return;
    }
    final r = OvertimeRecord(
      id: widget.editing?.id,
      workDate: ymd(_date),
      minutes: _minutes,
      hourPrice: _priceValue,
      note: _note.text.trim(),
      createdAt: widget.editing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    if (widget.editing != null) {
      await appState.repo.updateOvertime(r);
    } else {
      await appState.repo.addOvertime(r);
    }
    appState.touch();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条加班记录？'),
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
      await appState.repo.deleteOvertime(widget.editing!.id!);
      appState.touch();
      if (mounted) Navigator.of(context).pop(true);
    }
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
    if (picked != null) setState(() => _date = picked);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final muted = Pal.dim(context);
    final isEdit = widget.editing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '修改加班' : '记加班'),
        flexibleSpace: const GlassHeader(),
        actions: [
          if (isEdit) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GlassChip(
              icon: Icons.event,
              label: '${cnDay(_date)} ${weekdayCn(_date)}',
              onTap: _pickDate,
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: BigField(
                    controller: _hours,
                    label: '加班时间',
                    hint: '0.5',
                    unit: '小时',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 5,
                    autofocus: !isEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: BigField(
                    controller: _price,
                    label: '加班单价',
                    hint: '0.00',
                    unit: '元/时',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    maxLength: 8,
                    onChanged: (_) => _priceTouched = true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickHours.map((h) {
                // 选中态跟着输入框的值走：手打 1.5 也会点亮对应那颗
                return GlassChip(
                  label: '$h 小时',
                  selected: _hours.text.trim() == h,
                  onTap: () => setState(() => _hours.text = h),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            BigField(controller: _note, label: '备注', hint: '可不填', maxLength: 60),
            const SizedBox(height: 20),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Text('这一笔',
                      style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  Text(
                    _minutes > 0 && _priceValue > 0
                        ? '${hoursText(_minutes)} 小时 × ${yuanCsv(_priceValue)}'
                        : '填时间和单价',
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
