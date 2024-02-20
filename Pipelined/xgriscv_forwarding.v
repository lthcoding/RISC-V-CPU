`include "xgriscv_defines.v"

module forwarding(
    input EXMEM_regwrite,
    input [4:0] EXMEM_rd,
    input MEMWB_regwrite,
    input [4:0] MEMWB_rd,
    input [4:0] IDEX_rs1,
    input [4:0] IDEX_rs2,
    input [`XLEN-1:0] rdata1,
    input [`XLEN-1:0] rdata2,
    input [`XLEN-1:0] EXMEMwdata,
    input [`XLEN-1:0] MEMWBwdata,

    input MEMWB_memtoreg,
    input EXMEM_memwrite,
    input [`RFIDX_WIDTH-1:0] EXMEM_rs2,
    input [`XLEN-1:0] MEMWB_readdata,
    input [`XLEN-1:0] EXMEM_rdata2,

    output reg [`XLEN-1:0] rdata1_forwardingconsidered,
    output reg [`XLEN-1:0] rdata2_forwardingconsidered,
    output reg [`XLEN-1:0] memwritedata_forwardingconsidered
);

    always @(*) begin
        //----------------------------------------------------------
        // CAUTION: consider the sequence of instructions below:
        // add x1, x1, x2
        // add x1, x1, x3   --EX hazard
        // add x1, x1, x4   --also EX hazard but also meet the conditions of MEM hazard
        // don't need to add extra conditions to the MEM hazard because of the if block
        // judge EX hazards first and if EX hazards detected, won't calculate the conditions of MEM hazards.
        //----------------------------------------------------------
        if(EXMEM_regwrite && EXMEM_rd!=5'b00000 && EXMEM_rd==IDEX_rs1) begin
            rdata1_forwardingconsidered <= EXMEMwdata;
        end
        else if(MEMWB_regwrite && MEMWB_rd!=5'b00000 && MEMWB_rd==IDEX_rs1) begin
            rdata1_forwardingconsidered <= MEMWBwdata;
        end
        else begin
            rdata1_forwardingconsidered <= rdata1;
        end
        
        if(EXMEM_regwrite && EXMEM_rd!=5'b00000 && EXMEM_rd==IDEX_rs2) begin
            rdata2_forwardingconsidered <= EXMEMwdata;
        end
        else if(MEMWB_regwrite && MEMWB_rd!=5'b00000 && MEMWB_rd==IDEX_rs2) begin
            rdata2_forwardingconsidered <= MEMWBwdata;
        end
        else begin
            rdata2_forwardingconsidered <= rdata2;
        end
    
        if(MEMWB_memtoreg && EXMEM_memwrite && MEMWB_rd==EXMEM_rs2) begin
            memwritedata_forwardingconsidered <= MEMWB_readdata;
        end
        else begin
            memwritedata_forwardingconsidered <= EXMEM_rdata2;
        end
    end
endmodule
