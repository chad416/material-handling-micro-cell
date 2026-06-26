# MHMC TestHarness Scenario Report

- Generated: 2026-06-26T11:42:14.759097+00:00
- Scope: deterministic SIL run of all PLC TestHarness scenario contracts.
- Passed: 10
- Failed: 0

## Expected vs Actual

| Scenario | Expected | Actual | Verdict | Deviation | Key KPIs |
| --- | --- | --- | --- | --- | --- |
| Normal Lane A | Lane A package sorts without alarm; KPI count and historian sample update. | 1 package verified on Lane A, no alarm active, historian emitted conveyor/KPI/event samples. | PASS | None | packages=1; laneA=1; reject=0; jams=0; throughput=7.32 ppm; historian_samples=9 |
| Jam PE3 and recovery | PE3 blockage creates jam alarm, station holds, reset is accepted, station unholds. | PE3 jam latched, alarm code 100 raised, ResetJam accepted, station returned to EXECUTE. | PASS | None | packages=0; laneA=0; reject=0; jams=1; throughput=0.00 ppm; historian_samples=13 |
| PE2 stuck high | Scanner PE stuck high is detected as jam source 2 before timeout. | PE2 stuck high exceeded dynamic jam limit and reported jam source 2. | PASS | None | packages=0; laneA=0; reject=0; jams=1; throughput=0.00 ppm; historian_samples=8 |
| PE2 stuck low | Package misses scanner trigger and raises route fault/alarm 250. | PE2 never triggered; routing forced scanner timeout and alarm manager reported code 250. | PASS | None | packages=0; laneA=0; reject=0; jams=0; throughput=0.00 ppm; historian_samples=7 |
| Start with product present | Product already on PE1 is not silently counted; route fault prevents bad KPI count. | Initial PE1 blockage did not create a false good count; downstream PE2 caused route fault. | PASS | None | packages=0; laneA=0; reject=0; jams=0; throughput=0.00 ppm; historian_samples=6 |
| Barcode misread | Bad scanner read routes package to reject and increments bad scan KPI. | BAD-SCAN payload produced one reject package and one bad scan KPI increment. | PASS | None | packages=1; laneA=0; reject=1; jams=0; throughput=5.94 ppm; historian_samples=11 |
| Network dropout | OPC UA/historian health drops and later recovers without creating a process alarm. | Historian health went false during dropout, then recovered after heartbeat and write-ok returned. | PASS | None | packages=0; laneA=0; reject=0; jams=0; throughput=0.00 ppm; historian_samples=5 |
| Manual override abuse | Manual jog/diverter abuse while AUTO is active is inhibited. | AUTO-mode manual jog/diverter requests were ignored; no solenoid command or alarm was produced. | PASS | None | packages=0; laneA=0; reject=0; jams=0; throughput=0.00 ppm; historian_samples=7 |
| Recipe change mid cycle | Recipe load event is recorded while active package still completes without misroute. | Recipe 3 loaded mid-cycle; active package retained route context and completed Lane A. | PASS | None | packages=1; laneA=1; reject=0; jams=0; throughput=6.82 ppm; historian_samples=10 |
| Throughput degradation | Slow speed lowers throughput KPI and historian publishes the degraded KPI sample. | Degraded speed lowered throughput below 8 ppm; KPI and historian captured the degradation. | PASS | None | packages=0; laneA=0; reject=0; jams=0; throughput=6.00 ppm; historian_samples=11 |

## Event Timeline Evidence

