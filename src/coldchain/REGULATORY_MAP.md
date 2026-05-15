# Coldchain — Regulatory Mapping

The `coldchain` hull is an HMAC-signed, append-only reefer log. This document maps its design to the regulatory regimes cold-chain custody is judged against. The point is to name what the substrate *does* satisfy, what it does *not*, and what compliance work would still be required for a regulated deployment.

The hull is a substrate, not a turnkey compliance solution. The mapping is published so that anyone building a regulated cold-chain product on top can see exactly where the line falls.

## Regulatory regimes considered

| Regime | Scope | Why it touches cold-chain |
|---|---|---|
| **FDA 21 CFR Part 11** (US) | Electronic records + electronic signatures in FDA-regulated industries | Pharmaceutical, biologic, and certain food shipments require electronic audit trails that meet Part 11 |
| **HACCP** (Codex Alimentarius, FDA, USDA) | Food safety; temperature is a Critical Control Point (CCP) for chilled and frozen products | Continuous temperature monitoring + corrective action records are part of the HACCP plan |
| **EU GDP** (Commission Guidelines 2013/C 343/01) | Good Distribution Practice for medicinal products | Section 9 mandates temperature-controlled distribution with documented monitoring |
| **EU FSMA** | Food Safety Modernization Act, US — Sanitary Transportation rule | Records of temperature control during transport must be retained |
| **USDA / FSIS** (9 CFR 416) | Meat, poultry, egg products | Sanitary transport temperature records |

## What the coldchain hull satisfies — by clause

### FDA 21 CFR Part 11

| Clause | Requirement | How the hull addresses it | Evidence level |
|---|---|---|---|
| §11.10(b) | Ability to generate accurate and complete copies of records suitable for inspection and review | The log file is binary, fixed-width (88 bytes/entry), and self-describing (the format is documented in `log.zig`). Anyone with the format spec can render the records | `unit-tested` (replay verified across 100-entry sequences) |
| §11.10(c) | Protection of records to enable accurate retrieval throughout the records-retention period | The HMAC chain detects single-byte tampering, insertion, deletion, and reordering on replay. Records cannot be silently altered without breaking the chain | `unit-tested` (tamper-detection assertion in test suite) |
| §11.10(e) | Use of secure, computer-generated, time-stamped audit trails to record the date and time of operator entries and actions that create, modify, or delete electronic records | Each entry carries `timestamp_us` (microsecond Unix epoch) signed under the HMAC chain. Time stamps cannot be silently altered | `unit-tested` |
| §11.30 | Controls for open systems (electronic records transmitted through systems not under exclusive control of persons responsible for the record) | The HMAC chain provides integrity over open-system transmission. Confidentiality is *not* provided by this hull — see Type-II below | `unit-tested` (integrity); not provided (confidentiality) |

### HACCP

| Element | Requirement | How the hull addresses it |
|---|---|---|
| **Monitoring of CCP** | Temperature at a Critical Control Point must be monitored continuously or at a frequency sufficient to detect deviation before product is unsafe | The hull accepts entries at any cadence the producer chooses. There is no built-in sampling-rate enforcement — that is the operator's choice and HACCP-plan-specific |
| **Records** | Records of monitoring activities must be maintained | The append-only log is the record. Records cannot be retroactively altered |
| **Corrective action records** | When monitoring shows deviation, corrective action must be recorded | The entry format includes only telemetry, not free-form corrective-action notes. **Operators must layer a corrective-action record store on top.** This is a Type-II gap surfaced honestly |

### EU GDP §9 (Transportation)

| Requirement | How the hull addresses it |
|---|---|
| Temperature kept within accepted limits | The hull *records* temperature. It does not *control* it. Coupling to a refrigeration controller is out of scope |
| Documentation of temperature monitoring during transport | The HMAC-chained log provides tamper-evident documentation |
| Investigation of deviations | The replay procedure surfaces the exact entry at which any tamper or chain break occurred |

## What the coldchain hull does NOT provide

This is the Type-II honest audit. Anyone building a regulated cold-chain product on top of this hull must layer these themselves:

