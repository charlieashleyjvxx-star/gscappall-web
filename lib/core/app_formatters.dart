class AppFormatters {
  const AppFormatters._();

  static String dateKey(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String shortDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  static String minutesLabel(int minutes) {
    if (minutes <= 0) {
      return '未记录';
    }
    if (minutes < 60) {
      return '$minutes 分钟';
    }
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    if (remain == 0) {
      return '$hours 小时';
    }
    return '$hours 小时 $remain 分钟';
  }
}
