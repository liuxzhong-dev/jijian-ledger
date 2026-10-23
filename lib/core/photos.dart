// 菲票照片存储。
//
// 为什么值得单独一个文件：照片是「文件系统 + 数据库」两头的事，
// 散在页面里写，删记录时漏删/换图时漏建目录/备份后路径失效这类事
// 必然发生。三条决策都来自「哪里会坏」，不是凭空设计：
//
// 1) **选完的图必须立刻转存**。image_picker 返回的文件在缓存目录里，
//    iOS 在内存压力下会回收缓存——不立刻 saveTo 到 App 自己的目录，
//    过一会儿回来看图就是空白（安卓一般不回收，但不能赌）。
// 2) **只存文件名，不存绝对路径**。绝对路径换机恢复、备份恢复后必然
//    全部指向不存在的旧位置；文件名 + 固定目录，路径永远可推导。
// 3) **选图时就压好**（maxWidth 1600 / quality 85）。原图 3-5MB，
//    工人一天拍十几张，一个月就把手机存满；压完一张两三百 KB。
//
// 安全：photo 字段的值可能来自外部导入的备份，所以取文件时过
// `p.basename`——防 "../../" 之类的路径穿越读到别的文件。

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Photos {
  Photos._();

  static const dirName = 'feipiao';

  /// 选图参数集中在这里，页面不允许自己传——否则有人忘写 quality，
  /// 某天突然多出 3MB 的原图，查都不知从哪查。
  /// （maxWidth 是 double：API 就这么定义的，像素值）
  static const double maxWidth = 1600;
  static const int quality = 85;

  static final _picker = ImagePicker();
  static Directory? _cached;

  /// App 私有目录下的 feipiao/。卸载 App 才清，系统不会动它。
  static Future<Directory> dir() async {
    final d = _cached ??=
        Directory(p.join((await getApplicationDocumentsDirectory()).path, dirName));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// 拍/选一张，压好存好，返回**文件名**（不含目录）。取消返回空串。
  ///
  /// PlatformException（相机被占用/没有相机/拒绝权限）往上抛，
  /// 由调用方转成 toast——这里不吞。
  static Future<String> pickAndSave(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: quality,
    );
    if (picked == null) return ''; // 用户取消，不是错误
    return savePicked(picked);
  }

  /// 把选到的图转存进照片目录，返回文件名。
  static Future<String> savePicked(XFile picked) async {
    final d = await dir();
    final base = DateTime.now().millisecondsSinceEpoch.toString();
    var name = '$base.jpg';
    // 同一毫秒连拍两张才会走到这；补后缀，不覆盖旧图
    var n = 1;
    while (File(p.join(d.path, name)).existsSync()) {
      name = '$base-$n.jpg';
      n++;
    }
    await picked.saveTo(p.join(d.path, name));
    return name;
  }

  /// 取照片文件；不存在（换机/清理过/备份里只有名字）返回 null，
  /// 调用方显示「照片文件已丢失」而不是崩。
  static Future<File?> file(String name) async {
    if (name.trim().isEmpty) return null;
    final f = File(p.join((await dir()).path, p.basename(name)));
    return f.existsSync() ? f : null;
  }

  static Future<void> remove(String name) async {
    if (name.trim().isEmpty) return;
    final f = File(p.join((await dir()).path, p.basename(name)));
    if (f.existsSync()) f.deleteSync();
  }

  /// 目录总字节数（「我的」页显示"照片占了多大地方"用）
  static Future<int> totalBytes() async {
    final d = await dir();
    if (!d.existsSync()) return 0;
    var total = 0;
    for (final f in d.listSync()) {
      if (f is File) total += f.lengthSync();
    }
    return total;
  }

  /// 孤儿文件：目录里存在、但没有任何记录引用。
  /// 删记录时不删照片（防误删丢凭证），垃圾靠这个扫出来让用户确认。
  static Future<List<File>> orphans(Set<String> referenced) async {
    final d = await dir();
    if (!d.existsSync()) return const [];
    return d
        .listSync()
        .whereType<File>()
        .where((f) => !referenced.contains(p.basename(f.path)))
        .toList();
  }
}
