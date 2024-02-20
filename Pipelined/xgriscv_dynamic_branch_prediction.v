`include "xgriscv_defines.v"

module branch_prediction(
    input [`XLEN-1:0] instr,
    input [`ADDR_SIZE-1:0] pc,
    input [`ADDR_SIZE-1:0] pcplus4,
    input [1:0] state,

    output reg [`ADDR_SIZE-1:0] predicted_pc,
    output reg [1:0] initialized_state
);

    wire [`ADDR_SIZE-1:0] branch_pc_predict;
    addr_adder predictadder(pc, {{{`XLEN-13}{instr[31]}}, {instr[31], instr[7], instr[30:25], instr[11:8]}, 1'b0}, branch_pc_predict);

    always@(*) begin
        if(pc == 32'b0) initialized_state <= 2'b0;
        else initialized_state <= state;
    end

    always@(*) begin
        if(instr[6:0] == `OP_BRANCH)begin
            case(state)
                2'b00: predicted_pc <= pcplus4;
                2'b01: predicted_pc <= pcplus4;
                2'b10: predicted_pc <= branch_pc_predict;
                2'b11: predicted_pc <= branch_pc_predict;
            endcase
        end
        else begin
            predicted_pc <= pcplus4;
        end
    end

endmodule