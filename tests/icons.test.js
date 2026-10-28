const {test} = require('node:test');
const assert = require('node:assert/strict');
const A = require('../Attention.js');
const L = require('../NotificationLogic.js');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');

test('website notification icon/avatar precedes the browser icon', () => {
  assert.deepEqual(A.iconCandidates({image:'file:///tmp/site.png',appIcon:'google-chrome'}),
    ['file:///tmp/site.png','google-chrome']);
  assert.deepEqual(A.iconCandidates({image:'image://notifications/avatar',appIcon:'brave-browser'}),
    ['image://notifications/avatar','brave-browser']);
});
test('absent or duplicate website icons fall back cleanly', () => {
  assert.deepEqual(A.iconCandidates({appIcon:'firefox'}),['firefox']);
  assert.deepEqual(A.iconCandidates({image:'firefox',appIcon:'firefox'}),['firefox']);
  assert.deepEqual(A.iconCandidates({}),[]);
});
test('icon selection never requests remote URLs', () => {
  for (const image of ['https://example.com/favicon.ico','http://example.com/icon','ftp://example.com/icon','data:image/png;base64,test'])
    assert.deepEqual(A.iconCandidates({image,appIcon:'firefox'}),['firefox']);
});
test('card retries the next candidate on decode/load failure', () => {
  const card=readFileSync(join(__dirname,'../components/NotificationCard.qml'),'utf8');
  assert.match(card,/status === Image\.Error && root\.iconIndex \+ 1 < root\.iconCandidates\.length/);
  assert.match(card,/root\.iconIndex\+\+/);
  assert.match(card,/onIconCandidatesChanged:\s*iconIndex = 0/);
});
test('local image-path hint replaces the provider URL so missing files can fail', () => {
  const local = L.snapshotOf({ id: 1, appName:'Brave', appIcon:'brave-browser',
    image:'image://icon//tmp/site.png', hints:{'image-path':'/tmp/site.png'} }, 1);
  assert.equal(local.image, '/tmp/site.png');
  const fileUrl = L.snapshotOf({ id: 2, hints:{'image-path':'file:///tmp/My%20Site.png'} }, 1);
  assert.equal(fileUrl.image, '/tmp/My Site.png');
});
test('remote image hints are dropped rather than fetched implicitly', () => {
  for (const remote of ['https://example.com/favicon.ico','http://example.com/i.png','ftp://example.com/i'])
    assert.equal(L.snapshotOf({ id:1, image:'image://icon/remote', hints:{'image-path':remote} },1).image, '');
  assert.equal(L.snapshotOf({ id:1, image:'https://example.com/i.png' },1).image, '');
});
test('provider image-data remains usable when no path hint exists', () => {
  assert.equal(L.snapshotOf({ id:1, image:'image://notifications/avatar' },1).image, 'image://notifications/avatar');
});
test('large media previews use safe sources and load only when requested', () => {
  const card=readFileSync(join(__dirname,'../components/NotificationCard.qml'),'utf8');
  assert.match(card,/Attention\.iconCandidates\(\{ image: entry\.image \}\)/);
  assert.match(card,/source: root\.expanded && root\.previewMedia \? root\.mediaSource : ""/);
  assert.doesNotMatch(card,/source:\s*root\.entry\.image/);
});
