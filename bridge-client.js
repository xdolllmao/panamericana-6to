// Puente cross-origin: si el usuario no tiene sesion en este dominio pero
// SI la tiene en el otro (sextogram.vercel.app <-> panamericana-6to.vercel.app),
// traemos los tokens de Supabase via iframe+postMessage y recargamos para que
// createClient los encuentre al iniciar.
(function () {
  var HOSTS = {
    'sextogram.vercel.app': 'https://panamericana-6to.vercel.app',
    'panamericana-6to.vercel.app': 'https://sextogram.vercel.app',
  };
  var other = HOSTS[location.hostname];
  if (!other) return;
  if (sessionStorage.getItem('sb-bridge-tried') === '1') return;
  try {
    for (var i = 0; i < localStorage.length; i++) {
      var k = localStorage.key(i);
      if (k && k.indexOf('sb-') === 0 && k.indexOf('auth-token') !== -1) return;
    }
  } catch (e) { return; }
  sessionStorage.setItem('sb-bridge-tried', '1');

  function attach() {
    var iframe = document.createElement('iframe');
    iframe.style.display = 'none';
    iframe.src = other + '/bridge.html';
    document.body.appendChild(iframe);
    var timeout = setTimeout(function () {
      window.removeEventListener('message', handler);
      try { iframe.remove(); } catch (e) {}
    }, 4000);
    function handler(e) {
      if (e.origin !== other) return;
      var msg = e.data || {};
      if (msg.type === 'sb-bridge-ready') {
        try { iframe.contentWindow.postMessage({ type: 'sb-bridge-request' }, other); } catch (err) {}
        return;
      }
      if (msg.type === 'sb-bridge-response') {
        window.removeEventListener('message', handler);
        clearTimeout(timeout);
        var payload = msg.payload || {};
        var keys = Object.keys(payload);
        try { iframe.remove(); } catch (err) {}
        if (keys.length) {
          for (var j = 0; j < keys.length; j++) {
            try { localStorage.setItem(keys[j], payload[keys[j]]); } catch (err) {}
          }
          location.reload();
        }
      }
    }
    window.addEventListener('message', handler);
  }
  if (document.body) attach();
  else document.addEventListener('DOMContentLoaded', attach, { once: true });
})();
