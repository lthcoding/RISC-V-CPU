`include "xgriscv_defines.v"

// pc register with write enable
module pcenr (
	input             		clk, reset,
	input             		en,
	input      [`XLEN-1:0]	d, 
	output reg [`XLEN-1:0]	q);
 
	always @(posedge clk, posedge reset)
	// if      (reset) q <= 0;
    if (reset) 
    	q <= `ADDR_SIZE'h00000000 ;
    else if (en)    
    	q <=  d;
endmodule

// adder for address calculation
module addr_adder (
	input  [`ADDR_SIZE-1:0] a, b,
	output [`ADDR_SIZE-1:0] y);

	assign  y = a + b;
endmodule

// flop with reset and clear control
module floprc #(parameter WIDTH = 8)
              (input                  clk, reset, clear,
               input      [WIDTH-1:0] d, 
               output reg [WIDTH-1:0] q);

  always @(posedge clk, posedge reset)
    if (reset)      q <= 0;
    else if (clear) q <= 0;
    else            q <= d;
endmodule

// flop with reset, enable and clear control
module flopenrc #(parameter WIDTH = 8)
                 (input                  clk, reset,
                  input                  en, clear,
                  input      [WIDTH-1:0] d, 
                  output reg [WIDTH-1:0] q);
 
  always @(posedge clk, posedge reset)
    if      (reset) q <= 0;
    else if (clear) q <= 0;
    else if (en)    q <= d;
endmodule

// flop with reset and enable control
module flopenr #(parameter WIDTH = 8)
                (input                  clk, reset,
                 input                  en,
                 input      [WIDTH-1:0] d, 
                 output reg [WIDTH-1:0] q);
 
  always @(posedge clk, posedge reset)
    if      (reset) q <= 0;
    else if (en)    q <=  d;
endmodule

module mux2 #(parameter WIDTH = 8)
             (input  [WIDTH-1:0] d0, d1, 
              input              s, 
              output [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
             (input  [WIDTH-1:0] d0, d1, d2,
              input  [1:0]       s, 
              output [WIDTH-1:0] y);

  assign  y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

module mux4 #(parameter WIDTH = 8)
             (input  [WIDTH-1:0] d0, d1, d2, d3,
              input  [1:0]       s, 
              output reg [WIDTH-1:0] y);

	always @( * )
	begin
      case(s)
         2'b00: y <= d0;
         2'b01: y <= d1;
         2'b10: y <= d2;
         2'b11: y <= d3;
      endcase
	end
endmodule

module mux5 #(parameter WIDTH = 8)
             (input		[WIDTH-1:0] d0, d1, d2, d3, d4,
              input		[2:0]       s, 
              output reg	[WIDTH-1:0] y);

	always @( * )
	begin
      case(s)
	    3'b000: y <= d0;
	    3'b001: y <= d1;
	    3'b010: y <= d2;
	    3'b011: y <= d3;
	    3'b100: y <= d4;
      endcase
//    $display("mux5 d0=%h, d1=%h, d2=%h, d3=%h, d4=%h, s=%b, y=%h", d0,d1,d2,d3,d4,s,y);
    end  
endmodule

module mux6 #(parameter WIDTH = 8)
           (input  [WIDTH-1:0] 	d0, d1, d2, d3, d4, d5,
            input  [2:0] 		s,
         	  output reg [WIDTH-1:0]	y);

	always@( * )
	begin
	  case(s)
		3'b000: y <= d0;
		3'b001: y <= d1;
		3'b010: y <= d2;
		3'b011: y <= d3;
		3'b100: y <= d4;
		3'b101: y <= d5;
	  endcase
	end
endmodule

module imm (
	input	[11:0]			iimm, //instr[31:20], 12 bits
	input	[11:0]			simm, //instr[31:25, 11:7], 12 bits
	input	[11:0]			bimm, //instrD[31], instrD[7], instrD[30:25], instrD[11:8], 12 bits
	input	[19:0]			uimm,
	input	[19:0]			jimm,
	input	[4:0]			 immctrl,

	output	reg [`XLEN-1:0] 	immout);
  always  @(*)
	 case (immctrl)
		`IMM_CTRL_ITYPE:	immout <= {{{`XLEN-12}{iimm[11]}}, iimm[11:0]};
		`IMM_CTRL_UTYPE:	immout <= {uimm[19:0], 12'b0};
    `IMM_CTRL_JTYPE:	immout <= {{{`XLEN-21}{jimm[19]}}, jimm[19:0], 1'b0};
    `IMM_CTRL_BTYPE:  immout <= {{{`XLEN-13}{bimm[11]}}, bimm[11:0], 1'b0};
    `IMM_CTRL_STYPE:  immout <= {{{`XLEN-12}{simm[11]}}, simm[11:0]};
		default:			      immout <= `XLEN'b0;
	 endcase
endmodule

// shift left by 1 for address calculation
module sl1(
	input  [`ADDR_SIZE-1:0] a,
	output [`ADDR_SIZE-1:0] y);

  assign  y = {a[`ADDR_SIZE-2:0], 1'b0};
endmodule

// comparator for branch
module cmp(
  input [`XLEN-1:0] a, b,
  input             op_unsigned,
  output            zero,
  output            lt);

  assign zero = (a == b);
  assign lt = (!op_unsigned & ($signed(a) < $signed(b))) | (op_unsigned & (a < b));
endmodule

// choose next pc (branch or not)
module branchaddrmux(
  input [3:0] branch,
  input zero, lt,
  input [`ADDR_SIZE-1:0] branchpc, pcexceptbranch,
  output reg [`ADDR_SIZE-1:0] nextpc
);
  always  @(*)
	 case (branch)
		4'b1000:if(zero)  begin nextpc <= branchpc; end
            else      begin nextpc <= pcexceptbranch; end
    4'b0100:if(~lt)   begin nextpc <= branchpc; end
            else      begin nextpc <= pcexceptbranch; end
    4'b0010:if(lt)    begin nextpc <= branchpc; end
            else      begin nextpc <= pcexceptbranch; end
    4'b0001:if(~zero) begin nextpc <= branchpc; end
            else      begin nextpc <= pcexceptbranch; end
		default:			          nextpc <= pcexceptbranch;
	 endcase
endmodule

module ampattern (input [1:0] addr, input [1:0] swhb, output reg [3:0] amp); //amp: access memory pattern
  always@(*)
  case (swhb)
    2'b01: amp <= 4'b1111; //sw
    2'b10: if (addr[1]) amp <= 4'b1100;  //sh
           else         amp <= 4'b0011; //addr[0]
    2'b11: case (addr)  //sb
              2'b00: amp <= 4'b0001;
              2'b01: amp <= 4'b0010;
              2'b10: amp <= 4'b0100;
              2'b11: amp <= 4'b1000;
           endcase
    default: amp <= 4'b1111;// it shouldn't happen
  endcase
endmodule

// process data from DMEM according to different types of load instructions
module dmemloaddatamux(
  input [`XLEN-1:0] addr,
  input [2:0] lwhbu,
  input [`XLEN-1:0] rdata,
  output reg [`XLEN-1:0] outdata
);
  always@(*)
  case(lwhbu)
    3'b010: outdata <= rdata; //lw
    3'b100: case(addr[1:0]) //lh
              2'b00: outdata <= {{16{rdata[31]}},rdata[15:0]};
              2'b10: outdata <= {{16{rdata[31]}},rdata[31:16]};
              default: outdata <= {{16{rdata[31]}},rdata[15:0]};
            endcase
    3'b110: case(addr[1:0]) //lb
                2'b00: outdata <= {{24{rdata[31]}},rdata[7:0]};
                2'b01: outdata <= {{24{rdata[31]}},rdata[15:8]};
                2'b10: outdata <= {{24{rdata[31]}},rdata[23:16]};
                2'b11: outdata <= {{24{rdata[31]}},rdata[31:24]};
                default: outdata <= {{24{rdata[31]}},rdata[7:0]};
            endcase
    3'b101: case(addr[1:0]) //lhu
              2'b00: outdata <= {{16'b0},rdata[15:0]};
              2'b10: outdata <= {{16'b0},rdata[31:16]};
              default: outdata <= {{16'b0},rdata[15:0]};
            endcase
    3'b011: case(addr[1:0]) //lbu
                2'b00: outdata <= {{24'b0},rdata[7:0]};
                2'b01: outdata <= {{24'b0},rdata[15:8]};
                2'b10: outdata <= {{24'b0},rdata[23:16]};
                2'b11: outdata <= {{24'b0},rdata[31:24]};
                default: outdata <= {{24'b0},rdata[7:0]};
            endcase
    default: outdata <= rdata;
  endcase
endmodule