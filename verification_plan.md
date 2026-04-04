#  Verification Plan

**Project:** APB-Based SoC Peripheral Subsystem
**Methodology:** SystemVerilog + UVM
**Author:** Neethu Jaisan

---

## 1. Objective

The objective of this verification effort is to validate the functional correctness, protocol compliance, and integration behavior of the APB-based SoC subsystem.

The verification ensures:

* Correct APB protocol implementation (SETUP → ACCESS)
* Accurate address decoding
* Functional correctness of all peripherals
* Proper inter-module communication

---

## 2. Scope

### Included

* APB protocol verification
* Address decoding logic
* Peripheral verification:

  * SRAM
  * Timer
  * GPIO
  * ALU
* Read/write operations
* Reset behavior

### Excluded

* Physical design checks
* Power analysis
* Interrupt handling

---

## 3. DUT Description

The DUT is an APB-based subsystem integrating four peripherals using memory-mapped addressing.

### Address Map

| Peripheral | Address Range |
| ---------- | ------------- |
| SRAM       | 0x00 – 0x3F   |
| Timer      | 0x40 – 0x4F   |
| GPIO       | 0x50 – 0x5F   |
| ALU        | 0x60 – 0x6C   |

* Address decoding is based on `PADDR[7:4]`
* Invalid address returns `0xDEADBEEF`

---

## 4. Verification Strategy

* Methodology: UVM (Universal Verification Methodology)
* Approach: Constrained-random verification
* Number of transactions: 500

### UVM Components

* Sequence → stimulus generation
* Driver → protocol driving
* Monitor → signal sampling
* Scoreboard → reference checking
* Coverage → completeness tracking

---

## 5. Testbench Architecture

```
tb
 └── apb_test
      └── apb_env
           ├── apb_driver
           ├── apb_monitor
           ├── apb_scoreboard
           ├── apb_coverage
           └── uvm_sequencer
```

* Virtual interface used for DUT connection
* Monitor broadcasts transactions to scoreboard and coverage

---

## 6. Features to be Verified

### 6.1 APB Protocol

* PSEL assertion in SETUP phase
* PENABLE assertion in ACCESS phase
* Address stability during transfer
* Proper IDLE transitions

---

### 6.2 Address Decoding

* Correct peripheral selection
* Default response for invalid address

---

### 6.3 SRAM

* Write and read operations
* Data integrity
* Boundary address testing

---

### 6.4 Timer

* Enable/disable functionality
* Increment behavior
* Read correctness

---

### 6.5 GPIO

* Write operation
* Read-back validation
* Data retention

---

### 6.6 ALU

* Operand loading (A, B)
* Opcode execution

#### Supported Operations

* ADD
* SUB
* AND
* OR

---

### 6.7 Reset Behavior

* All registers reset correctly
* No unknown (X) values

---

## 7. Stimulus Plan

### Directed Testing

* Basic read/write per peripheral
* Reset validation
* Single transaction checks

### Constrained Random Testing

* Random address within valid ranges
* Random data values
* Mixed read/write sequences

---

## 8. Checker Strategy

### Scoreboard

* Maintains reference model:

  * SRAM memory array
  * GPIO register
  * ALU operands and opcode

* On write → update model

* On read → compare expected vs actual

> Timer reads are excluded due to non-deterministic behavior

---

## 9. Assertions (SVA)

Implemented in interface:

* PSEL → PENABLE sequencing check
* Address stability during ACCESS phase

---

## 10. Coverage Plan

### Functional Coverage

#### Coverpoints

* Address bins:

  * MEM
  * TIMER
  * GPIO
  * ALU

* ALU operations:

  * ADD, SUB, AND, OR

* Cross Coverage:

  * Read/Write × Address

### Goal

* 100% functional coverage

---

## 11. Regression Plan

| Test Type      | Description            |
| -------------- | ---------------------- |
| Smoke Test     | Basic functionality    |
| Directed Tests | Individual peripherals |
| Random Tests   | Full system stress     |
| Reset Test     | Initialization check   |

---

## 12. Pass/Fail Criteria

### PASS

* No UVM errors or warnings
* All scoreboard checks pass
* Coverage = 100%

### FAIL

* Any mismatch detected
* Protocol violation
* Coverage holes present

---

## 13. Tools Used

* Simulator: Synopsys VCS
* Language: SystemVerilog + UVM

---

## 14. Risks & Assumptions

### Risks

* Timer non-deterministic output
* Limited negative testing

### Assumptions

* Single master system
* No bus contention

---

## 15. Conclusion

This verification plan ensures complete validation of protocol correctness, functional behavior, and subsystem integration.

The UVM-based environment provides a scalable and reusable framework for achieving full verification closure.

---
