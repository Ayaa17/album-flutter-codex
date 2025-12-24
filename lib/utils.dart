class Utils {
  static String twoDigits(int value) => value.toString().padLeft(2, '0');

  static String formatActivityName(String template) {
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${twoDigits(now.month)}-${twoDigits(now.day)}';
    return template.replaceAll('{date}', formattedDate);
  }
}
