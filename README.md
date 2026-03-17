# APB-Based SoC Peripheral Subsystem with UVM Verification

## Overview

Designed and verified a mini SoC subsystem using the APB protocol. The design integrates multiple peripherals with address decoding and is verified using a UVM-based testbench.

---

## Features

* APB-based communication (PSEL, PENABLE, PREADY)
  <img width="803" height="408" alt="image" src="https://github.com/user-attachments/assets/f32c027b-76b1-4500-b514-8ad371ec8ef8" />

* Memory-mapped peripherals (ALU, GPIO, Timer, Memory)
* Address decoding for peripheral selection
* UVM testbench with driver, monitor, scoreboard
* Functional coverage and assertion-based checks

---
<img width="848" height="699" alt="image" src="https://github.com/user-attachments/assets/057237e9-c1f6-4874-bda2-9db1db8a3b45" />

## Verification

* UVM environment with transaction-level modeling
* Scoreboard for data integrity checking
* Functional coverage using covergroups
* Debugging using waveform analysis

---
<img width="802" height="616" alt="image" src="https://github.com/user-attachments/assets/a93aaf1d-4554-4e23-bdde-4d2d5c0ef273" />


## Results

### Simulation Log


<img src="a.png" width="700">
<img src="b.png" width="700">
<img src="c.png" width="700">


### Coverage Summary

* Functional Coverage: **93.75%**
* Cross Coverage: **100%**
* Variable Coverage: **91.67%**

<img src="d.png" width="700">

---

## Observations

* Detected mismatches using scoreboard → debugged using waveforms
* Identified missing coverage in **ALU AND operation**
* Verified correct APB transactions across all peripherals

---

## Tools Used

* SystemVerilog, UVM 1.2
* Synopsys VCS
* URG (Coverage Analysis)

---

## Conclusion

Successfully implemented and verified an APB-based SoC subsystem with high functional coverage and effective bug detection using UVM methodology.