| Scenario | Time (s) | Class | State | Alarm | Severity | Message |
| --- | ---: | --- | --- | ---: | ---: | --- |
| Normal Lane A | 0.00 | COMMAND | STOPPED | 0 | 0 | Scenario started |
| Normal Lane A | 1.20 | STATE | STARTING | 0 | 0 | Station STARTING |
| Normal Lane A | 2.30 | STATE | EXECUTE | 0 | 0 | Station EXECUTE |
| Normal Lane A | 7.60 | ROUTE | EXECUTE | 0 | 0 | Lane A verification complete |
| Normal Lane A | 8.20 | KPI | EXECUTE | 0 | 0 | Scenario passed |
| Jam PE3 and recovery | 0.00 | COMMAND | STOPPED | 0 | 0 | Scenario started |
| Jam PE3 and recovery | 4.50 | FAULT_INJECTION | EXECUTE | 0 | 0 | PE3 forced high |
| Jam PE3 and recovery | 7.50 | ALARM | HOLDING | 100 | 800 | Package jam detected on main conveyor |
| Jam PE3 and recovery | 9.00 | RECOVERY | HELD | 0 | 0 | PE3 released and ResetJam accepted |
| Jam PE3 and recovery | 10.10 | STATE | UNHOLDING | 0 | 0 | Station UNHOLDING |
| Jam PE3 and recovery | 12.40 | KPI | EXECUTE | 0 | 0 | Scenario passed |
| PE2 stuck high | 4.50 | FAULT_INJECTION | EXECUTE | 0 | 0 | PE2 forced high |
| PE2 stuck high | 7.50 | ALARM | HOLDING | 100 | 800 | Jam source 2 detected |
| PE2 stuck low | 3.00 | FAULT_INJECTION | EXECUTE | 0 | 0 | PE2 forced low |
| PE2 stuck low | 5.60 | ROUTE | EXECUTE | 250 | 850 | Package missed scanner window |
| PE2 stuck low | 5.70 | ALARM | HOLDING | 250 | 850 | Routing verification or FIFO fault active |
| Start with product present | 0.00 | FAULT_INJECTION | STOPPED | 0 | 0 | Product present at PE1 before reset/start |
| Start with product present | 4.90 | ROUTE | EXECUTE | 250 | 850 | PE2 trigger without matching registered package |
| Start with product present | 5.00 | ALARM | HOLDING | 250 | 850 | Route fault active |
| Barcode misread | 5.00 | FAULT_INJECTION | EXECUTE | 0 | 0 | Scanner read failed |
| Barcode misread | 9.40 | ROUTE | EXECUTE | 0 | 0 | Reject verification complete |
| Network dropout | 4.00 | FAULT_INJECTION | EXECUTE | 0 | 0 | OPC UA/collector dropout started |
| Network dropout | 5.10 | HISTORIAN | EXECUTE | 0 | 0 | Collector heartbeat missed |
| Network dropout | 11.00 | HISTORIAN | EXECUTE | 0 | 0 | Network restored |
| Network dropout | 12.20 | HISTORIAN | EXECUTE | 0 | 0 | Historian healthy |
| Manual override abuse | 3.20 | FAULT_INJECTION | EXECUTE | 0 | 0 | Manual diverter and jog abuse asserted |
| Manual override abuse | 5.20 | SAFEGUARD | EXECUTE | 0 | 0 | Manual abuse blocked in AUTO |
| Recipe change mid cycle | 4.00 | RECIPE | EXECUTE | 0 | 0 | Recipe 3 load requested mid-cycle |
| Recipe change mid cycle | 4.10 | RECIPE | EXECUTE | 0 | 0 | Recipe accepted and dispatched |
| Recipe change mid cycle | 8.20 | ROUTE | EXECUTE | 0 | 0 | Lane A verification complete |
| Throughput degradation | 0.00 | FAULT_INJECTION | STOPPED | 0 | 0 | Recipe speed limited to degraded value |
| Throughput degradation | 10.00 | KPI | EXECUTE | 0 | 0 | Throughput degradation captured |

## Adjustments

- Scenario thresholds are intentionally conservative: 3.0 s base jam limit, 0.5 s historian sample period, and an 18.0 s scenario timeout.
- No deviations were found in this deterministic run, so no production ST logic changes were required.
- Physical commissioning still must verify real sensor bounce, pneumatic travel time, VFD ramping, scanner latency, and network loss behavior on hardware.
