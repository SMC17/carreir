---- MODULE Coldchain ----

(***************************************************************************)
(* Formal specification of the HMAC-signed append-only reefer log.         *)
(*                                                                         *)
(* This spec models the integrity guarantees of `coldchain/log.zig` at a   *)
(* level of abstraction high enough to be tractable in TLC, but low enough *)
(* to catch the kind of bug that would let a tamper-evident log fail       *)
(* silently.                                                               *)
(*                                                                         *)
(* What's modelled                                                         *)
(*                                                                         *)
(*  - The log is a sequence of entries. Each entry has a payload, a        *)
(*    prior_hmac field linking it to the previous entry, and an hmac       *)
(*    field that is the message authentication code over                   *)
(*    `prior_hmac || payload` under a fixed key.                           *)
(*                                                                         *)
(*  - HMAC is modelled abstractly as a function MAC(key, data) that is     *)
(*    one-way and collision-resistant. We do not model the construction;   *)
(*    we model only its end-to-end property: given the same key and the    *)
(*    same data, MAC produces the same value, and the only way to produce *)
(*    a valid MAC for new data is to know the key.                        *)
(*                                                                         *)
(*  - The adversary may perform any of: insert an entry anywhere, delete  *)
(*    an entry, reorder entries, modify an entry's bytes (payload OR      *)
(*    prior_hmac OR hmac), or append an entry signed under the WRONG      *)
(*    key. The adversary does NOT have the key.                           *)
(*                                                                         *)
(*  - Replay walks the log from the start, checks each entry's MAC, and  *)
(*    asserts the chain is intact.                                        *)
(*                                                                         *)
(* What's NOT modelled                                                    *)
(*                                                                         *)
(*  - HMAC-SHA256 specifically (we use abstract MAC).                     *)
(*  - Byte-level wire format (88-byte entries with specific field          *)
(*    offsets).                                                            *)
(*  - Clock-skew between writers (out of scope; the timestamps are within *)
(*    the payload and are signed under the MAC).                          *)
(*  - Confidentiality (the log is plaintext on disk by design).           *)
(*  - Key-compromise scenarios (the spec assumes the adversary does not   *)
(*    have the key).                                                      *)
(*                                                                         *)
(***************************************************************************)

EXTENDS Naturals, Sequences, TLC

CONSTANTS
    Payloads,     \* Abstract set of possible payloads (e.g., temperature readings)
    MaxEntries,   \* Bound on log length for model checking
    Key,          \* The HMAC key, held only by the writer
    Genesis       \* The all-zero prior_hmac for the first entry

VARIABLES
    log,          \* Sequence of entries written by the legitimate writer
    adversary_log \* Sequence of entries as observed after adversary tampering

vars == << log, adversary_log >>

\* MAC is modelled as a function from (key, data) pairs to opaque values.
\* We assume MAC is deterministic, collision-resistant, and one-way: the
\* only way to produce MAC(Key, x) is to evaluate MAC(Key, x) directly.
\* In TLC, this is modelled by treating MAC as an uninterpreted tuple.
MAC(key, data) == << "MAC", key, data >>

\* An entry is a record: payload, prior_hmac (link to previous), hmac (signature).
Entry(p, prior) == [
    payload     |-> p,
    prior_hmac  |-> prior,
    hmac        |-> MAC(Key, << prior, p >>)
]

\* The set of all possible entries the legitimate writer could produce.
LegitimateEntries == { Entry(p, prior) :
    p \in Payloads,
    prior \in {Genesis} \cup { MAC(Key, anything) : anything \in (Payloads \X {Genesis}) } }

\* Initial state: log is empty.
Init ==
    /\ log = << >>
    /\ adversary_log = << >>

\* The writer appends a payload to the log.
\* The new entry's prior_hmac is the previous entry's hmac, or Genesis if empty.
\* The hmac is correctly computed.
Append(p) ==
    /\ Len(log) < MaxEntries
    /\ p \in Payloads
    /\ LET prior == IF Len(log) = 0 THEN Genesis ELSE log[Len(log)].hmac
       IN  log' = Append(log, Entry(p, prior))
    /\ adversary_log' = adversary_log

\* The adversary observes the writer's log and copies it.
AdversaryObserve ==
    /\ adversary_log' = log
    /\ UNCHANGED log

\* The adversary inserts an arbitrary entry at position i in adversary_log.
\* The entry may carry ANY hmac value the adversary chooses (since the
\* adversary doesn't have the key, this hmac will not equal MAC(Key, ...)
\* for the entry's actual (prior_hmac, payload) — unless the adversary
\* lucks into a collision, which we assume is negligible).
AdversaryInsert(i, p, fake_prior, fake_hmac) ==
    /\ i \in 1..(Len(adversary_log) + 1)
    /\ p \in Payloads
    /\ adversary_log' =
        LET prefix == SubSeq(adversary_log, 1, i - 1)
            suffix == SubSeq(adversary_log, i, Len(adversary_log))
            forged == [ payload |-> p, prior_hmac |-> fake_prior, hmac |-> fake_hmac ]
        IN  prefix \o << forged >> \o suffix
    /\ UNCHANGED log

\* The adversary deletes the entry at position i.
AdversaryDelete(i) ==
    /\ i \in 1..Len(adversary_log)
    /\ adversary_log' = SubSeq(adversary_log, 1, i - 1) \o SubSeq(adversary_log, i + 1, Len(adversary_log))
    /\ UNCHANGED log

\* The adversary reorders the log by swapping two entries.
AdversarySwap(i, j) ==
    /\ i \in 1..Len(adversary_log)
    /\ j \in 1..Len(adversary_log)
    /\ i # j
    /\ adversary_log' = [
           k \in 1..Len(adversary_log) |->
               IF k = i THEN adversary_log[j]
               ELSE IF k = j THEN adversary_log[i]
               ELSE adversary_log[k]
       ]
    /\ UNCHANGED log

\* Replay verification walks the adversary_log from the start. Each entry's
\* hmac must equal MAC(Key, prior_hmac || payload). The first entry's
\* prior_hmac must equal Genesis. Each subsequent entry's prior_hmac must
\* equal the previous entry's hmac.
ReplayValid(s) ==
    \A i \in 1..Len(s):
        /\ s[i].hmac = MAC(Key, << s[i].prior_hmac, s[i].payload >>)
        /\ IF i = 1
           THEN s[i].prior_hmac = Genesis
           ELSE s[i].prior_hmac = s[i-1].hmac

\* The next-state relation: either the writer appends, or the adversary acts.
Next ==
    \/ \E p \in Payloads: Append(p)
    \/ AdversaryObserve
    \/ \E i \in 1..(Len(adversary_log) + 1), p \in Payloads,
            fake_prior \in {Genesis} \cup { e.hmac : e \in {adversary_log[k] : k \in 1..Len(adversary_log)} },
            fake_hmac \in { e.hmac : e \in {adversary_log[k] : k \in 1..Len(adversary_log)} } \cup {<< "MAC", "not-key", << Genesis, p >> >>}:
            AdversaryInsert(i, p, fake_prior, fake_hmac)
    \/ \E i \in 1..Len(adversary_log): AdversaryDelete(i)
    \/ \E i, j \in 1..Len(adversary_log): AdversarySwap(i, j)

Spec == Init /\ [][Next]_vars

(***************************************************************************)
(* Invariants — the safety properties the coldchain hull must satisfy.    *)
(***************************************************************************)

\* SAFETY 1: The writer's log is always valid under replay.
\* If this invariant ever fails, the writer is producing logs the verifier
\* would reject — a substrate bug.
WriterLogIsAlwaysValid == ReplayValid(log)

\* SAFETY 2: The adversary cannot produce a valid log that differs from
\* the writer's log without knowing the key.
\* Specifically: if adversary_log is replay-valid AND adversary_log differs
\* from log, then the adversary must have known the key (which contradicts
\* the spec's assumption that the key is held only by the writer).
\*
\* Operationalised: in any state where adversary_log is replay-valid,
\* either adversary_log equals log, OR adversary_log is empty, OR the
\* adversary lucked into producing a valid MAC for a forged entry.
\* Under the abstract MAC model, the third disjunct is impossible (MAC is
\* a function — the adversary cannot evaluate it without the key).
TamperDetection ==
    ReplayValid(adversary_log) =>
        \/ adversary_log = log
        \/ Len(adversary_log) = 0
        \/ \E i \in 1..Len(adversary_log):
              adversary_log[i].hmac # MAC(Key, << adversary_log[i].prior_hmac, adversary_log[i].payload >>)

\* SAFETY 3: Reordering breaks the chain.
\* If two adjacent entries are swapped, replay must fail.
\* Operationalised: any prefix of adversary_log that survives replay must
\* be a prefix of log (the legitimate sequence).
ReorderingDetected ==
    \A k \in 0..Len(adversary_log):
        ReplayValid(SubSeq(adversary_log, 1, k)) =>
            SubSeq(adversary_log, 1, k) = SubSeq(log, 1, k)

(***************************************************************************)
(* Model checking notes                                                   *)
(*                                                                         *)
(* To check this spec under TLC, instantiate constants:                   *)
(*   Payloads = { p1, p2, p3 }                                            *)
(*   MaxEntries = 4                                                       *)
(*   Key = "WriterKey"                                                    *)
(*   Genesis = "Zero"                                                     *)
(*                                                                         *)
(* Check Init /\ [][Next]_vars with invariants:                          *)
(*   - WriterLogIsAlwaysValid                                            *)
(*   - TamperDetection                                                   *)
(*   - ReorderingDetected                                                *)
(*                                                                         *)
(* Expected: all three hold. If any fails, the abstract MAC model is     *)
(* wrong (adversary action set should be bounded so MAC values are only  *)
(* obtainable through legitimate Append actions) OR there's a real flaw  *)
(* in the chain construction that needs to be addressed in log.zig.      *)
(*                                                                         *)
(* This spec does NOT prove HMAC-SHA256 itself is secure. It proves that *)
(* GIVEN HMAC-SHA256 is collision-resistant and one-way, the chain       *)
(* construction in log.zig provides tamper-evidence.                     *)
(***************************************************************************)

====
