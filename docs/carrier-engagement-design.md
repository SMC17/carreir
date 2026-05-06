# Carrier Engagement-Grade Prototype Plan

Drafted 2026-05-06 by a Plan subagent during the Round III moonshot
fan-out. This is the upgrade path for `~/carreir/` — turn it from a
GEMINI-doctrine prototype into a real BACnet/IP-targeted HVAC
fault-monitor. **Per the no-downgrade direction, nothing here is
optional or aspirational; each item has a success condition and a
proof level.**

## 1. Pick BACnet/IP as the real protocol target

**Justification:** Carrier's commercial chillers (AquaEdge 19DV/23XRV,
ChillerVu i-Vu) and rooftop units publish BACnet/IP and BACnet MS/TP
integration profiles (PICs). It's an open ASHRAE/ISO standard
(ASHRAE 135-2020, ISO 16484-5), no NDA, no OEM partnership required.
Modbus is too generic; APX/Micro-Link 5 sovereign cross-compile is
unverifiable without OEM access. BACnet is the actual published wire
Carrier sells today.

**Cite:** ASHRAE 135-2020 (clauses 4, 6, 12, 19, 21), Carrier i-Vu
BACnet Integration Guide (public PDF), Carrier 19DV PIC statement.

**Success:** `src/bacnet/` decodes a real captured BACnet/IP
`Read-Property-Multiple` PDU off-wire (pcap replay).

**Files:** new `src/bacnet/npdu.zig`, `src/bacnet/apdu.zig`,
`src/bacnet/object_types.zig`; `docs/protocol-references.md`.

**Proof level after:** unit-tested.

## 2. Replay frame format `.cfr` (Carrier Frame Replay)

COBS-framed; 24-byte little-endian payload header then 16-bit BACnet
object refs:

- `magic: u32` = `0x43465231` ("CFR1")
- `seq: u32` (monotonic)
- `t_us_since_boot: u64`
- `unit_id: u16` (0..65535, mapped to chiller serial)
- `mode: u8` enum {Off=0, Startup=1, Steady=2, Defrost=3, Pumpdown=4, Fault=5}
- `n_points: u8`
- then N × `{point_id: u16, value: f32}` for: `compressor_rpm`
  (0..6000), `suction_psi` (0..200), `discharge_psi` (0..650),
  `evap_coil_c` (-50..30), `cond_coil_c` (-20..80), `ambient_c`
  (-40..55), `superheat_c` (-10..40), `subcooling_c` (-5..30),
  `fault_code: u16` (Carrier 19DV fault table 0x0000..0x00FF).

**Files:** `src/replay/frame.zig`, `data/replay/golden_19DV_steady.cfr`.

**Proof:** round-trip encode→COBS→decode; sample frame parses
bit-identical.

## 3. Causality engine v2 — multi-variable + mode-conditioned + fault injection

Extend `src/carrier_core.zig` and add `src/causality/`:

- `saturation.zig`: R-410A / R-1234ze P-T saturation table; invariant
  `evap_coil_c >= T_sat(suction_psi) - max_superheat_margin`.
- `mode_invariants.zig`: state machine keyed on `mode` enum. Startup
  allows pressure transients (skip Invariant 3 first 30s). Steady
  enforces full set. Defrost inverts evap-temp expectation.
- `fault_injection_test.zig`: replay synthetic flooded-compressor
  sequence (suction superheat collapses below 2 °C while discharge
  rises) and assert `CausalityError.FloodedSuction` fires; second
  test for low-charge (subcooling < 1 °C + high superheat).

**Proof:** two `zig build test` cases tagged `fault-injection`.

## 4. Benchmark — back the >1 kHz claim

- **Loop measured:** read frame from mmap'd `.cfr` → COBS decode →
  parse header → `checkCausality()` → `tokenizeAction()` → write
  8-byte action token to ring buffer.
- **Hardware target:** primary x86_64 dev box (record CPU model in
  output); stretch ARM Cortex-A72 (Pi 4) and Cortex-M7 cycle-count
  sim via `qemu-system-arm`.
- **Latency budget:** p99 < 1 ms (=1 kHz floor); aspirational p50 <
  100 µs.
- **Acceptance:** 1,000,000 frames replayed, p99 < 1 ms, zero
  allocations after warmup (verified via `std.heap.LoggingAllocator`).

**Files:** `bench/replay_bench.zig`, `build.zig` adds `bench` step,
`docs/benchmarks.md` records numbers.

## 5. Compile-target reality

- **APX:** Carrier APX is a building-automation supervisory controller;
  ISA and RTOS not publicly documented. **Research item** in
  `docs/open-questions.md`.
