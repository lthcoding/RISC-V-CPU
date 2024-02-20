`include "xgriscv_defines.v"

module datapath(
	input						clk, reset,

	input [`INSTR_SIZE-1:0]		instr,
	output [`ADDR_SIZE-1:0]		pc,

	input [`XLEN-1:0]			readdata, 	// from data memory: read data
	output[`XLEN-1:0]			pr_EXMEM_aluout, // to data memory: address
 	output[`XLEN-1:0]			memwritedata_forwardingconsidered, 	// to data memory: write data
	output                      pr_EXMEM_memwrite, // to data memory: write enable
	
	// from & to controller
	input [4:0]		            immctrl,
	input			            itype, jump, jalr, bunsigned, pcsrc,
	input [3:0]		            aluctrl,
	input [1:0]		            alusrca,
	input			            alusrcb,
	input						memwrite, lunsigned,
	input          		        memtoreg, regwrite,
	input [3:0]					branch,
	output [6:0]				op,
	output [2:0]				funct3,
	output [6:0]				funct7,
	output [4:0]				rd, rs1,
	output [11:0]  		        imm,
	input  [1:0]                swhb, // from controller: swhb of instruction of the current pc
	input  [2:0]                lwhbu, // from controller
	
	// to DMEM
	output  [1:0]               pr_EXMEM_swhb, // swhb of the instruction in MEM stage 
	output  [2:0]               pr_EXMEM_lwhbu,

	// to testbench
	output [`ADDR_SIZE-1:0]     pc_done
	);

	//================================================================================================
	// define pipeline registers
	// pr: pipeline register
	// IF/ID
	wire [`ADDR_SIZE-1:0] pr_IFID_pc;
	wire [`ADDR_SIZE-1:0] pr_IFID_pcplus4;
	wire [`INSTR_SIZE-1:0] pr_IFID_instr;
	
	// ID/EX
	wire [`RFIDX_WIDTH-1:0] pr_IDEX_rd;
	wire [`RFIDX_WIDTH-1:0] pr_IDEX_rs1;
	wire [`RFIDX_WIDTH-1:0] pr_IDEX_rs2;
	wire [`INSTR_SIZE-1:0] pr_IDEX_instr;
	wire [`ADDR_SIZE-1:0] pr_IDEX_pc;
	wire [`ADDR_SIZE-1:0] pr_IDEX_pcplus4;
	wire [`XLEN-1:0] pr_IDEX_immout;
	wire [`XLEN-1:0] pr_IDEX_rdata1;
	wire [`XLEN-1:0] pr_IDEX_rdata2;
	wire [3:0] pr_IDEX_aluctrl;
	wire [3:0] pr_IDEX_branch;
	wire [2:0] pr_IDEX_lwhbu;
	wire [1:0] pr_IDEX_swhb;
	wire [1:0] pr_IDEX_alusrca;
	wire pr_IDEX_alusrcb;
	wire pr_IDEX_memwrite;
	wire pr_IDEX_lunsigned;
	wire pr_IDEX_regwrite;
	wire pr_IDEX_itype;
	wire pr_IDEX_jalr;
	wire pr_IDEX_bunsigned;
	wire pr_IDEX_pcsrc;
	wire pr_IDEX_memtoreg;
	wire pr_IDEX_jump;
	
	// EX/MEM
	wire [`RFIDX_WIDTH-1:0] pr_EXMEM_rs2;
	wire [`RFIDX_WIDTH-1:0] pr_EXMEM_rd;
	wire [`ADDR_SIZE-1:0] pr_EXMEM_pc;
	wire [`ADDR_SIZE-1:0] pr_EXMEM_pcplus4;
	wire pr_EXMEM_regwrite;
	wire pr_EXMEM_memtoreg;
	wire pr_EXMEM_jump;
	wire [`XLEN-1:0] pr_EXMEM_rdata2;
	// the following is declared in output
	// wire [`XLEN-1:0] pr_EXMEM_aluout;
	// wire [2:0] pr_EXMEM_lwhbu;
	// wire [1:0] pr_EXMEM_swhb;
	// wire pr_EXMEM_memwrite;

	
	// MEM/WB	
	wire [`RFIDX_WIDTH-1:0] pr_MEMWB_rd;
	wire [`ADDR_SIZE-1:0] pr_MEMWB_pc;
	wire [`ADDR_SIZE-1:0] pr_MEMWB_pcplus4;
	wire [`XLEN-1:0] pr_MEMWB_readdata;
	wire [`XLEN-1:0] pr_MEMWB_aluout;
	wire pr_MEMWB_regwrite;
	wire pr_MEMWB_memtoreg;
	wire pr_MEMWB_jump;



	
	//================================================================================================
	// IF stage

	wire [1:0] prediction_state;
	wire [1:0] new_state;
	wire [1:0] init_state;

	// save pc of the current instruction
	wire [`ADDR_SIZE-1:0] origin_pc = pc;
	
	wire [`ADDR_SIZE-1:0] pcplus4;
	addr_adder pcadder(pc, `ADDR_SIZE'b100, pcplus4);
	// dynamic branch prediction
	wire [`ADDR_SIZE-1:0] pc_predicted;
	branch_prediction dbp(instr, pc, pcplus4, prediction_state, pc_predicted, init_state);
	flopenrc #(2) initstate(clk, reset, 1'b0, 1'b0, init_state, prediction_state);


	// hazard detection
	wire [`XLEN-1:0] rdata1_forwardingconsidered;
	wire [`RFIDX_WIDTH-1:0] rs2;
	wire pr_IFID_flush, pr_IDEX_flush, EXMEM_flush, stall;
	wire [`ADDR_SIZE-1:0] nextpc;
	hazard_detect hd(
		pr_IDEX_branch, pr_IDEX_jump, pr_IDEX_jalr, pr_IDEX_pc, pc_predicted, pr_IDEX_immout, rdata1_forwardingconsidered, zero, lt,
		nextpc, pr_IFID_flush, pr_IDEX_flush, 
		pr_IDEX_rs1, pr_IDEX_rs2, pr_EXMEM_memtoreg, pr_EXMEM_rd,
		stall, EXMEM_flush,
		prediction_state, new_state
	);
	flopenrc #(2) predictionstate(clk, reset, 1'b0, 1'b0, new_state, prediction_state);

	// update pc
	pcenr pcenr1(clk, reset, ~stall, nextpc, pc);

	

	//================================================================================================
	// IF/ID pipeline registers
	flopenrc #(`ADDR_SIZE) pr0(clk, reset, ~stall, pr_IFID_flush, origin_pc, pr_IFID_pc);
	flopenrc #(`ADDR_SIZE) pr1(clk, reset, ~stall, pr_IFID_flush, pcplus4, pr_IFID_pcplus4);
	flopenrc #(`INSTR_SIZE) pr2(clk, reset, ~stall, pr_IFID_flush, instr, pr_IFID_instr);




	//================================================================================================
	// ID stage
	// decode
	assign  op		= pr_IFID_instr[6:0];
	assign  rd		= pr_IFID_instr[11:7];
	assign  funct3	= pr_IFID_instr[14:12];
	assign  rs1		= pr_IFID_instr[19:15];
	assign  rs2   	= pr_IFID_instr[24:20];
	assign  funct7	= pr_IFID_instr[31:25];
	assign  imm		= pr_IFID_instr[31:20];

	// immediate generation
	wire [11:0]				iimm = pr_IFID_instr[31:20];
	wire [11:0]				simm	= {pr_IFID_instr[31:25], pr_IFID_instr[11:7]};
	wire [11:0]  			bimm	= {pr_IFID_instr[31], pr_IFID_instr[7], pr_IFID_instr[30:25], pr_IFID_instr[11:8]};
	wire [19:0]				uimm	= pr_IFID_instr[31:12];
	wire [19:0]  			jimm	= {pr_IFID_instr[31], pr_IFID_instr[19:12], pr_IFID_instr[20], pr_IFID_instr[30:21]};
	wire [`XLEN-1:0]		immout;
	imm immgen(iimm, simm, bimm, uimm, jimm, immctrl, immout);

	
	// register file
	wire [`XLEN-1:0] rdata1, rdata2, wdata;
	wire [`XLEN-1:0] wdatasrc;
	mux2 #(`XLEN) wdataMUX1(pr_MEMWB_aluout, pr_MEMWB_readdata, pr_MEMWB_memtoreg, wdatasrc);
	mux2 #(`XLEN) wdataMUX2(wdatasrc, pr_MEMWB_pcplus4, pr_MEMWB_jump, wdata); //jal or jalr
	regfile rf(clk, rs1, rs2, rdata1, rdata2, pr_MEMWB_regwrite, pr_MEMWB_rd, wdata, pr_MEMWB_pc);

	
	//ID/EX pipeline registers	
	flopenrc #(`RFIDX_WIDTH) pr44(clk, reset, ~stall, pr_IDEX_flush, rd, pr_IDEX_rd);
	flopenrc #(`RFIDX_WIDTH) pr48(clk, reset, ~stall, pr_IDEX_flush, rs1, pr_IDEX_rs1);
	flopenrc #(`RFIDX_WIDTH) pr49(clk, reset, ~stall, pr_IDEX_flush, rs2, pr_IDEX_rs2);
	flopenrc #(`INSTR_SIZE) pr4(clk, reset, ~stall, pr_IDEX_flush, pr_IFID_instr, pr_IDEX_instr);
	flopenrc #(`ADDR_SIZE) pr5(clk, reset, ~stall, pr_IDEX_flush, pr_IFID_pc, pr_IDEX_pc);
	flopenrc #(`ADDR_SIZE) pr6(clk, reset, ~stall, pr_IDEX_flush, pr_IFID_pcplus4, pr_IDEX_pcplus4);
	flopenrc #(`XLEN) pr8(clk, reset, ~stall, pr_IDEX_flush, immout, pr_IDEX_immout);
	flopenrc #(`XLEN) pr9(clk, reset, ~stall, pr_IDEX_flush, rdata1, pr_IDEX_rdata1);
	flopenrc #(`XLEN) pr10(clk, reset, ~stall, pr_IDEX_flush, rdata2, pr_IDEX_rdata2);
	flopenrc #(4) pr11(clk, reset, ~stall, pr_IDEX_flush, aluctrl, pr_IDEX_aluctrl);
	flopenrc #(4) pr12(clk, reset, ~stall, pr_IDEX_flush, branch, pr_IDEX_branch);
	flopenrc #(3) pr13(clk, reset, ~stall, pr_IDEX_flush, lwhbu, pr_IDEX_lwhbu);
	flopenrc #(2) pr14(clk, reset, ~stall, pr_IDEX_flush, swhb, pr_IDEX_swhb);
	flopenrc #(2) pr15(clk, reset, ~stall, pr_IDEX_flush, alusrca, pr_IDEX_alusrca);
	flopenrc #(1) pr16(clk, reset, ~stall, pr_IDEX_flush, alusrcb, pr_IDEX_alusrcb);
	flopenrc #(1) pr18(clk, reset, ~stall, pr_IDEX_flush, memwrite, pr_IDEX_memwrite);
	flopenrc #(1) pr19(clk, reset, ~stall, pr_IDEX_flush, lunsigned, pr_IDEX_lunsigned);
	flopenrc #(1) pr20(clk, reset, ~stall, pr_IDEX_flush, regwrite, pr_IDEX_regwrite);
	flopenrc #(1) pr21(clk, reset, ~stall, pr_IDEX_flush, itype, pr_IDEX_itype);
	flopenrc #(1) pr22(clk, reset, ~stall, pr_IDEX_flush, jalr, pr_IDEX_jalr);
	flopenrc #(1) pr23(clk, reset, ~stall, pr_IDEX_flush, bunsigned, pr_IDEX_bunsigned);
	flopenrc #(1) pr24(clk, reset, ~stall, pr_IDEX_flush, pcsrc, pr_IDEX_pcsrc);
	flopenrc #(1) pr25(clk, reset, ~stall, pr_IDEX_flush, memtoreg, pr_IDEX_memtoreg);
	flopenrc #(1) pr26(clk, reset, ~stall, pr_IDEX_flush, jump, pr_IDEX_jump);
	


	//================================================================================================
	// EX stage
	// forwarding
	// wire [`XLEN-1:0] rdata1_forwardingconsidered;  defined before hazrd detection
	wire [`XLEN-1:0] rdata2_forwardingconsidered, EXMEMwdata, MEMWBwdata, MEMWBwdatasrc;
	mux2 #(`XLEN) forwardMUX1(pr_MEMWB_aluout, pr_MEMWB_readdata, pr_MEMWB_memtoreg, MEMWBwdatasrc);
	mux2 #(`XLEN) forwardMUX2(MEMWBwdatasrc, pr_MEMWB_pcplus4, pr_MEMWB_jump, MEMWBwdata); //jal or jalr
	mux2 #(`XLEN) forwardMUX3(pr_EXMEM_aluout, pr_EXMEM_pcplus4, pr_EXMEM_jump, EXMEMwdata); //jal or jalr
	forwarding forward(
		pr_EXMEM_regwrite, pr_EXMEM_rd, pr_MEMWB_regwrite, pr_MEMWB_rd, pr_IDEX_rs1, pr_IDEX_rs2, pr_IDEX_rdata1, pr_IDEX_rdata2, EXMEMwdata, MEMWBwdata, //wdata is the data to write of MEM hazards 
		pr_MEMWB_memtoreg, pr_EXMEM_memwrite, pr_EXMEM_rs2, pr_MEMWB_readdata, pr_EXMEM_rdata2,
		rdata1_forwardingconsidered, rdata2_forwardingconsidered, memwritedata_forwardingconsidered
	);
	
	// alu
	wire [`XLEN-1:0] alua, alub; //alu source: a,b
	wire [4:0] shiftamount; //shamt
	wire [`XLEN-1:0] aluout;
	mux2 #(5) shamtMUX(rdata2_forwardingconsidered[4:0], pr_IDEX_instr[24:20], pr_IDEX_itype, shiftamount); //if itype:imm ; else:readdata2
	mux3 #(`XLEN) alusrcMUX1(rdata1_forwardingconsidered, 0, pr_IDEX_pc, pr_IDEX_alusrca, alua);
	mux2 #(`XLEN) alusrcMUX2(rdata2_forwardingconsidered, pr_IDEX_immout, pr_IDEX_alusrcb, alub);
	alu 	alu(alua, alub, shiftamount, pr_IDEX_aluctrl, aluout, overflow, zero, lt, ge);


	//================================================================================================
	//EX/MEM pipeline registers	
	flopenrc #(`RFIDX_WIDTH) pr50(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_rs2, pr_EXMEM_rs2);
	flopenrc #(`RFIDX_WIDTH) pr45(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_rd, pr_EXMEM_rd);
	flopenrc #(`ADDR_SIZE) pr27(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_pc, pr_EXMEM_pc);
	flopenrc #(`ADDR_SIZE) pr28(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_pcplus4, pr_EXMEM_pcplus4);
	flopenrc #(`XLEN) pr29(clk, reset, 1'b1, EXMEM_flush, rdata2_forwardingconsidered, pr_EXMEM_rdata2);
	flopenrc #(`XLEN) pr30(clk, reset, 1'b1, EXMEM_flush, aluout, pr_EXMEM_aluout);
	flopenrc #(3) pr31(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_lwhbu, pr_EXMEM_lwhbu);
	flopenrc #(2) pr32(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_swhb, pr_EXMEM_swhb);
	flopenrc #(1) pr33(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_memwrite, pr_EXMEM_memwrite);
	flopenrc #(1) pr34(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_regwrite, pr_EXMEM_regwrite);
	flopenrc #(1) pr35(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_memtoreg, pr_EXMEM_memtoreg);
	flopenrc #(1) pr36(clk, reset, 1'b1, EXMEM_flush, pr_IDEX_jump, pr_EXMEM_jump);



	//================================================================================================
	// MEM stage
	// output: address(read or write), writeenable, writedata (in EX/MEM pipeline registers)
	// input: readdata
	

	//================================================================================================
	// MEM/WB pipeline registers	
	flopenrc #(`RFIDX_WIDTH) pr46(clk, reset, 1'b1, 1'b0, pr_EXMEM_rd, pr_MEMWB_rd);
	flopenrc #(`ADDR_SIZE) pr37(clk, reset, 1'b1, 1'b0, pr_EXMEM_pc, pr_MEMWB_pc);
	flopenrc #(`ADDR_SIZE) pr38(clk, reset, 1'b1, 1'b0, pr_EXMEM_pcplus4, pr_MEMWB_pcplus4);
	flopenrc #(`XLEN) pr39(clk, reset, 1'b1, 1'b0, readdata, pr_MEMWB_readdata);
	flopenrc #(`XLEN) pr40(clk, reset, 1'b1, 1'b0, pr_EXMEM_aluout, pr_MEMWB_aluout);
	flopenrc #(1) pr41(clk, reset, 1'b1, 1'b0, pr_EXMEM_regwrite, pr_MEMWB_regwrite);
	flopenrc #(1) pr42(clk, reset, 1'b1, 1'b0, pr_EXMEM_memtoreg, pr_MEMWB_memtoreg);
	flopenrc #(1) pr43(clk, reset, 1'b1, 1'b0, pr_EXMEM_jump, pr_MEMWB_jump);



	//================================================================================================
	// pc_done to testbench
	flopenrc #(`ADDR_SIZE) pr47(clk, reset, 1'b1, 1'b0, pr_MEMWB_pc, pc_done);

endmodule