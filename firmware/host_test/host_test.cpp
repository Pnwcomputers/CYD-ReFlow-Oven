// Host test: runs the real reflow firmware (reflow_controller.ino) on a PC
// against a simulated oven, thermocouple chip, SSR and Shelly, and checks the
// behaviour that matters for safety. See README.md in this folder.
//
// Build and run with ./run.sh (needs only g++).

#include "reflow_controller.ino"

#include <functional>
#include <sys/wait.h>
#include <unistd.h>

namespace {

bool loopHung = false;        // loop() is not being called (stuck control loop)
bool boardDead = false;       // nothing runs (reset, crash, power loss)
uint64_t nextTaskUs = 0;
int checksFailed = 0;
bool ssrEverOn = false;
size_t textsChecked = 0;
const char* scenarioName = "";

void failed(const char* what, const char* file, int line) {
  checksFailed++;
  printf("    FAILED %s:%d  %s   (t=%.1f s, oven %.1f C, mode %d, abort \"%s\")\n", file, line, what,
         sim::seconds(), sim::oven.tempC, (int)mode, abortReason);
}
#define CHECK(cond) do { if (!(cond)) failed(#cond, __FILE__, __LINE__); } while (0)

bool isRunMode() { return mode == Mode::Arming || mode == Mode::Running || mode == Mode::Cooling; }

// Text must stay on the screen, clear of the buttons, and the title and status
// line must stay left of the temperature readout.
void checkLayout() {
  if (sim::texts.size() < textsChecked) textsChecked = 0;      // screen was cleared
  for (; textsChecked < sim::texts.size(); textsChecked++) {
    const sim::Text& t = sim::texts[textsChecked];
    bool ok = t.x0 >= 0 && t.x1 <= W && t.y0 >= 0 && t.y1 <= H;
    bool label = t.datum == MC_DATUM;                           // a button's own label
    if (!label) {
      std::vector<const Btn*> shown;
      if (mode == Mode::Idle) shown = {&BTN_PREV, &BTN_NEXT, &BTN_START};
      else if (isRunMode()) shown = {&BTN_STOP};
      else shown = {&BTN_OK};
      for (const Btn* b : shown)
        if (t.x1 > b->x && t.x0 < b->x + b->w && t.y1 > b->y && t.y0 < b->y + b->h) ok = false;
      bool isTemp = t.datum == TR_DATUM && t.font == 4;
      if (!isTemp && t.y0 < 30 && t.x1 > W - 4 - TEMP_W) ok = false;
      if (isTemp && t.x1 - t.x0 != TEMP_W) ok = false;         // padded to a fixed width
    } else {
      const Btn* all[] = {&BTN_PREV, &BTN_NEXT, &BTN_START, &BTN_STOP, &BTN_OK};
      bool inside = false;
      for (const Btn* b : all)
        if (t.x0 >= b->x && t.x1 <= b->x + b->w && t.y0 >= b->y && t.y1 <= b->y + b->h) inside = true;
      if (!inside) ok = false;
    }
    if (!ok) {
      checksFailed++;
      printf("    FAILED layout: \"%s\" font %d at x %d..%d, y %d..%d on a %dx%d screen\n", t.s.c_str(),
             t.font, t.x0, t.x1, t.y0, t.y1, W, H);
    }
  }
}

// One millisecond of simulated time.
void tick() {
  sim::us += 1000;
  sim::world();
  if (!boardDead) {
    if (!loopHung) loop();
    if (sim::us >= nextTaskUs && sim::us >= sim::taskBusyUntilUs) {
      shellyStep();
      nextTaskUs = sim::us + 200000;
    }
  }
  if (sim::ssrConducting()) {
    ssrEverOn = true;
    // The SSR may only be driven while a run is in its heating phase.
    if (!loopHung && !boardDead && mode != Mode::Running) {
      static bool once = false;
      if (!once) { once = true; failed("SSR driven outside the heating phase", __FILE__, __LINE__); }
    }
  }
  if (sim::texts.size() != textsChecked) checkLayout();
}

bool until(const std::function<bool()>& done, double maxSeconds) {
  uint64_t end = sim::us + (uint64_t)(maxSeconds * 1e6);
  while (sim::us < end) {
    tick();
    if (done()) return true;
  }
  return false;
}
void run(double seconds) { until([] { return false; }, seconds); }

void tap(const Btn& b) {
  sim::touchX = (uint16_t)(b.x + b.w / 2);
  sim::touchY = (uint16_t)(b.y + b.h / 2);
  sim::touchDown = true;
  run(0.1);
  sim::touchDown = false;
  run(0.1);
}

void boot() {
  sim::ssrPin = SSR_PIN; sim::tcCs = TC_CS; sim::tcSck = TC_SCK; sim::tcSo = TC_SO;
  sim::ssrActiveLow = SSR_ACTIVE_LOW;
#if defined(BOARD_FREENOVE_S3_35)
  sim::screenW = 480; sim::screenH = 320;
#endif
  setup();
  CHECK(sim::taskCreated);
  CHECK(!sim::ssrConducting());
  run(4.0);                                 // the Shelly task opens the relay and publishes "idle"
  CHECK(mode == Mode::Idle);
  CHECK(!isnan(tempC));
}

bool startRun_(int profile) {
  while (profileIdx != profile) tap(BTN_NEXT);
  tap(BTN_START);
  return until([] { return mode != Mode::Arming; }, 20) && mode == Mode::Running;
}

bool aborted(const char* why) { return mode == Mode::Aborted && strcmp(abortReason, why) == 0; }

// After any abort: SSR released at once, relay open and "idle" published soon after.
void checkSafeAfterAbort() {
  CHECK(!sim::ssrConducting());
  run(1.0);
  CHECK(!sim::shelly.relay);
  CHECK(!sim::shelly.kvsActive);
  CHECK(!sim::ssrConducting());
}

// ------------------------------------------------------------------ scenarios

void fullRun(int profile, double peakLow, double peakHigh) {
  boot();
  CHECK(startRun_(profile));
  CHECK(sim::shelly.relay && sim::shelly.kvsActive);
  bool done = until([] { return mode == Mode::Done || mode == Mode::Aborted; }, 40 * 60);
  CHECK(done && mode == Mode::Done);
  printf("    %-20s peak %.1f C (profile %d C), heater on %.0f s, ended at %.0f s\n", PROFILES[profile].name,
         sim::oven.peakC, profilePeak(PROFILES[profile]), sim::heatOnUs / 1e6, sim::seconds());
  CHECK(sim::oven.peakC >= peakLow && sim::oven.peakC <= peakHigh);
  CHECK(sim::oven.peakC < HARD_MAX_C);
  CHECK(!sim::shelly.everOnWithoutTimer);                    // every "on" call carried toggle_after
  CHECK(sim::shelly.lastToggleAfter == (int)SHELLY_TOGGLE_AFTER_S);
  CHECK(sim::shelly.maxOnGapS < SHELLY_TOGGLE_AFTER_S - 5);  // heartbeats well inside the timeout
  run(1.0);
  CHECK(!sim::shelly.relay && !sim::shelly.kvsActive && !sim::ssrConducting());
  tap(BTN_OK);
  CHECK(mode == Mode::Idle);
}
// Peak windows are for the model oven in stubs/sim.h, not a promise about a real
// one: they are here to catch a change that makes the control loop behave differently.
void profile_leaded() { fullRun(0, 205, 225); }
void profile_lowtemp() { fullRun(1, 157, 175); }
void profile_sac305() { fullRun(2, 233, 255); }
void profile_bake() { fullRun(3, 115, 133); }

void probe_unplugged_mid_run() {
  boot();
  CHECK(startRun_(0));
  run(60);
  sim::tcOpen = true;
  CHECK(until([] { return mode == Mode::Aborted; }, 2.5));
  CHECK(aborted("Thermocouple not reading"));
  checkSafeAfterAbort();
}

void probe_unplugged_at_start() {
  sim::tcOpen = true;
  sim::ssrPin = SSR_PIN; sim::tcCs = TC_CS; sim::tcSck = TC_SCK; sim::tcSo = TC_SO;
  sim::ssrActiveLow = SSR_ACTIVE_LOW;
  setup();
  run(4.0);
  CHECK(isnan(tempC));
  tap(BTN_START);
  run(2.0);
  CHECK(aborted("Thermocouple not reading"));
  CHECK(!ssrEverOn);
  checkSafeAfterAbort();
}

void probe_wire_shorted_high() {
  boot();
  CHECK(startRun_(0));
  run(40);
  sim::tcStuckHigh = true;
  CHECK(until([] { return mode == Mode::Aborted; }, 2.5));
  CHECK(aborted("Thermocouple not reading"));
  checkSafeAfterAbort();
}

void oven_still_hot() {
  sim::oven.tempC = 120;
  boot();
  tap(BTN_START);
  run(1.0);
  CHECK(aborted("Oven too hot to start"));
  CHECK(!ssrEverOn);
  checkSafeAfterAbort();
}

void shelly_unreachable_at_start() {
  sim::shelly.reachable = false;
  boot();
  tap(BTN_START);
  CHECK(mode == Mode::Arming);
  CHECK(until([] { return mode == Mode::Aborted; }, ARM_TIMEOUT_MS / 1000.0 + 1));
  CHECK(aborted("Shelly not reachable"));
  CHECK(!ssrEverOn);
  CHECK(!sim::ssrConducting());
}

void wifi_off_at_start() {
  sim::wifiUp = false;
  boot();
  tap(BTN_START);
  CHECK(until([] { return mode == Mode::Aborted; }, ARM_TIMEOUT_MS / 1000.0 + 1));
  CHECK(aborted("Shelly not reachable"));
  CHECK(!ssrEverOn);
  CHECK(sim::wifiReconnects > 0);
}

// A short Wi-Fi dropout must not end the run.
void wifi_dropout_8s() {
  boot();
  CHECK(startRun_(0));
  run(100);
  sim::wifiUp = false;
  run(8);
  sim::wifiUp = true;
  CHECK(mode == Mode::Running);
  CHECK(until([] { return mode == Mode::Done || mode == Mode::Aborted; }, 40 * 60));
  CHECK(mode == Mode::Done);
  CHECK(sim::oven.peakC > 205);
}

// The Shelly stops answering for a few seconds right when a heartbeat is due.
void shelly_slow_for_6s() {
  boot();
  CHECK(startRun_(0));
  run(100);
  sim::shelly.reachable = false;
  run(6);
  sim::shelly.reachable = true;
  CHECK(until([] { return mode == Mode::Done || mode == Mode::Aborted; }, 40 * 60));
  CHECK(mode == Mode::Done);
}

// The Shelly is gone for good: the run must stop before the Shelly's own timeout.
void shelly_lost_mid_run() {
  boot();
  CHECK(startRun_(0));
  run(100);
  double lastOk = shellyLastOkMs / 1000.0;
  sim::shelly.reachable = false;
  CHECK(until([] { return mode == Mode::Aborted; }, 40));
  CHECK(aborted("Lost contact with Shelly"));
  double after = sim::seconds() - lastOk;
  printf("    aborted %.1f s after the last answered heartbeat\n", after);
  CHECK(after > SHELLY_LOST_ABORT_MS / 1000.0 - 0.5 && after < SHELLY_TOGGLE_AFTER_S);
  CHECK(!sim::ssrConducting());
  CHECK(until([] { return !sim::shelly.relay; }, 10));      // the Shelly opens by itself
  CHECK(sim::seconds() - lastOk <= SHELLY_TOGGLE_AFTER_S + 0.5);
}

// Element open or oven unplugged from the socket: full power, no temperature rise.
void heater_dead() {
  sim::oven.heaterDead = true;
  boot();
  CHECK(startRun_(0));
  double t0 = sim::seconds();
  CHECK(until([] { return mode == Mode::Aborted; }, 120));
  CHECK(aborted("No temp rise: check probe"));
  printf("    aborted after %.0f s\n", sim::seconds() - t0);
  checkSafeAfterAbort();
}

// SSR already failed closed: the check before heating must refuse to run.
void ssr_stuck_before_start() {
  sim::oven.ssrShorted = true;
  boot();
  tap(BTN_START);
  CHECK(until([] { return mode != Mode::Arming; }, 20));
  CHECK(aborted("SSR stuck on: replace it"));
  CHECK(!ssrEverOn);
  checkSafeAfterAbort();
  run(60);
  printf("    refused to start; oven peaked at %.0f C from the few seconds the relay was closed\n", sim::oven.peakC);
  CHECK(sim::oven.peakC < 40);
}

// SSR fails closed during a run: only the Shelly relay can stop the heat. The
// firmware notices at a heartbeat, from power flowing while it holds the SSR off.
void ssr_fails_closed_mid_run() {
  boot();
  CHECK(startRun_(0));
  run(100);
  double t0 = sim::seconds(), c0 = sim::oven.tempC;
  sim::oven.ssrShorted = true;
  CHECK(until([] { return mode == Mode::Aborted; }, 120));
  CHECK(aborted("SSR stuck on: replace it"));
  printf("    noticed after %.0f s, oven went from %.0f to %.0f C\n", sim::seconds() - t0, c0, sim::oven.tempC);
  checkSafeAfterAbort();
  run(180);
  CHECK(sim::oven.peakC < 215);                             // well short of the profile's own peak
  CHECK(sim::oven.tempC < sim::oven.peakC - 5);             // it is cooling
  tap(BTN_OK);
  CHECK(mode == Mode::Idle);
}

// The supervisor script on the Shelly is holding the relay open (after a trip).
void shelly_refuses_to_close() {
  sim::shelly.lockout = true;
  boot();
  tap(BTN_START);
  CHECK(until([] { return mode != Mode::Arming; }, 20));
  CHECK(aborted("Shelly opened its relay"));
  CHECK(!ssrEverOn);
}

// The Shelly opens its relay itself (power or current limit, over temperature,
// the supervisor script, the app). The heartbeat must not close it again.
void relay_opened_by_shelly() {
  boot();
  CHECK(startRun_(0));
  run(100);
  int onCalls = sim::shelly.onCalls;
  sim::shelly.relay = false;
  sim::shelly.toggleAtUs = 0;
  CHECK(until([] { return mode == Mode::Aborted; }, SHELLY_HEARTBEAT_MS / 1000.0 + 2));
  CHECK(aborted("Shelly opened its relay"));
  run(20);
  CHECK(sim::shelly.onCalls == onCalls);                    // never re-closed
  CHECK(!sim::shelly.relay);
  checkSafeAfterAbort();
}

// The status answer is laid out differently (no spaces, different order).
void shelly_status_other_layout() {
  sim::shelly.statusFormat = "{\"output\":%s,\"apower\":%.1f,\"current\":%.2f,\"id\":0}";
  boot();
  CHECK(startRun_(0));
  run(100);
  CHECK(mode == Mode::Running);
  sim::shelly.relay = false;
  sim::shelly.toggleAtUs = 0;
  CHECK(until([] { return mode == Mode::Aborted; }, SHELLY_HEARTBEAT_MS / 1000.0 + 2));
  CHECK(aborted("Shelly opened its relay"));
}

// A status answer the firmware can't read must not stop a healthy run.
void shelly_status_unreadable() {
  sim::shelly.statusFormat = "{\"ison\":%s,\"power\":%.1f,\"amps\":%.2f}";
  boot();
  CHECK(startRun_(1));
  CHECK(until([] { return mode == Mode::Done || mode == Mode::Aborted; }, 40 * 60));
  CHECK(mode == Mode::Done);
  CHECK(sim::serialOut.find("Shelly status not understood") != std::string::npos);
}

// loop() stops running with the SSR on. The Shelly task must cut the heat.
void control_loop_hangs() {
  boot();
  CHECK(startRun_(0));
  run(30);
  CHECK(until([] { return sim::ssrConducting(); }, 5));
  loopHung = true;
  double t0 = sim::seconds();
  CHECK(until([] { return !sim::ssrConducting(); }, 10));
  printf("    SSR released %.1f s after the loop stopped\n", sim::seconds() - t0);
  CHECK(sim::seconds() - t0 <= LOOP_STALL_MS / 1000.0 + 0.5);
  CHECK(until([] { return !sim::shelly.relay; }, 2));
  int onCalls = sim::shelly.onCalls;
  run(40);
  CHECK(sim::shelly.onCalls == onCalls);                    // heartbeat stopped too
  CHECK(!sim::shelly.relay && !sim::ssrConducting());
  loopHung = false;
  run(0.5);
  CHECK(aborted("Controller stalled"));
  checkSafeAfterAbort();
}

// The board resets, crashes or loses power: pins float, nothing runs.
void board_dies() {
  boot();
  CHECK(startRun_(0));
  run(100);
  double lastOk = shellyLastOkMs / 1000.0;
  boardDead = true;
  sim::pins[SSR_PIN].mode = INPUT;                          // reset releases every pin
  CHECK(until([] { return !sim::shelly.relay; }, 40));
  printf("    Shelly opened %.1f s after the last heartbeat\n", sim::seconds() - lastOk);
  CHECK(sim::seconds() - lastOk <= SHELLY_TOGGLE_AFTER_S + 0.5);
}

void stop_button() {
  boot();
  CHECK(startRun_(0));
  run(50);
  tap(BTN_STOP);
  CHECK(aborted("Stopped by user"));
  checkSafeAfterAbort();
  tap(BTN_OK);
  CHECK(mode == Mode::Idle);
}

void stop_while_cooling() {
  boot();
  CHECK(startRun_(1));
  CHECK(until([] { return mode == Mode::Cooling; }, 20 * 60));
  CHECK(!sim::ssrConducting());
  run(1.0);
  CHECK(!sim::shelly.relay);                                // relay opens when heating ends
  CHECK(sim::shelly.kvsActive);                             // still "in a run" until done
  tap(BTN_STOP);
  CHECK(aborted("Stopped by user"));
  checkSafeAfterAbort();
}

void serial_commands() {
  boot();
  sim::serialIn.push_back('x');                             // 'x' while idle does nothing
  run(0.2);
  CHECK(mode == Mode::Idle);
  sim::serialIn.push_back('g');
  CHECK(until([] { return mode == Mode::Running; }, 12));
  run(20);
  sim::serialIn.push_back('g');                             // 'g' during a run does nothing
  run(0.2);
  CHECK(mode == Mode::Running);
  sim::serialIn.push_back('x');
  run(0.2);
  CHECK(aborted("Stopped from serial"));
  checkSafeAfterAbort();
  tap(BTN_OK);
  sim::serialIn.push_back('x');                             // ...and must not turn "idle" into "aborted"
  run(0.2);
  CHECK(mode == Mode::Idle);
}

void profile_choice_is_saved() {
  boot();
  CHECK(profileIdx == 0);
  tap(BTN_NEXT); tap(BTN_NEXT);
  CHECK(profileIdx == 2);
  tap(BTN_PREV);
  CHECK(profileIdx == 1);
  setup();                                                  // "reboot": flash is kept
  CHECK(profileIdx == 1);
  for (int i = 0; i < NUM_PROFILES; i++) { tap(BTN_NEXT); run(0.6); }   // draw every title
  CHECK(profileIdx == 1);
}

// The longest abort text must fit beside the OK button on this screen.
void abort_texts_fit() {
  boot();
  const char* reasons[] = {"Thermocouple not reading", "Over max temperature", "Too far above profile",
                           "Max run time exceeded", "Shelly opened its relay", "Lost contact with Shelly",
                           "No temp rise: check probe", "Oven too hot to start", "Shelly not reachable",
                           "Controller stalled", "Stopped by user", "Stopped from serial",
                           "SSR stuck on: replace it"};
  for (const char* r : reasons) {
    abortRun(r);
    run(0.6);
    tap(BTN_OK);
    CHECK(mode == Mode::Idle);
  }
}

struct Scenario { const char* name; void (*fn)(); };
const Scenario SCENARIOS[] = {
  {"profile: Sn63/Pb37 leaded, full run", profile_leaded},
  {"profile: Sn42/Bi58 low-temp, full run", profile_lowtemp},
  {"profile: SAC305 lead-free, full run", profile_sac305},
  {"profile: bake 120 C, full run", profile_bake},
  {"thermocouple unplugged during a run", probe_unplugged_mid_run},
  {"thermocouple unplugged before START", probe_unplugged_at_start},
  {"thermocouple data wire shorted high", probe_wire_shorted_high},
  {"START with the oven still hot", oven_still_hot},
  {"Shelly not reachable at START", shelly_unreachable_at_start},
  {"Wi-Fi down at START", wifi_off_at_start},
  {"Wi-Fi drops for 8 s during a run (must carry on)", wifi_dropout_8s},
  {"Shelly silent for 6 s during a run (must carry on)", shelly_slow_for_6s},
  {"Shelly lost for good during a run", shelly_lost_mid_run},
  {"heating element dead", heater_dead},
  {"SSR already stuck on at START", ssr_stuck_before_start},
  {"SSR fails closed during a run", ssr_fails_closed_mid_run},
  {"Shelly refuses to close (script lockout)", shelly_refuses_to_close},
  {"Shelly opens its relay by itself", relay_opened_by_shelly},
  {"Shelly status in another layout", shelly_status_other_layout},
  {"Shelly status unreadable (must carry on)", shelly_status_unreadable},
  {"control loop hangs with the SSR on", control_loop_hangs},
  {"board resets during a run", board_dies},
  {"STOP button", stop_button},
  {"STOP while cooling", stop_while_cooling},
  {"serial commands g and x", serial_commands},
  {"profile choice is saved", profile_choice_is_saved},
  {"every abort message fits the screen", abort_texts_fit},
};

}  // namespace

int main(int argc, char** argv) {
  setvbuf(stdout, nullptr, _IOLBF, 0);
  const char* board =
#if defined(BOARD_FREENOVE_S3_35)
    "Freenove ESP32-S3 3.5\" (480x320, SSR active-high)";
#else
    "CrowPanel 2.8 / NerdMiner 2.8 (320x240, SSR active-low)";
#endif
  printf("Board: %s\n", board);
  int bad = 0, n = 0;
  for (const Scenario& s : SCENARIOS) {
    if (argc > 1 && !strstr(s.name, argv[1])) continue;
    n++;
    fflush(stdout);
    // The firmware keeps its state in globals, so every scenario gets a fresh process.
    pid_t pid = fork();
    if (pid == 0) {
      scenarioName = s.name;
      printf("  %s\n", s.name);
      s.fn();
      checkLayout();
      if (argc > 2) fputs(sim::serialOut.c_str(), stdout);   // any second argument: dump the serial log
      fflush(stdout);
      _exit(checksFailed ? 1 : 0);
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
      bad++;
      printf("  ^^^ FAILED: %s\n", s.name);
    }
  }
  printf("%d of %d scenarios passed\n", n - bad, n);
  return bad ? 1 : 0;
}
