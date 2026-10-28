import 'package:flutter_test/flutter_test.dart';
import 'package:kahol_yavan_radio_app/schedule.dart';

void main() {
  // 2026-10-28 is a Wednesday.
  test('current slot', () {
    expect(currentSlot(DateTime(2026, 10, 28, 10, 30))?.name, 'התכנית היומית DAILY KOUS KOUS');
    expect(currentSlot(DateTime(2026, 10, 28, 23, 59))?.name, 'TONIGHT RADIO SHOW עם ספירוס');
    expect(currentSlot(DateTime(2026, 10, 28, 12, 0)), isNull);
    expect(currentSlot(DateTime(2026, 10, 25, 20, 30)), isNull); // Sunday has no evening show
  });

  test('next slot', () {
    final now = DateTime(2026, 10, 28, 16, 30);
    final n = nextSlot(now)!;
    expect(n.$1.name, 'TONIGHT RADIO SHOW');
    expect(whenLabel(n.$2, now), 'היום 20:00');
    final late = DateTime(2026, 10, 29, 23, 0); // Thursday night
    final f = nextSlot(late)!;
    expect(f.$1.startMin, 12 * 60);
    expect(whenLabel(f.$2, late), 'מחר 12:00');
    final sat = DateTime(2026, 10, 31, 18, 0);
    expect(whenLabel(nextSlot(sat)!.$2, sat), 'מחר 10:00');
  });
}
