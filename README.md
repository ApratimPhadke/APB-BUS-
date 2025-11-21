# 🚀 APB-SoC: Advanced Peripheral Bus System on Artix-7

![Verilog](https://img.shields.io/badge/Language-Verilog-blue?style=for-the-badge&logo=verilog)
![FPGA](https://img.shields.io/badge/Target-Artix--7%20(Nexys%204)-red?style=for-the-badge&logo=xilinx)
![Protocol](https://img.shields.io/badge/Protocol-AMBA%20APB3-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Synthesized%20%26%20Verified-success?style=for-the-badge)

> A complete System-on-Chip (SoC) infrastructure implementing the **AMBA APB v3 protocol** to interface custom **UART** and **I2C** peripherals. Designed for the Digilent Nexys 4 FPGA, featuring a hardware-based Built-In Self-Test (BIST) engine.

---

## 🧠 Project Overview

This repository hosts a modular FPGA design that bridges high-level system control with low-level communication protocols. Unlike simple "bit-banging" implementations, this project uses a fully compliant **APB Slave interface** for all peripherals, mimicking real-world ASIC/SoC architecture where a CPU (or Master FSM) communicates via a memory-mapped bus.

### ✨ Key Features
* **Bus Protocol:** Full AMBA APB v3 implementation (PSEL, PENABLE, PREADY, PSLVERR).
* **UART Core:** * Configurable Baud Rate (Default: 9600 @ 100MHz).
    * Interrupt generation on TX Done / RX Valid.
    * Status registers for error tracking (Frame/Parity errors).
* **I2C Master Core:** * FSM-based Master controller.
    * Support for Start, Stop, Read, and Write transactions.
    * Clock synchronization and ACK error detection.
* **Hardware BIST:** A top-level Finite State Machine (FSM) that automatically exercises the bus and peripherals to verify silicon functionality without a soft-core processor.

---

## 🏗️ Architecture

The design follows a strict hierarchical structure centered around the APB Interconnect:

```mermaid
graph TD
    Top[Top Level FPGA] --> BIST[BIST / Master FSM]
    BIST -->|APB Interface| Bridge_UART[APB-UART Bridge]
    BIST -->|APB Interface| Bridge_I2C[APB-I2C Bridge]
    
    Bridge_UART --> UART_Core[UART TX/RX Core]
    Bridge_I2C --> I2C_Core[I2C Master Core]
    
    UART_Core -->|RS232| USB_Port[USB-UART Port]
    I2C_Core -->|SDA/SCL| Sensors[On-board Sensors]
## 📝 Register Map

Communication is handled via 32-bit memory-mapped registers.

### 📡 UART Peripheral
| Offset | Name | R/W | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | **CONTROL** | RW | Configuration bits |
| `0x04` | **STATUS** | RO | `[0]` Busy, `[1]` TX Done, `[2]` RX Valid, `[3]` Error |
| `0x08` | **TX_DATA** | RW | Write byte to transmit |
| `0x0C` | **RX_DATA** | RO | Read received byte |

### 🔌 I2C Peripheral
| Offset | Name | R/W | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | **CONTROL** | RW | `[0]` Start, `[1]` Stop, `[2]` Read, `[3]` Write |
| `0x04` | **STATUS** | RO | `[0]` Busy, `[1]` Done, `[2]` ACK Error |
| `0x08` | **ADDR** | RW | 7-bit Slave Address |
| `0x0C` | **TX_DATA** | RW | Byte to write to slave |
| `0x10` | **RX_DATA** | RO | Byte read from slave |

---

## 🛠️ Verification & Testing

### Simulation
A complete testbench (`tb_top_level.v`) is provided. It instantiates the top level, generates a 100MHz clock, and simulates user inputs (Switches/Buttons) to trigger transactions.

* **Waveform Dump:** Generates `tb_top_level.vcd` for viewing in GTKWave.
* **Self-Checking:** Monitors UART TX lines to verify data integrity.

### Hardware Validation (Nexys 4)
The design maps to the Nexys 4 board peripherals:

* **LEDs `[7:0]`**: Indicate Status (Heartbeat, UART IRQ, I2C IRQ, Test Pass).
* **Switches `[1:0]`**: Select Test Mode (`SW[0]`=UART, `SW[1]`=I2C).
* **Buttons**:
    * `BTN[0]`: Send next UART Character.
    * `BTN[2]`: System Reset.

---

## 📂 File Structure

* `apb_bus.v`: **The Core.** Contains all APB slaves, UART/I2C logic, and Bridges.
* `top_level_fpga.v`: **The Glue.** Maps the APB system to physical FPGA pins and contains the Test FSM.
* `tb_top_level.v`: **The Proof.** Simulation testbench.
* `top_level_fpga_netlist.v`: **The Synthesis.** Yosys-generated gate-level netlist.

---

## 🚀 Getting Started

**1. Clone the repo:**
```bash
git clone [https://github.com/ApratimPhadke/your-repo-name.git](https://github.com/ApratimPhadke/your-repo-name.git)

**2. Simulate (using Icarus Verilog):**
```bash
iverilog -o testbench tb_top_level.v top_level_fpga.v apb_bus.v
vvp testbench
gtkwave tb_top_level.vcd
**3. Synthesize:**
 Import the source files into Vivado or use Yosys with the provided netlist for integration.

👤** Author**
**Apratim Phadke** GitHub | LinkedIn

Built with Verilog, Coffee, and a love for Digital Design.

