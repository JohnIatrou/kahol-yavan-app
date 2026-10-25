import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Key codes of the TV remotes; browsers on a computer never send them.
const _tizenBack = 10009;
const _webosBack = 461;
const _playPause = 10252;
const _play = 415;
const _pause = 19;

/// [back] goes back one screen and returns false on the home screen, where Back closes the app.
void listenTvRemote({required bool Function() back, required void Function() playPause}) {
  // Tizen sends the media keys only to apps that ask for them.
  try {
    final input = (globalContext['tizen'] as JSObject?)?['tvinputdevice'] as JSObject?;
    input?.callMethod('registerKeyBatch'.toJS, ['MediaPlayPause', 'MediaPlay', 'MediaPause'].map((k) => k.toJS).toList().toJS);
  } catch (_) {}
  globalContext.callMethod(
    'addEventListener'.toJS,
    'keydown'.toJS,
    ((JSObject e) {
      final code = (e['keyCode'] as JSNumber?)?.toDartInt;
      switch (code) {
        case _tizenBack || _webosBack:
          e.callMethod('preventDefault'.toJS);
          if (!back()) _exit();
        case _playPause || _play || _pause:
          playPause();
      }
    }).toJS,
  );
}

void _exit() {
  try {
    final tizen = globalContext['tizen'] as JSObject?;
    if (tizen != null) {
      ((tizen['application'] as JSObject).callMethod<JSObject>('getCurrentApplication'.toJS)).callMethod('exit'.toJS);
      return;
    }
    final webos = globalContext['webOS'] as JSObject?;
    if (webos != null) {
      webos.callMethod('platformBack'.toJS);
      return;
    }
  } catch (_) {}
}
