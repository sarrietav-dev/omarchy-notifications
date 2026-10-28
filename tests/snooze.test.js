const {test} = require('node:test');
const assert = require('node:assert/strict');
const A = require('../Attention.js');
const L = require('../NotificationLogic.js');

test('snooze duration is bounded and rejects invalid requests', () => {
  assert.equal(A.snoozeDeadline('5', 1000), 301000);
  for (const bad of ['0', '-1', 'oops', 'Infinity', '10081']) assert.equal(A.snoozeDeadline(bad,1000),0);
});
test('tomorrow snooze uses next local calendar day at 08:00', () => {
  const now = new Date(2026,9,28,23,59);
  assert.equal(A.snoozeDeadline('tomorrow',now.getTime()), new Date(2026,9,29,8).getTime());
});
test('snooze metadata survives disk roundtrip and legacy entries default to awake', () => {
  const row={originalId:4,id:4,timestamp:100,summary:'Reminder',wakeAt:500000,remindedAt:0};
  const restored=L.parsePopupFiles(L.serializePopup(row,1),1)[0];
  assert.equal(restored.wakeAt,500000);
  assert.equal(A.key(restored),A.key(row));
  assert.equal(L.historyEntry({},1).wakeAt,0);
});
test('redelivery is fresh for ordering/unread without changing persistent identity', () => {
  const old={timestamp:100,originalId:1}, reminded={...old,remindedAt:200000};
  assert.equal(A.receivedAt(old),100);
  assert.equal(A.receivedAt(reminded),200000);
  assert.equal(A.key(old),A.key(reminded));
  const restored=L.parsePopupFiles(L.serializePopup(reminded,1),1)[0];
  assert.equal(A.receivedAt(restored),200000);
});
test('redelivery grouping uses reminder time rather than original message time', () => {
  const a={timestamp:100,originalId:1,app:'Chat',urgency:1,remindedAt:1000000};
  const b={timestamp:1000010,originalId:2,app:'Chat',urgency:1};
  assert.equal(A.groups([a,b],true).length,1);
});
test('a newly returned reminder keeps its lifetime across another restart', () => {
  const row={timestamp:100,remindedAt:100000};
  assert.equal(L.popupExpired(row,8000,100500),false);
  assert.equal(L.popupExpired(row,8000,108000),true);
});
