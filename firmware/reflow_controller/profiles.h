// Reflow profiles: setpoint vs time, linearly interpolated between points.
// Check your paste's datasheet and adjust. The TO1313SBD's own thermostat tops
// out around 232 C (450 F), so leave it at maximum: SAC305's 245 C peak may not
// be reachable with the thermostat in circuit. Leaded or low-temp paste is safer.
#pragma once
#include <stdint.h>

struct ProfilePoint { uint16_t t_s; uint16_t temp_c; };

struct Profile {
  const char* name;
  const ProfilePoint* pts;
  uint8_t n;
  uint16_t reflow_start_s;  // when the "reflow" phase begins (for the phase label)
  uint16_t cool_start_s;    // when heating ends and cooling begins
};

// Sn63/Pb37 (leaded), typical Kester/Chip Quik curve
static const ProfilePoint PTS_SNPB[] = {
  {0, 25}, {90, 150}, {180, 180}, {210, 215}, {240, 215}, {270, 150}, {330, 50}};
// Sn42/Bi58 (low temp)
static const ProfilePoint PTS_LT[] = {
  {0, 25}, {90, 90}, {180, 130}, {210, 165}, {240, 165}, {270, 120}, {330, 50}};
// SAC305 (lead-free) — peak 245 C may exceed the oven thermostat
static const ProfilePoint PTS_SAC[] = {
  {0, 25}, {90, 150}, {180, 200}, {220, 245}, {245, 245}, {280, 180}, {340, 50}};
// Bake / dry at 120 C for 10 min (moisture-sensitive parts, PCB drying)
static const ProfilePoint PTS_BAKE[] = {
  {0, 25}, {120, 120}, {720, 120}, {780, 50}};

static const Profile PROFILES[] = {
  {"Sn63/Pb37 leaded", PTS_SNPB, 7, 180, 240},
  {"Sn42/Bi58 low-temp", PTS_LT, 7, 180, 240},
  {"SAC305 lead-free", PTS_SAC, 7, 180, 245},
  {"Bake 120C 10 min", PTS_BAKE, 4, 120, 720},
};
static const uint8_t NUM_PROFILES = sizeof(PROFILES) / sizeof(PROFILES[0]);

static inline float profileSetpoint(const Profile& p, float t) {
  if (t <= p.pts[0].t_s) return p.pts[0].temp_c;
  for (uint8_t i = 1; i < p.n; i++) {
    if (t <= p.pts[i].t_s) {
      float t0 = p.pts[i - 1].t_s, t1 = p.pts[i].t_s;
      float v0 = p.pts[i - 1].temp_c, v1 = p.pts[i].temp_c;
      return v0 + (v1 - v0) * (t - t0) / (t1 - t0);
    }
  }
  return p.pts[p.n - 1].temp_c;
}
static inline uint16_t profileEnd(const Profile& p) { return p.pts[p.n - 1].t_s; }
static inline uint16_t profilePeak(const Profile& p) {
  uint16_t m = 0;
  for (uint8_t i = 0; i < p.n; i++) if (p.pts[i].temp_c > m) m = p.pts[i].temp_c;
  return m;
}
