# AXI4 Slave RTL Design and SystemVerilog Verification

## Overview

This project implements a **32-bit AXI4 Full Memory-Mapped Slave** in SystemVerilog and verifies it using a **layered SystemVerilog testbench**.

The slave contains an internal **256 × 32-bit memory**, providing a **1 KB address space** from `0x000` to `0x3FC`. The verification environment exercises single transfers, burst transfers, byte strobes, invalid accesses, protocol behavior, functional coverage, and randomized transactions.

## Features

### RTL Design

- AXI4 Full memory-mapped slave
- 32-bit data width
- 32-bit address width
- 4-bit transaction ID
- Internal 256 × 32-bit memory
- 1 KB addressable memory space
- Word-aligned accesses
- Write Address, Write Data and Write Response channels
- Read Address and Read Data channels
- Single-beat and burst transfers
- FIXED, INCR and WRAP burst types
- `WSTRB` byte-enable support for partial writes
- `WLAST` and `RLAST` handling
- Address-range checking
- `OKAY` and `SLVERR` response generation
- Memory reset to zero

### SystemVerilog Verification Environment

The testbench follows a layered verification architecture:

```text
                    +----------------+
                    |     Test       |
                    +--------+-------+
                             |
                    +--------v-------+
                    |  Environment   |
                    +--------+-------+
                             |
              +--------------+--------------+
              |              |              |
        +-----v-----+  +-----v-----+  +-----v------+
        | Generator |  |  Driver   |  |  Monitor   |
        +-----------+  +-----------+  +------+-----+
                                             |
                                  +----------+----------+
                                  |                     |
                            +-----v------+       +------v------+
                            | Scoreboard |       |  Coverage   |
                            +------------+       +-------------+
```

### Verification Components

- **Interface** — AXI4 signals, modports and protocol assertions
- **Transaction** — Randomizable AXI4 transaction class
- **Generator** — Generates directed and constrained-random transactions
- **Driver** — Drives AXI4 transactions onto the DUT interface
- **Monitor** — Captures DUT activity and reconstructs transactions
- **Scoreboard** — Uses a reference memory model for self-checking
- **Coverage** — Collects functional coverage
- **Environment** — Connects and controls the verification components
- **Test** — Executes directed and constrained-random test scenarios

## Assertions

The interface contains protocol assertions including:

1. AXI VALID signals remain inactive during reset.
2. `AWVALID` remains asserted until the address handshake.
3. `WVALID` remains asserted until the data handshake.
4. `ARVALID` remains asserted until the address handshake.
5. `BRESP` is restricted to supported response values.
6. `RRESP` is restricted to supported response values.
7. VALID signals are checked for unknown (`X`) values.

## Functional Coverage

The coverage model includes:

- Burst type: FIXED / INCR / WRAP
- Burst length: 1 / 4 / 8 beats
- Read / Write operation
- WSTRB patterns
- Response type: OKAY / SLVERR
- Address ranges: low / mid / high / illegal
- Cross coverage of burst type vs. read/write operation

## Test Scenarios

The test sequence includes:

| Test | Description |
|---|---|
| TC1 | Reset verification |
| TC2 | Single write and single read |
| TC3 | 4-beat INCR burst write/read |
| TC4 | FIXED burst transfer |
| TC5 | WRAP burst transfer |
| TC6 | Partial write using WSTRB |
| TC7 | Invalid address access and SLVERR |
| TC8 | 20 constrained-random transactions |
| TC9 | Consecutive burst transactions |
| TC10 | Address-range coverage |
| TC11 | WSTRB pattern coverage |

The constrained-random transaction class restricts burst lengths to **1, 4 and 8 beats**, uses a **70% write / 30% read distribution**, and intentionally generates a portion of illegal addresses for negative testing.

## Project Structure

```text
AXI4_Slave/
│
├── Design/
│   └── AXI4_slave.sv
│
├── TB/
│   ├── interface.sv
│   ├── transaction.sv
│   ├── generator.sv
│   ├── driver.sv
│   ├── monitor.sv
│   ├── scoreboard.sv
│   ├── coverage.sv
│   ├── environment.sv
│   ├── test.sv
│   ├── top.sv
│   └── testbench.sv
│
└── README.md
```

## Design Parameters

| Parameter | Value |
|---|---:|
| Data Width | 32 bits |
| Address Width | 32 bits |
| ID Width | 4 bits |
| Memory Depth | 256 words |
| Word Size | 32 bits |
| Address Space | 1 KB |
| Valid Address Range | 0x000 – 0x3FC |
| Clock | 100 MHz |

## Verification Methodology

The testbench uses **mailboxes** for communication between verification components and a **virtual interface** for DUT access.

The scoreboard maintains a reference memory model and compares:

- Write responses
- Read responses
- Read data
- Burst behavior
- Partial writes
- Invalid-address responses

The testbench also generates a VCD waveform dump using:

```systemverilog
$dumpfile("dump.vcd");
$dumpvars(0, axi4_top);
```

## Tools

- SystemVerilog
- Verilog/SystemVerilog simulation
- EDA Playground-compatible testbench structure
- VCD waveform generation

## Expected Verification Result

At the end of simulation, the scoreboard prints a PASS/FAIL summary and the functional coverage percentage:

```text
SCOREBOARD SUMMARY : PASS=<count>  FAIL=0
Functional coverage = 100%
```

A successful verification run should complete the directed and constrained-random tests without scoreboard failures and achieve high functional coverage.

## Learning Objectives

This project demonstrates practical experience with:

- AXI4 protocol channels and handshaking
- Burst-based data transfers
- RTL FSM design
- Memory-mapped slave design
- SystemVerilog classes
- Constrained randomization
- Layered testbench architecture
- Mailboxes and virtual interfaces
- Assertions
- Functional coverage
- Scoreboard-based self-checking verification
- Directed and constrained-random verification

## Author

**VrushankH**

Repository: https://github.com/VrushankH/AXI4_Slave
