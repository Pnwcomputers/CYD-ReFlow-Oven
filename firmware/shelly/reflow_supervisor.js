// Reflow oven supervisor for the Shelly 1PM Gen4 in the oven's hot conductor.
// Runs on the Shelly itself, independent of the display controller.
//
// Install: Shelly web UI > Scripts > Create script, paste this, Save, Start,
// and enable "Run on startup".
//
// What it does (any one of these opens the relay):
//   1. Max on-time: relay on longer than MAX_ON_S in one go.
//   2. Shelly overheating: its own temperature above MAX_DEVICE_C.
//   3. Power while idle: the controller has published reflow_active=false
//      (KVS) but the oven still draws more than IDLE_POWER_W for IDLE_TRIP_S.
//      That needs both the relay closed outside a run (from the app, say) and
//      the SSR conducting when it shouldn't.
// After a trip the relay is held open for LOCKOUT_S: if anything closes it
// during that time (the app, a schedule, a controller that is still sending its
// heartbeat), it is opened again at once. To clear a lockout sooner, stop and
// start this script.
//
// A hung or rebooted controller is covered separately: it re-arms the relay
// with Switch.Set toggle_after=30 every 15 s, so the relay opens on its own
// 30 s after the heartbeats stop.
//
// Also set in the Shelly UI (not done here): power-on default OFF, input
// detached, power limit 1400 W, current limit 11 A.

let MAX_ON_S = 15 * 60;      // longest reflow + margin
let MAX_DEVICE_C = 70;       // Shelly internal temperature trip
let IDLE_POWER_W = 40;       // above standby; the oven's elements are ~1150 W
let IDLE_TRIP_S = 6;
let LOCKOUT_S = 5 * 60;      // hold the relay open this long after a trip
let POLL_MS = 2000;

let onSince = -1;            // uptime when the relay closed, -1 = open
let idleHighSince = -1;
let lockUntil = -1;          // uptime until which the relay is held open, -1 = no lockout
let reflowActive = false;

function now() { return Shelly.getComponentStatus("sys").uptime; }

function locked() { return lockUntil >= 0 && now() < lockUntil; }

function openRelay() { Shelly.call("Switch.Set", { id: 0, on: false }); }

function trip(why) {
  print("REFLOW SUPERVISOR TRIP: " + why);
  lockUntil = now() + LOCKOUT_S;
  openRelay();
  Shelly.emitEvent("reflow_trip", { reason: why });
}

function readActive() {
  Shelly.call("KVS.Get", { key: "reflow_active" }, function (res, err) {
    if (err === 0 && res && res.value !== undefined) {
      reflowActive = (res.value === "true" || res.value === true);
    }
  });
}

function poll() {
  let sw = Shelly.getComponentStatus("switch", 0);
  let t = now();
  if (!sw.output) { onSince = -1; idleHighSince = -1; return; }
  if (locked()) { openRelay(); return; }
  if (onSince < 0) onSince = t;

  if (t - onSince > MAX_ON_S) { trip("max on-time"); return; }
  if (sw.temperature && sw.temperature.tC > MAX_DEVICE_C) { trip("Shelly over temperature"); return; }

  readActive();
  if (!reflowActive && sw.apower > IDLE_POWER_W) {
    if (idleHighSince < 0) idleHighSince = t;
    if (t - idleHighSince >= IDLE_TRIP_S) { trip("power drawn while controller idle (SSR conducting?)"); return; }
  } else {
    idleHighSince = -1;
  }
}

// During a lockout, don't wait for the next poll: open the relay the moment it closes.
Shelly.addStatusHandler(function (ev) {
  if (ev && ev.component === "switch:0" && ev.delta && ev.delta.output === true && locked()) {
    print("REFLOW SUPERVISOR: relay closed during lockout, opening it again");
    openRelay();
  }
});

Timer.set(POLL_MS, true, poll);
print("Reflow supervisor running");
