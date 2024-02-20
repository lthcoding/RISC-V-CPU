`include "xgriscv_defines.v"

module xgriscv_pipeline(clk, reset, pc_done);
  input             clk, reset;
  output [`ADDR_SIZE-1:0]    pc_done;

  wire [`ADDR_SIZE-1:0] pc;
  wire [31:0]       instr;
  wire              memwriteenable;
  wire [3:0]        amp;
  wire [1:0]        swhb;
  wire [2:0]        lwhbu;
  wire [31:0]       addr, writedata, readdata;
   
  imem U_imem(pc, instr);

  wire [`XLEN-1:0] readdataraw;
  dmem U_dmem(clk, memwriteenable, addr, writedata, pc, amp, readdataraw);
  // peocess data from dmem according to the type of load instruction
  dmemloaddatamux dmemmux(addr, lwhbu, readdataraw, readdata);
  
  xgriscv U_xgriscv(clk, reset, pc, instr, memwriteenable, amp, addr, writedata, readdata, swhb, lwhbu, pc_done);
  
endmodule

// xgriscv: a single cycle riscv processor
module xgriscv(input         			        clk, reset,
               output [31:0] 			        pc,
               input  [`INSTR_SIZE-1:0]   instr,
               output					            memwriteenable,
               output [3:0]  			        amp,
               output [`ADDR_SIZE-1:0] 	  daddr, 
               output [`XLEN-1:0] 		    writedata,
               input  [`XLEN-1:0] 		    readdata,
               output  [1:0]               swhbout,
               output [2:0]               lwhbuout,
               output [`ADDR_SIZE-1:0]    pc_done
               );
	
  wire [6:0]  op;
 	wire [2:0]  funct3;
	wire [6:0]  funct7;
  wire [4:0]  rd, rs1;
  wire [11:0] imm;
  wire [4:0]  immctrl;
  wire        itype, jump, jalr, bunsigned, pcsrc;
  wire [3:0]  aluctrl, branch;
  wire [1:0]  alusrca;
  wire        alusrcb;
  wire        lunsigned;
  wire        memtoreg, regwrite;
  wire [1:0]  swhb;
  wire [2:0]  lwhbu;
  wire memwrite;

  ampattern ampcalculator(daddr[1:0], swhbout, amp);

  controller  c(clk, reset, op, funct3, funct7, rd, rs1, imm,
              immctrl, itype, jump, jalr, bunsigned, pcsrc, 
              aluctrl, alusrca, alusrcb, 
              memwrite, lunsigned, 
              memtoreg, regwrite, branch, swhb, lwhbu);


  datapath    dp(clk, reset,
              instr, pc,
              readdata, daddr, writedata, memwriteenable,
              immctrl, itype, jump, jalr, bunsigned, pcsrc, 
              aluctrl, alusrca, alusrcb, 
              memwrite, lunsigned,
              memtoreg, regwrite, branch,
              op, funct3, funct7, rd, rs1, imm, swhb, lwhbu, swhbout, lwhbuout, pc_done);

endmodule
