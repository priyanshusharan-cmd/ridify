(() => {
  const message = document.getElementById('loading-message');
  const retry = document.getElementById('retry');
  retry.addEventListener('click', () => window.location.reload());
  window.ridifyLoadingFailed = () => {
    if (!document.getElementById('loading')) return;
    message.textContent = 'Ridify could not finish loading. Check your connection and try again.';
    retry.hidden = false;
  };
  const timeout = setTimeout(window.ridifyLoadingFailed, 45000);
  window.addEventListener('flutter-first-frame', () => {
    clearTimeout(timeout);
    document.getElementById('loading')?.remove();
  }, { once: true });
  window.addEventListener('error', (event) => {
    if (event.target?.tagName === 'SCRIPT') window.ridifyLoadingFailed();
  }, true);
})();
