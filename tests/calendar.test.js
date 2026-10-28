const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const A = require('../Attention.js');
const local = (y,m,d,h=8,min=0) => new Date(y,m-1,d,h,min).getTime();

test('Gmail-style Wednesday presets match the reference, including Sunday weekend', () => {
  const options=A.snoozeOptions(local(2026,10,28,14));
  assert.deepEqual(options.map(o=>o.label),['Later today','Tomorrow','Later this week','This weekend','Next week']);
  assert.deepEqual(options.map(o=>o.timestamp),[
    local(2026,10,28,18),local(2026,10,29),local(2026,10,30),local(2026,11,1),local(2026,11,2)
  ]);
});
test('past presets are hidden, never silently scheduled in the past', () => {
  const now=local(2026,11,1,20);
  const options=A.snoozeOptions(now);
  assert.deepEqual(options.map(o=>o.label),['Tomorrow','Next week']);
  assert.ok(options.every(o=>o.timestamp>now));
});
test('calendar presets handle month and year rollover', () => {
  const options=A.snoozeOptions(local(2026,12,31,12));
  assert.equal(options.find(o=>o.label==='Tomorrow').timestamp,local(2027,1,1));
  assert.equal(options.find(o=>o.label==='Next week').timestamp,local(2027,1,4));
});
test('absolute deadlines validate future timestamps', () => {
  assert.equal(A.snoozeDeadline('at:2000',1000),2000);
  for (const bad of ['at:500','at:NaN','at:-2000','at:Infinity','at:999999999999999999'])
    assert.equal(A.snoozeDeadline(bad,1000),0);
});
test('custom date/time uses strict local calendar validation', () => {
  assert.equal(A.parseLocalDateTime('2028-02-29','08:30',0),local(2028,2,29,8,30));
  for (const [date,time] of [['2027-02-29','08:00'],['2026-04-31','08:00'],['2026-13-01','08:00'],['2026-10-28','24:00'],['2026-10-28','08:60'],['10/28/2026','08:00'],['2026-10-28','8:00']])
    assert.equal(A.parseLocalDateTime(date,time,0),0,`${date} ${time}`);
  assert.equal(A.parseLocalDateTime('2026-10-28','08:00',local(2026,10,28,9)),0);
});
test('local scheduling handles daylight-saving transitions, not fixed 24-hour offsets', () => {
  const code=`const A=require(${JSON.stringify(require.resolve('../Attention.js'))});
    const before=new Date(2026,2,7,12).getTime();
    const tomorrow=A.snoozeDeadline('tomorrow',before);
    if(new Date(tomorrow).getHours()!==8 || (tomorrow-before)!==19*3600000) process.exit(1);
    if(A.parseLocalDateTime('2026-03-08','02:30',0)!==0) process.exit(2);`;
  const child=spawnSync(process.execPath,['-e',code],{env:{...process.env,TZ:'America/New_York'}});
  assert.equal(child.status,0,child.stderr.toString());
});
