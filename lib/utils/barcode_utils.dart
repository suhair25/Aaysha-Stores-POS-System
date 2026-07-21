class BarcodeUtils {
  static String? normalizeScannedBarcode(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final candidates = RegExp(
      r'\d+',
    ).allMatches(trimmed).map((match) => match.group(0)!).toList();
    final valid = candidates
        .where((candidate) => candidate.length >= 8 && candidate.length <= 13)
        .toList();
    if (valid.isEmpty) {
      return null;
    }

    return valid.last;
  }
}
