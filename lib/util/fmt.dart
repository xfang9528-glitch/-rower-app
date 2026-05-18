/// 全 App 统一的格式化(日期/时长/配速/距离),保证记录/详情/列表/趋势
/// 数字呈现一致(PRD §4.3 自洽要求)。
class Fmt {
  static const _week = ['一', '二', '三', '四', '五', '六', '日'];

  /// 时长 → "m:ss" 或 "h:mm:ss"。
  static String dur(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 配速秒数(每 500m)→ "m:ss";<=0 视为无 → "—"。
  static String pace(int secPer500) {
    if (secPer500 <= 0) return '—';
    final m = secPer500 ~/ 60;
    final s = secPer500 % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 距离米 → 带千分位整数(如 2,000)。
  static String dist(double m) {
    final v = m.round();
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String ymd(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// "5 月 16 日 · 周五"
  static String dayLabel(DateTime t) =>
      '${t.month} 月 ${t.day} 日 · 周${_week[t.weekday - 1]}';

  /// 与 dayLabel 同源的"M 月 D 日"(详情标题用)。
  static String mdShort(DateTime t) => '${t.month} 月 ${t.day} 日';

  /// 同一天判定(按本地日历日)。
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
