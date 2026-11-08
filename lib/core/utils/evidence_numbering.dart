class EvidenceNumbering {
  static String generate(int count) {
    final number = count + 1;
    return 'E-${number.toString().padLeft(3, '0')}';
  }
}