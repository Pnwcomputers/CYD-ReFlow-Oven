// Runs the Shelly supervisor script (../shelly/reflow_supervisor.js) under
// Node.js with a stand-in for the Shelly's scripting API, and checks each trip.
// Usage: node shelly_script_test.js   (run.sh does this too)
'use strict';
const fs = require('fs');
const path = require('path');
const source = fs.readFileSync(path.join(__dirname, '..', 'shelly', 'reflow_supervisor.js'), 'utf8');

// A fake Shelly: one switch, a KVS, uptime, timers, status handlers.
function makeShelly() {
  const dev = {
    uptime: 100, output: false, apower: 0, tC: 40, kvs: {}, offCalls: 0, prints: [], events: [],
    timers: [], handlers: [], queue: [],
  };
  function setOutput(on) {
    if (dev.output === on) return;
    dev.output = on;
    if (!on) dev.apower = 0;
    // Status handlers run after the current callback, as on the device.
    dev.queue.push(() => dev.handlers.forEach(h => h({ component: 'switch:0', name: 'switch', id: 0, delta: { id: 0, output: on } })));
  }
  const Shelly = {
    getComponentStatus(name) {
      if (name === 'sys') return { uptime: dev.uptime };
      return { id: 0, output: dev.output, apower: dev.apower, temperature: { tC: dev.tC, tF: dev.tC * 1.8 + 32 } };
    },
    call(method, params, cb) {
      if (method === 'Switch.Set') {
        const was = dev.output;
        if (!params.on) dev.offCalls++;
        setOutput(!!params.on);
        if (cb) dev.queue.push(() => cb({ was_on: was }, 0, ''));
      } else if (method === 'KVS.Get') {
        const has = Object.prototype.hasOwnProperty.call(dev.kvs, params.key);
        dev.queue.push(() => (has ? cb({ etag: 'x', value: dev.kvs[params.key] }, 0, '') : cb(null, -105, 'not found')));
      } else {
        throw new Error('script called an API the test does not provide: ' + method);
      }
    },
    emitEvent(name, data) { dev.events.push({ name, data }); },
    addStatusHandler(fn) { dev.handlers.push(fn); },
  };
  const Timer = { set(ms, repeat, fn) { dev.timers.push({ ms, repeat, fn, next: ms }); return dev.timers.length; } };
  const print = (...a) => dev.prints.push(a.join(' '));
  new Function('Shelly', 'Timer', 'print', source)(Shelly, Timer, print);

  dev.drain = () => { while (dev.queue.length) dev.queue.shift()(); };
  // Something outside the script closes the relay (controller heartbeat, app).
  dev.close = (watts) => { setOutput(true); dev.apower = watts; dev.drain(); };
  // Advance time in 1 s steps, firing timers.
  dev.run = (seconds, each) => {
    for (let i = 0; i < seconds; i++) {
      dev.uptime += 1;
      for (const t of dev.timers) {
        t.next -= 1000;
        if (t.next <= 0) { t.next += t.ms; t.fn(); }
      }
      dev.drain();
      if (each) each(dev);
    }
  };
  return dev;
}

let failed = 0, count = 0;
function test(name, fn) {
  count++;
  try {
    fn();
    console.log('  ' + name);
  } catch (e) {
    failed++;
    console.log('  ' + name + '\n    FAILED: ' + e.message);
  }
}
function check(cond, what) { if (!cond) throw new Error(what); }
const tripped = (dev, text) => dev.events.some(e => e.name === 'reflow_trip' && e.data.reason.indexOf(text) >= 0);

console.log('Shelly supervisor script');

test('a normal 6 minute run is left alone', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'true';
  d.close(1150);
  d.run(360);
  check(d.output && d.events.length === 0, 'relay was opened: ' + JSON.stringify(d.events));
});

test('reflow_active stored as a real boolean also counts', () => {
  const d = makeShelly();
  d.kvs.reflow_active = true;
  d.close(1150);
  d.run(60);
  check(d.output && d.events.length === 0, 'relay was opened');
});

test('relay closed for more than 15 minutes: trip', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'true';
  d.close(600);
  d.run(14 * 60);
  check(d.output, 'tripped early');
  d.run(70);
  check(!d.output && tripped(d, 'max on-time'), 'no max on-time trip');
});

test('Shelly above 70 C: trip', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'true';
  d.close(1150);
  d.run(30);
  d.tC = 75;
  d.run(4);
  check(!d.output && tripped(d, 'over temperature'), 'no over-temperature trip');
});

test('oven draws power while the controller says idle: trip within 10 s', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'false';
  d.close(1150);
  d.run(4);
  check(d.output, 'tripped before IDLE_TRIP_S');
  d.run(6);
  check(!d.output && tripped(d, 'idle'), 'no idle-power trip');
});

test('no reflow_active key at all counts as idle', () => {
  const d = makeShelly();
  d.close(1150);
  d.run(10);
  check(!d.output && tripped(d, 'idle'), 'no idle-power trip');
});

test('relay closed but nothing drawn while idle: left alone', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'false';
  d.close(2);
  d.run(120);
  check(d.output && d.events.length === 0, 'relay was opened');
});

test('the first seconds of a run, before reflow_active arrives, do not trip', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'false';
  d.close(1150);
  d.run(3);
  d.kvs.reflow_active = 'true';
  d.run(60);
  check(d.output && d.events.length === 0, 'relay was opened');
});

test('after a trip the relay is re-opened at once for 5 minutes, then released', () => {
  const d = makeShelly();
  d.kvs.reflow_active = 'true';
  d.close(1150);
  d.tC = 80;
  d.run(4);
  check(!d.output, 'no trip');
  d.tC = 40;
  let closedSeconds = 0;
  // A controller that keeps sending its heartbeat every 15 s.
  d.run(280, dev => {
    if (dev.uptime % 15 === 0) dev.close(1150);
    if (dev.output) closedSeconds++;
  });
  check(closedSeconds === 0, 'relay stayed closed for ' + closedSeconds + ' s during the lockout');
  d.run(30);
  d.close(1150);
  d.run(20);
  check(d.output, 'relay still held open after the lockout ended');
});

console.log((count - failed) + ' of ' + count + ' script tests passed');
process.exit(failed ? 1 : 0);
