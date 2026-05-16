import 'package:flutter_test/flutter_test.dart';

import 'package:stopgrinding/app/shell/menu_bar_tray_config.dart';

void main() {
  test('formats short tray countdown as minutes and seconds', () {
    expect(formatTrayCountdown(const Duration(minutes: 1, seconds: 9)), '1:09');
  });

  test('formats long tray countdown with hours', () {
    expect(
      formatTrayCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('builds descriptive tooltip for active break countdown', () {
    expect(
      resolveTrayToolTip(const Duration(seconds: 45)),
      'StopGrinding • Break ends in 0:45',
    );
  });
}
