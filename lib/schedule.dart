import 'state.dart';

/// One weekly broadcast slot. Days count from 0 = Sunday, as in [kDayNames].
class Slot {
  const Slot(this.days, this.start, this.end, this.name);
  final List<int> days;
  final String start;

  /// "00:00" means midnight at the end of the day.
  final String end;
  final String name;

  int get startMin => _min(start);
  int get endMin => end == '00:00' ? 24 * 60 : _min(end);

  /// "א׳–ה׳", "ב׳–ה׳", "שישי", "שבת".
  String get daysLabel {
    if (days.length == 1) return days.first == 6 ? 'שבת' : 'יום ${kDayNames[days.first]}';
    return '${_letters[days.first]}–${_letters[days.last]}';
  }

  static int _min(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}

const _letters = ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳'];
const _sunThu = [0, 1, 2, 3, 4];
const _monThu = [1, 2, 3, 4];

/// The station's weekly broadcast schedule.
const kSchedule = [
  Slot(_sunThu, '10:00', '12:00', 'התכנית היומית DAILY KOUS KOUS'),
  Slot(_sunThu, '14:00', '16:00', 'יורדניס RADIO SHOW'),
  Slot(_monThu, '20:00', '22:00', 'TONIGHT RADIO SHOW'),
  Slot(_monThu, '22:00', '00:00', 'TONIGHT RADIO SHOW עם ספירוס'),
  Slot([5], '12:00', '14:00', 'כחול יוון עם יוני איאטרו ברדיו 101.5 FM'),
  Slot([5], '14:00', '16:00', 'אהבה יוונית עם קרן רחמני'),
  Slot([5], '16:00', '18:00', "תכנית האהבה עם סטפאנוס קג'יוניס"),
  Slot([6], '11:00', '13:00', 'אהבה יוונית עם קרן רחמני ש.ח'),
  Slot([6], '13:00', '15:00', 'הופעות חיות'),
  Slot([6], '15:00', '17:00', 'כחול יוון עם יוני איאטרו ברדיו 101 FM'),
];

int _weekday(DateTime t) => t.weekday % 7;

/// The slot on the air at [t], if any.
Slot? currentSlot(DateTime t) {
  final m = t.hour * 60 + t.minute;
  for (final s in kSchedule) {
    if (s.days.contains(_weekday(t)) && m >= s.startMin && m < s.endMin) return s;
  }
  return null;
}

/// The next slot to start after [t], with its start time.
(Slot, DateTime)? nextSlot(DateTime t) {
  final day0 = DateTime(t.year, t.month, t.day);
  for (var d = 0; d <= 7; d++) {
    final day = DateTime(day0.year, day0.month, day0.day + d);
    final starts = [
      for (final s in kSchedule)
        if (s.days.contains(_weekday(day))) (s, DateTime(day.year, day.month, day.day, s.startMin ~/ 60, s.startMin % 60)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final x in starts) {
      if (x.$2.isAfter(t)) return x;
    }
  }
  return null;
}

/// "היום 20:00", "מחר 10:00" or "יום שישי 12:00".
String whenLabel(DateTime start, DateTime now) {
  final days = DateTime(start.year, start.month, start.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  final hhmm = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final day = days == 0 ? 'היום' : days == 1 ? 'מחר' : 'יום ${kDayNames[_weekday(start)]}';
  return '$day $hhmm';
}
