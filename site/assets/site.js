const controls = document.querySelector('#preview-controls');
const logButton = document.querySelector('#log-set');
const resetButton = document.querySelector('#reset-preview');
const status = document.querySelector('#log-status');
const count = document.querySelector('#set-count');
const rows = [...document.querySelectorAll('[data-set]')];
let logged = 0;

function renderSets() {
  rows.forEach((row, index) => {
    row.classList.toggle('is-logged', index < logged);
    row.classList.toggle('is-current', index === logged);
    row.querySelector('.set-state').textContent = index < logged ? 'Logged' : index === logged ? 'Ready' : 'Planned';
  });
  count.textContent = logged === rows.length ? 'All logged' : `${logged + 1} of ${rows.length}`;
  status.textContent = logged === rows.length
    ? '3 of 3 sets logged. Example complete. Reset to try again.'
    : `${logged} of ${rows.length} sets logged.${logged ? ' Take a rest before your next set.' : ''}`;
  logButton.disabled = logged === rows.length;
  logButton.textContent = logged === rows.length ? 'Complete' : 'Log set';
}

logButton.addEventListener('click', () => {
  if (logged < rows.length) logged += 1;
  renderSets();
  if (logged === rows.length) resetButton.focus();
});
resetButton.addEventListener('click', () => {
  logged = 0;
  renderSets();
  logButton.focus();
});
controls.hidden = false;
renderSets();

// Content is visible without the observer; motion only adds an arrival, never a reading gate.
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-seen');
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.12 });
  document.querySelectorAll('.showcase h2, .showcase-intro p, .logging-preview, .practice h2, .row-copy h3, .row-copy p, .practice figure, .close h2, .close-bottom p, .close-bottom .button, .footer-links, .footer-wordmark').forEach((element, index) => {
    element.classList.add('reveal');
    element.style.setProperty('--delay', `${(index % 3) * 70}ms`);
    observer.observe(element);
  });
}
