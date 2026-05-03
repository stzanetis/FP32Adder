# FP32Adder

Tzanetis Savvas - 10889

---

32-bit single-precision floating-point adder (IEEE-754 compliance 0, SystemVerilog implementation with SVA verification)

## Introduction

This repository is part of the **Digital Systems Hardware in Low Level Logic 2** class assignment of the **Aristotle University of Thessaloniki**. For this project, we are tasked with implementing a pipelined single-precision floating-point adder using **SystemVerilog**.

The design implements partial IEEE-754 compliance (Compliance Level 0, treating denormals as zeros and NaNs as infinity) and includes a testbench that verifies functionality against the HardFloat reference model using SystemVerilog Assertions (SVA).

## Execution

Using Questa, run:

```bash
# Compile HardFloat reference model
vlog -work work hardfloat/*.v

# Compile design modules with SystemVerilog support
vlog -work work -sv -mfcu -cuname project_all +incdir+hardfloat src/*.sv tb/*.sv top/*.sv

# Start simulation with testbench
vsim work.tb_adder

# Run simulation
run -all
```
