// Runs before Flutter on Samsung (Tizen) and LG (webOS) TVs.

// The TV browsers report a 1920×1080 screen at pixel ratio 1. The TV layout is drawn for 960×540
// like on Android TV, so tell Flutter the pixels are bigger: the same picture, sharp on every TV.
window.devicePixelRatio = Math.max(1, window.innerWidth / 960);

// The app opens from a local folder (file://), where fetch() is refused but XMLHttpRequest works.
// Flutter loads its engine, fonts and assets with fetch(), so serve local files through XMLHttpRequest.
(function () {
  if (location.protocol !== 'file:') return;
  var nativeFetch = window.fetch.bind(window);
  var types = { wasm: 'application/wasm', js: 'text/javascript', json: 'application/json', otf: 'font/otf', ttf: 'font/ttf', png: 'image/png' };
  window.fetch = function (input, init) {
    var url = new URL(typeof input === 'string' ? input : input.url, document.baseURI);
    if (url.protocol !== 'file:') return nativeFetch(input, init);
    return new Promise(function (resolve, reject) {
      var x = new XMLHttpRequest();
      x.open('GET', url.href);
      x.responseType = 'arraybuffer';
      x.onload = function () {
        var type = types[url.pathname.split('.').pop()] || 'application/octet-stream';
        resolve(new Response(x.response, { status: 200, headers: { 'Content-Type': type } }));
      };
      x.onerror = function () { reject(new TypeError('Cannot load ' + url.href)); };
      x.send();
    });
  };
})();
