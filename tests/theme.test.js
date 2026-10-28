const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync, readdirSync} = require('node:fs');
const {join} = require('node:path');
const base = join(__dirname, '..');
const Attention = require('../Attention.js');
const read = (file) => readFileSync(join(base, file), 'utf8');

test('presentation does not pin fonts, literal colors, or decorative radii', () => {
  const files = readdirSync(join(base, 'components')).filter(f=>f.endsWith('.qml')).map(f=>'components/'+f);
  files.push('BarWidget.qml');
  for (const file of files) {
    const qml = read(file);
    assert.doesNotMatch(qml, /(?:font\.family|fontFamily)\s*:\s*"/, file);
    assert.doesNotMatch(qml, /(?:color|background|foreground)\s*:\s*"#[\da-f]+"/i, file);
    assert.doesNotMatch(qml, /radius\s*:\s*Style\.space\(/, file);
  }
});
test('notification cards and center consume native surface borders and rounding', () => {
  for (const [file, section] of [['components/NotificationCard.qml','notifications'],['components/NotificationCenter.qml','popups']]) {
    const qml = read(file);
    assert.match(qml, /Ui\.BorderSurface\s*\{/);
    assert.match(qml, /radius:\s*Style\.cornerRadius/);
    assert.ok(qml.includes('Border.surfaceSpec("'+section+'", "border"'));
  }
});
test('buttons, search and bar reuse Omarchy controls', () => {
  assert.match(read('components/ActionButton.qml'), /Ui\.Button\s*\{/);
  assert.match(read('components/NotificationCenter.qml'), /Ui\.TextField\s*\{/);
  assert.match(read('BarWidget.qml'), /Ui\.WidgetButton\s*\{/);
});
test('menus use the popup palette and shared interaction tokens', () => {
  assert.match(read('components/NotificationMenu.qml'), /Commons\.Color\.popups\.background/);
  assert.match(read('components/NotificationMenuItem.qml'), /Border\.controlSpec\("hover-cursor"/);
  assert.doesNotMatch(read('components/NotificationCenter.qml'), /\bMenuItem\s*\{/);
  assert.doesNotMatch(read('components/NotificationCard.qml'), /\bMenuItem\s*\{/);
});
test('legacy local font overrides no longer disconnect notifications from the theme', () => {
  const preferences = Attention.defaults({behavior:{fontFamily:'sans-serif'}});
  assert.equal(Object.hasOwn(preferences.behavior, 'fontFamily'), false);
});