- **Micro-Link 5:** Truck/trailer telematics (Vector). Public marketing
  only; CPU/RTOS not disclosed. **Research item.**
- **Committed cross-targets** (achievable without OEM access):
  `arm-linux-gnueabihf` (Pi 4 reference), `thumb-freestanding-eabi`
  Cortex-M4/M7 (BACnet MS/TP gateway analog), `x86_64-linux-gnu`
  (CI). `zig build -Dtarget=...` matrix in CI.

**Proof:** all three targets compile clean; binary size logged.

## 6. Category-theory grounding that pays off

Implement **functorial composition of subsystem fault models**: each
subsystem (compressor, evap, cond, expansion-valve) is an object; a
fault model is a morphism `State → FaultSet`. Composition `chiller =
compressor ∘ evap ∘ cond ∘ EXV` yields plant-level fault model whose
`FaultSet` is the union closed under correlated-fault rules (low-charge
in EXV + high-superheat in evap → composed fault
`LowRefrigerantCharge_Plant`).

**Code:** `src/morphisms/subsystem.zig` (interface),
`src/morphisms/plant_composition.zig` (functor),
`src/morphisms/fault_lattice.zig` (join semilattice on `FaultSet`).

**Proof:** test that `(comp_fault ∪ evap_fault)` via composition
equals manually-asserted plant fault for two known scenarios;
identity and associativity laws asserted as `comptime` tests.

## 7. Hardware-loop test rig

- **Minimum:** Pi 4 running `cfr_emit` (Zig-built) over UDP at 2 kHz
  to carreir node on dev box; node ingests, runs causality, logs.
  Pass = 60 s run, zero dropped frames, all causality checks
  deterministic (replay-stable).
- **Stretch:** ESP32-S3 emitting BACnet/IP virtual device with 5
  analog-input objects mirroring 19DV points; carreir polls via
  BACnet `Read-Property-Multiple`. Pass = sustained 1 kHz poll.
- **Out-of-scope (engagement-only):** real Carrier controller.

**Files:** `rig/cfr_emit.zig`, `rig/README.md`, `docs/test-rig.md`.

## 8. Repository plan

`git init ~/carreir/`. Layout: `src/`, `src/bacnet/`, `src/replay/`,
`src/causality/`, `src/morphisms/`, `bench/`, `rig/`, `data/replay/`,
`data/pcap/`, `docs/`, `tests/`.

`.gitignore`: `.zig-cache/`, `zig-out/`, `*.pcap` >5MB, `*.cfr` >1MB
(keep `golden_*.cfr`).

`STATUS.md`: states current capability, test status, benchmark numbers,
what is published-spec-real vs research-flagged.

## 9. Acceptance gate — "engagement-ready"

All items 1–8 either green or filed as tracked issue in
`docs/open-questions.md`. Required artifacts:

- `docs/benchmarks.md` with p50/p99/p99.9 numbers, CPU + build flags.
- `docs/protocol-references.md` with ASHRAE 135 clause-level citations.
- ≥1 fault-injection test for a real Carrier failure mode (flooded
  compressor or low charge).
- `git log` shows ≥1 commit per item 1–8.
- `zig build test && zig build bench && zig build
  -Dtarget=arm-linux-gnueabihf` all succeed.

## 10. Documentation pass

Rewrite `GEMINI.md` → `docs/architecture.md`: replace "APX/Micro-Link
sovereign cross-compile" claim with "BACnet/IP + cfr replay; APX
target tracked in open-questions.md". Keep doctrine paragraph framed
as direction, not delivered fact.

## 11. CI scaffold

Local `zig build ci` runs: `test`, `bench --short`, three
cross-compile targets. Optional GitHub Actions later. Proof: single
command, exit 0.

## 12. Tag `v0.1-engagement-prototype`

After items 1–11 land. Tag annotated; release notes link benchmark
and protocol-references docs.

---

## Open questions for stax

1. **Protocol target confirmation:** approve BACnet/IP, or prefer
   Modbus TCP (simpler, but generic), or pursue Carrier i-Vu OEM API
   (requires partnership)?
2. **Hardware rig:** Pi 4 + ESP32-S3 on hand, or buy? Stretch rig
   (real Carrier residential controller via BACnet thermostat e.g.
   TP-WEM01) — budget?
3. **Carrier engagement posture:** public-spec-only (recommended),
   or attempt direct outreach for APX/Micro-Link 5 dev kit? Affects
   items 5 and 7.
4. **Refrigerant scope:** R-410A (residential Infinity) only, or
   also R-1234ze (AquaEdge) and R-452A (Vector)? Affects item 3
   saturation tables.
5. **License:** repo public or private? Affects whether pcap fixtures
   with vendor traffic are committed.