1. **Electronic signatures (Part 11 Subpart C)** — the HMAC is a machine-generated authentication code, not an electronic *signature* in the §11.50 / §11.70 sense. A regulated deployment must layer a distinct electronic-signature flow (signed-by-name, intent-of-signing, time of signing, with the signature linked to the record) on top.
2. **Confidentiality** — the entry payload (temperature, humidity, accelerometer) is plaintext on disk. The HMAC provides integrity, not encryption. If confidentiality is required, encrypt the file at rest separately.
3. **Operator authentication / authorization** — Part 11 §11.10(d), §11.10(g) require limiting system access to authorized individuals and authority checks. The hull is library-level — it does not enforce user authentication. The consuming application must.
4. **Key management** — the hull assumes the HMAC key is sealed externally (TPM, HSM, KMS, sealed file with OS-level ACL). If the key is compromised, the chain integrity guarantee is lost. **Key management is the highest-leverage compliance work and is out of scope for this hull.**
5. **Retention period enforcement** — Part 11 §11.10(c) requires records be retrievable throughout the retention period. The hull is format-stable but enforces no retention timer. The consuming application must.
6. **Validation under 21 CFR Part 820 / ISO 13485** — if used in a medical-device context, the hull is a software component that must be validated as part of the device's QMS. The unit tests in this repo are a starting point; full IQ/OQ/PQ documentation is a separate effort.
7. **Corrective-action record store (HACCP)** — the entry format carries telemetry only. Corrective-action notes must be stored alongside the log (e.g., in a companion append-only file with its own HMAC chain).
8. **Sampling-rate enforcement (HACCP / GDP)** — the hull accepts any entry cadence. A HACCP plan typically specifies the minimum monitoring frequency. The consuming application must enforce it.
9. **Multi-jurisdictional reconciliation** — a shipment crossing FDA, EU GDP, and USDA jurisdictions may need different retention periods and audit-trail surfaces. The hull provides one canonical record; reconciliation across regimes is out of scope.

## Evidence-level summary

| Surface | Evidence level |
|---|---|
| Integrity of recorded entries against tampering, insertion, deletion, reordering | `unit-tested` (HMAC chain replay) |
| Time-stamp integrity (Part 11 §11.10(e)) | `unit-tested` (timestamp signed under HMAC) |
| Format stability of the binary record | `unit-tested` (fixed-width 88-byte entries; format documented in source) |
| Electronic signature flow (Part 11 Subpart C) | **Not provided** |
| Operator authentication / authorization | **Not provided** |
| Confidentiality at rest | **Not provided** |
| Validated under 21 CFR Part 820 / ISO 13485 | **Not validated** |
| Production-deployed in any regulated context | **Not deployed** |
| Audited by a third party against any of these regimes | **Not audited** |

The hull is `unit-tested` and `audited` (against the threat model documented in `log.zig`). It is *not* `production`, *not* `compliance-certified`, and *not* a substitute for the validation, signature, authentication, and key-management work that any regulated deployment requires on top.

## How to consume this hull in a regulated context

1. Read this document and the threat model at the top of `log.zig` end-to-end.
2. Identify which regime(s) your deployment is judged against.
3. Layer the missing surfaces above (signatures, auth, encryption, key management, retention, corrective-action store).
4. Validate the combined system under your QMS. The hull provides format-stable building blocks; the combined system is what gets validated.
5. When in doubt, treat the hull as one of several compensating controls, not as the sole control.

## References

- **FDA 21 CFR Part 11**: *Electronic Records; Electronic Signatures*. Codified at 21 CFR Part 11. Final rule published 1997-03-20, with FDA guidance "Part 11, Electronic Records; Electronic Signatures — Scope and Application" (2003) clarifying the predicate-rule scope.
- **HACCP**: Codex Alimentarius Commission, *Recommended International Code of Practice — General Principles of Food Hygiene* (CXC 1-1969, latest revision). FDA HACCP regulations for seafood (21 CFR 123) and juice (21 CFR 120). USDA FSIS HACCP regulations (9 CFR 417).
- **EU GDP for medicinal products**: Commission Guidelines 2013/C 343/01 *on Good Distribution Practice of medicinal products for human use*, including Section 9 on transportation.
- **EU FSMA Sanitary Transportation**: 21 CFR Part 1, Subpart O *Sanitary Transportation of Human and Animal Food* (final rule 2016).
- **USDA / FSIS sanitary transport**: 9 CFR Part 416.
- **21 CFR Part 820** (medical devices Quality System Regulation) — for context on when validation is required.
- **ISO 13485:2016** — *Medical devices — Quality management systems*.

---

*This document maps a single substrate component to several regulatory regimes. It does not constitute legal or compliance advice. Operators of regulated cold-chain systems must consult qualified compliance counsel before deploying.*
