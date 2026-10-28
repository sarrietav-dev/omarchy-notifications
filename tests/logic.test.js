const {test} = require('node:test');
const assert = require('node:assert/strict');
const A = require('../Attention.js');
const L = require('../NotificationLogic.js');
const row = (id, app='Chat', timestamp=100000, urgency=1) => ({ originalId:id, id, app, timestamp, urgency });

test('identity survives server id reuse', () => {
  assert.notEqual(A.key(row(1, 'Chat', 1)), A.key(row(1, 'Chat', 2)));
});
test('channel prefers desktop entry and normalizes it', () => {
  assert.equal(A.channel({...row(1), desktopEntry:'Org.Chat.desktop'}), 'org.chat');
  assert.equal(A.channel({}), 'system');
});
test('app label handles unnamed and Omarchy senders', () => {
  assert.equal(A.label({appIcon:'com.mitchellh.ghostty'}), 'ghostty');
  assert.equal(A.label({app:'omarchy-action'}), 'Omarchy');
  assert.equal(A.label({}), 'System');
});
test('groups app bursts without deleting messages', () => {
  const input = [row(2, 'Chat', 100100), row(1, 'Chat', 100000), row(3, 'Mail')];
  const groups = A.groups(input, true);
  assert.equal(groups.length, 2);
  assert.equal(groups[0].rows.length, 2);
  assert.equal(input.length, 3);
  assert.equal(A.groups(input, false).length, 3);
});
test('critical alerts remain separate and precede normal groups', () => {
  const groups = A.groups([row(1), row(2, 'Chat', 100001, 2), row(3, 'Chat', 100002, 2)], true);
  assert.equal(groups.length, 3);
  assert.equal(groups[0].row.urgency, 2);
  assert.equal(groups[1].row.urgency, 2);
});
test('distant groups have unique stable keys', () => {
  const groups = A.groups([row(1), row(2, 'Chat', 1)], true);
  assert.equal(groups.length, 2);
  assert.notEqual(groups[0].groupKey, groups[1].groupKey);
});
test('settings are clamped and defaults stay quiet', () => {
  const prefs = A.defaults({behavior:{maxVisibleToasts:100, historyLimit:1}});
  assert.equal(prefs.behavior.maxVisibleToasts, 5);
  assert.equal(prefs.behavior.historyLimit, 10);
  assert.equal(Object.hasOwn(prefs.behavior, 'fontFamily'), false);
  assert.equal(prefs.doNotDisturb.enabled, false);
});
test('relative times handle future and older entries', () => {
  assert.equal(A.relative(2000, 1000), 'now');
  assert.equal(A.relative(0, 120000), '2m');
  assert.equal(A.relative(0, 7200000), '2h');
});
test('calendar sections use local midnight', () => {
  const now = new Date(2026,9,28,12).getTime();
  assert.equal(A.bucket(now-1, now), 'Recent');
  assert.equal(A.bucket(new Date(2026,9,28,8).getTime(), now), 'Earlier today');
  assert.equal(A.bucket(new Date(2026,9,27,23).getTime(), now), 'Yesterday');
});
test('new fields and safe action argv survive disk roundtrip', () => {
  const entry = L.snapshotOf({id:7, appName:'Chat', desktopEntry:'org.chat', urgency:1,
    hints:{value:42, 'omarchy-exec-argv':'["echo","a;b"]'}, resident:true}, 100);
  const restored = L.parsePopupFiles(L.serializePopup(entry,1),1)[0];
  assert.equal(restored.progress, 42);
  assert.equal(restored.resident, true);
  assert.equal(restored.desktopEntry, 'org.chat');
  assert.deepEqual(L.parseExecArgv(restored.execArgv), ['echo','a;b']);
  assert.equal(L.parseExecArgv('["-oops"]'), null);
});
test('legacy history acquires compatible defaults', () => {
  const restored = L.historyEntry({app:'Legacy', summary:'old'},1);
  assert.equal(restored.progress, -1);
  assert.equal(restored.resident, false);
  assert.equal(restored.desktopEntry, '');
});
test('replaces_id preserves identity but updates content', () => {
  const r = L.replacementSnapshot({id:9, summary:'new', hints:{value:100}}, 3, 100);
  assert.equal(r.originalId,3); assert.equal(r.timestamp,100); assert.equal(r.progress,100);
});
test('expiry deadline and critical persistence', () => {
  assert.equal(L.popupExpired({timestamp:0},0,999999),false);
  assert.equal(L.popupExpired({timestamp:0,deadline:200},50,150),false);
  assert.equal(L.popupExpired({timestamp:0,deadline:200},50,200),true);
});
test('markup never manufactures or loads image tags', () => {
  assert.equal(L.styledBody('<img src="https://example.com/pixel">hello','Chat',''), 'hello');
  // The nested run is ONE malformed tag in Qt; keep it intact rather than
  // splicing its halves into a new executable image tag.
  assert.equal(L.styledBody('<im<img src="x">g src="y">','Chat',''), '<im<img src="x">g src="y">');
  assert.ok(!L.styledBody('<x\n<img src="x">','Chat','').includes('<img'));
});
test('image file persistence drops ephemeral providers', () => {
  const persisted = L.persistablePopup({...row(1), image:'image://temporary/data'}, '/images/');
  assert.equal(persisted.entry.image,'');
});
test('DND bypass preserves existing narrow rules', () => {
  assert.equal(L.shouldBypassDnd({appName:'Chat',urgency:2},2),false);
  assert.equal(L.shouldBypassDnd({appName:'omarchy-action',urgency:0},2),true);
});
