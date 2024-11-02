# RISC-V-CPU
A RISC-V CPU written in Verilog. 

The project is a course project for ***Computer Organization and Design*** in WuHan University. The framework is provided by **Prof. Yili Gong**.

The goal of the project is to implement a simple pipelined RISC-V CPU(5-stage, single issue, in-order) with forwarding and hazard detection modules, which can run most of the instructions in RV32I instruction set. The first step is implementing a single cycle CPU( *Single_Cycle/*), and then modify it into a pipelined CPU(*Pipelined/*).

**P.S.** The dynamic branch prediction module(*Pipelined/xgriscv_dynamic_branch_prediction.v*) is just a simple demo which is **NOT** the same as how it is implemented in the real world.

More detailed description is in 实验报告.pdf (in Chinese).
