// Expands every <div class="phone" data-screen="scan"> into a framed device.
//
// data-screen   the rendered screen, ../screens/<name>.png
// data-status   "light" (white status bar, for dark screens) or "dark"
// data-scale    the zoom applied to the whole device (default 1)

(function () {
  const signal =
    '<svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3.2" height="4" rx="1"/>' +
    '<rect x="4.8" y="5.5" width="3.2" height="6.5" rx="1"/><rect x="9.6" y="3" width="3.2" height="9" rx="1"/>' +
    '<rect x="14.4" y="0" width="3.2" height="12" rx="1"/></svg>';
  const wifi =
    '<svg width="16" height="12" viewBox="0 0 16 12"><path d="M8 2.2c2.3 0 4.4.9 6 2.4l1.2-1.3A10.3 10.3 0 0 0 8 .4 10.3 10.3 0 0 0 .8 3.3L2 4.6a8.5 8.5 0 0 1 6-2.4Z"/>' +
    '<path d="M8 5.6c1.4 0 2.6.5 3.6 1.4l1.2-1.3A7 7 0 0 0 8 3.8a7 7 0 0 0-4.8 1.9L4.4 7C5.4 6.1 6.6 5.6 8 5.6Z"/>' +
    '<path d="M8 9c.6 0 1.1.2 1.5.6L8 11.6 6.5 9.6C6.9 9.2 7.4 9 8 9Z"/></svg>';
  const battery =
    '<svg width="27" height="13" viewBox="0 0 27 13"><rect x="0.5" y="0.5" width="22" height="12" rx="3.8" fill="none" stroke="currentColor" stroke-opacity="0.4"/>' +
    '<rect x="2.3" y="2.3" width="18.4" height="8.4" rx="2.2"/><path d="M24 4.4v4.2c.8-.3 1.4-1.1 1.4-2.1s-.6-1.8-1.4-2.1Z" fill-opacity="0.45"/></svg>';

  for (const el of document.querySelectorAll('.phone[data-screen]')) {
    const name = el.dataset.screen;
    if (el.dataset.status === 'dark') el.classList.add('dark-status');
    if (el.dataset.scale) el.style.zoom = el.dataset.scale;
    el.innerHTML =
      '<i class="btn action"></i><i class="btn vol-up"></i><i class="btn vol-down"></i><i class="btn power"></i>' +
      '<div class="screen">' +
      `<img src="../screens/${name}.png" alt="">` +
      '<div class="island"></div>' +
      `<div class="status"><span>9:41</span><span class="icons">${signal}${wifi}${battery}</span></div>` +
      '<div class="home"></div>' +
      '</div>';
  }
})();
