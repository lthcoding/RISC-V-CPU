`include "xgriscv_defines.v"

module hazard_detect(
    // for control hazards
    input [3:0] IDEX_branch,
    input IDEX_jump,
    input IDEX_jalr,
    input [`ADDR_SIZE-1:0] IDEX_pc,
    input [`ADDR_SIZE-1:0] IF_pcplus4,
    input [`XLEN-1:0] IDEX_immout,
    input [`XLEN-1:0] IDEX_rdata1,
    input IDEX_zero,
    input IDEX_lt,

    output reg [`ADDR_SIZE-1:0] nextpc,
    output reg IFID_flush,
    output reg IDEX_flush,
    
    // for data hazards
    input [`RFIDX_WIDTH-1:0] IDEX_rs1,
    input [`RFIDX_WIDTH-1:0] IDEX_rs2,
    input EXMEM_memtoreg,
    input [`RFIDX_WIDTH-1:0] EXMEM_rd,
    
    output reg stall,
    output reg EXMEM_flush,

    // for prediction
    input [1:0] prediction_state,
    output reg [1:0] new_state
);

    //for branch prediction
    reg if_branch;
    
    // -----control hazards-----
    // pc calculation
    wire [`ADDR_SIZE-1:0] jalpc, jalrpc, branchpc;
    addr_adder jalpcadder(IDEX_pc, IDEX_immout[`ADDR_SIZE-1:0], jalpc);
    addr_adder jalrpcadder(IDEX_rdata1[`ADDR_SIZE-1:0], IDEX_immout[`ADDR_SIZE-1:0], jalrpc);
    addr_adder branchpcadder(IDEX_pc, IDEX_immout[`ADDR_SIZE-1:0], branchpc);
    
    // -----data hazards-----
    always @(*) begin
        if(EXMEM_memtoreg && (EXMEM_rd==IDEX_rs1 || EXMEM_rd==IDEX_rs2)) begin
            stall <= 1'b1;
            EXMEM_flush <= 1'b1;
            // when data hazards take place, IF/ID ID/EX should be preserved, not flush
            // so that if detected data hazards, no need to detect control hazards
        end
        else begin
            stall <= 1'b0;
            EXMEM_flush <= 1'b0;
            
            // -----control hazards-----
            if(IDEX_jump == 1'b1) begin
                IFID_flush <= 1'b1;
                IDEX_flush <= 1'b1;
                if_branch <= 1'b0;
                case(IDEX_jalr) 
                        1'b0: nextpc <= jalpc; // jal
                        1'b1: nextpc <= jalrpc; // jalr
                    endcase
            end
            else if(IDEX_branch != 4'b0000) begin
                if((IDEX_branch==4'b1000 && IDEX_zero)||(IDEX_branch==4'b0100 && ~IDEX_lt)||(IDEX_branch==4'b0010 && IDEX_lt)||(IDEX_branch==4'b0001 && ~IDEX_zero))begin
                    nextpc <= branchpc;
                    IFID_flush <= 1'b1;
                    IDEX_flush <= 1'b1;
                    if_branch <= 1'b1;
                end
                else begin
                    nextpc <= IF_pcplus4;
                    IFID_flush <= 1'b0;
                    IDEX_flush <= 1'b0;
                    if_branch <= 1'b0;
                end
            end
            else begin
                nextpc <= IF_pcplus4;
                IFID_flush <= 1'b0;
                IDEX_flush <= 1'b0;
                if_branch <= 1'b0;
            end

        case(if_branch)
            1'b0: case(prediction_state)
                    2'b00: new_state <= 2'b00;
                    2'b01: new_state <= 2'b00;
                    2'b10: new_state <= 2'b11;
                    2'b11: new_state <= 2'b00;
                  endcase
            1'b1: case(prediction_state)
                    2'b00: new_state <= 01;
                    2'b01: new_state <= 10;
                    2'b10: new_state <= 10;
                    2'b11: new_state <= 10;
                  endcase
        endcase

        end
    end


endmodule