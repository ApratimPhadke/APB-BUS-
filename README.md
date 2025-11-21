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
