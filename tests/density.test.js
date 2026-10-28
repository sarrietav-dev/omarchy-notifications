const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const read = file => readFileSync(join(__dirname, '..', file), 'utf8');

test('idle notifications use a compact title/body and side-by-side icon', () => {
  const card=read('components/NotificationCard.qml');
  assert.match(card,/implicitWidth:\s*Style\.space\(360\)/);
  assert.match(card,/RowLayout\s*\{\s*id:\s*content/);
  assert.match(card,/maximumLineCount:\s*root\.expanded\s*\?\s*30\s*:\s*1/);
  assert.match(card,/maximumLineCount:\s*root\.expanded\s*\?\s*100\s*:\s*2/);
  assert.match(card,/implicitHeight:.*Style\.spacing\.controlPaddingY \* 2/);
});
test('secondary controls reveal without adding a permanent footer', () => {
  const card=read('components/NotificationCard.qml');
  assert.match(card,/opacity:\s*root\.showControls \|\| activeFocus \? 1 : 0/);
  assert.match(card,/visible:\s*root\.expanded && \(root\.actions\.length > 0 \|\| root\.showOpenAction\)/);
  assert.match(card,/Accessible\.name:\s*"Snooze notification"/);
  assert.match(card,/signal customSnoozeRequested\(\)/);
  assert.match(card,/Math\.min\(Style\.spacing\.hairline, Border\.top\(spec\)\)/);
});
test('toast width and integrated center actions share the compact card', () => {
  assert.match(read('components/ToastStack.qml'),/Math\.min\(Style\.space\(360\)/);
  const center=read('components/NotificationCenter.qml');
  assert.match(center,/showOpenAction:\s*true/);
  assert.match(center,/onOpenRequested:\s*center\.activate\(entry, ""\)/);
  assert.doesNotMatch(center,/text:\s*"Open ↗"/);
});
