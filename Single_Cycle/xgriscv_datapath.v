`include "xgriscv_defines.v"

module datapath(
	input						clk, reset,

	input [`INSTR_SIZE-1:0]		instr,
	output[`ADDR_SIZE-1:0]		pc,

	input [`XLEN-1:0]			readdata, 	// from data memory: read data
	output[`XLEN-1:0]			aluout,		// to data memory: address
 	output[`XLEN-1:0]			writedata, 	// to data memory: write data
	
	// from controller
	input [4:0]		            immctrl,
	input			            itype, jal, jalr, bunsigned, pcsrc,
	input [3:0]		            aluctrl,
	input [1:0]		            alusrca,
	input			            alusrcb,
	input						memwrite, lunsigned,
	input          		        memtoreg, regwrite,
	input [3:0]					branch,
	
  	// to controller
	output [6:0]				op,
	output [2:0]				funct3,
	output [6:0]				funct7,
	output [4:0]				rd, rs1,
	output [11:0]  		        immD,
	output 	       		        zero, lt
	);


	wire [`RFIDX_WIDTH-1:0] 	rs2;
	assign  op		= instr[6:0];
	assign  rd		= instr[11:7];
	assign  funct3	= instr[14:12];
	assign  rs1		= instr[19:15];
	assign  rs2   	= instr[24:20];
	assign  funct7	= instr[31:25];
	assign  imm		= instr[31:20];

	// immediate generation
	wire [11:0]				iimm = instr[31:20];
	wire [11:0]				simm	= {instr[31:25],instr[11:7]};
	wire [11:0]  			bimm	= {instr[31], instr[7], instr[30:25], instr[11:8]};
	wire [19:0]				uimm	= instr[31:12];
	wire [19:0]  			jimm	= {instr[31], instr[19:12], instr[20], instr[30:21]};
	wire [`XLEN-1:0]		immout, shftimm;
	wire [`XLEN-1:0]		rdata1, rdata2, wdata;
	wire [`RFIDX_WIDTH-1:0]	waddr = rd;

	imm 	im(iimm, simm, bimm, uimm, jimm, immctrl, immout);

	// pc
	wire stall = 1'b0;
	wire [`ADDR_SIZE-1:0] pcplus4, pcexceptbranch, nextpc, jumppc, jumppcplusbias, branchpc; //nextpc为下条指令地址
	// jump(jal or jalr)
	wire [`ADDR_SIZE-1:0] readaddr = rdata1[`ADDR_SIZE-1:0];
	wire [`ADDR_SIZE-1:0] immaddrbias = immout[`ADDR_SIZE-1:0];
	mux2 #(`ADDR_SIZE) jumppcsrcMUX(pc, readaddr, jalr, jumppc);
	addr_adder jumppcadder(jumppc, immaddrbias, jumppcplusbias);
	//branch
	wire [`ADDR_SIZE-1:0] branchpcbias = immout[`ADDR_SIZE-1:0];
	addr_adder branchpcadder(pc, branchpcbias, branchpc);
	cmp cmpforbranch(rdata1, rdata2, bunsigned, zero, lt);
	// choose next pc
	mux2 #(`ADDR_SIZE) pcMUX(pcplus4, jumppcplusbias, pcsrc, pcexceptbranch); //decide jump or +=4
	//decide if branch
	branchaddrmux branchpcMUX(branch, zero, lt, branchpc, pcexceptbranch, nextpc);
	//update pc
	pcenr pcenr1(clk, reset, ~stall, nextpc, pc);
	addr_adder pcadder(pc, `ADDR_SIZE'b100, pcplus4);

	// register file
	wire [`XLEN-1:0] wdatasrc;
	mux2 #(`XLEN) wdataMUX1(aluout, readdata, memtoreg, wdatasrc);
	mux2 #(`XLEN) wdataMUX2(wdatasrc, pcplus4, jal, wdata); //jal or jalr
	regfile rf(clk, rs1, rs2, rdata1, rdata2, regwrite, waddr, wdata);

	// alu
	wire [`XLEN-1:0] alua, alub; //a,b
	wire [4:0] shiftamount; //shamt
	mux2 #(5) shamtMUX(rdata2[4:0], instr[24:20], itype, shiftamount); //if itype:imm ; else:readdata2
	mux3 #(`XLEN) alusrcMUX1(rdata1, 0, pc, alusrca, alua);
	mux2 #(`XLEN) alusrcMUX2(rdata2, immout, alusrcb, alub);
	alu 	alu(alua, alub, shiftamount, aluctrl, aluout, overflow, zero, lt, ge);

	//load & store
	assign writedata = rdata2;

endmodule