`timescale 1ns / 1ps

module I2C_Master (
    input  logic       clk,
    input  logic       reset,
    // command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       busy,
    output logic       ack_out,
    // external i2c port
    inout  logic       sda,
    output logic       scl
);

    logic sda_o, sda_i;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    i2c_master u_i2c_master (.*);
endmodule

module i2c_master (
    input  logic       clk,
    input  logic       reset,
    // command port
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       busy,
    output logic       ack_out,
    // external i2c port
    input  logic       sda_i,
    output logic       sda_o,
    output logic       scl
);

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        START,
        WAIT_CMD,
        DATA,
        DATA_ACK,
        STOP
    } i2c_state_e;
    i2c_state_e       state;

    logic       [7:0] div_cnt;
    logic             qtr_tick;
    logic             scl_r;
    logic             sda_r;
    logic       [1:0] step;
    logic       [7:0] tx_shift_reg;
    logic       [7:0] rx_shift_reg;
    logic       [2:0] bit_cnt;
    logic             is_read;
    logic             ack_in_r;
    // synchronizer
    logic       [1:0] sda_sync;
    logic             sda_safe;

    assign scl   = scl_r;
    assign sda_o = sda_r;
    assign busy  = (state != IDLE);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            div_cnt  <= 0;
            qtr_tick <= 1'b0;
        end else begin
            if (div_cnt == 250 - 1) begin  // scl : 100khz
                div_cnt  <= 0;
                qtr_tick <= 1'b1;
            end else begin
                div_cnt  <= div_cnt + 1;
                qtr_tick <= 1'b0;
            end
        end
    end
    // synchronizer
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sda_sync <= 2'b11;
        end else begin
            sda_sync <= {sda_sync[0], sda_i};
        end
    end
    assign sda_safe = sda_sync[1];
    //
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            //busy         <= 1'b0;
            step         <= 0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
            is_read      <= 1'b0;
            ack_in_r     <= 1'b1;
            ack_out      <= 1'b1;
            rx_data      <= 0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    //busy  <= 1'b0;
                    if (cmd_start) begin
                        state <= START;
                        step  <= 0;
                        //busy  <= 1'b1;
                    end
                end
                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: step <= 2'd1;
                            2'd1: step <= 2'd2;
                            2'd2: step <= 2'd3;
                            2'd3: begin
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                WAIT_CMD: begin
                    step <= 0;
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 0;
                        is_read      <= 1'b0;
                        state        <= DATA;
                    end else if (cmd_read) begin
                        rx_shift_reg <= 0;
                        bit_cnt      <= 0;
                        is_read      <= 1'b1;
                        state        <= DATA;
                        ack_in_r     <= ack_in;
                    end else if (cmd_stop) begin
                        state <= STOP;
                    end else if (cmd_start) begin
                        state <= START;
                    end
                end
                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: step <= 2'd1;
                            2'd1: step <= 2'd2;
                            2'd2: begin
                                if (is_read) begin
                                    rx_shift_reg <= {
                                        rx_shift_reg[6:0], sda_safe
                                    };
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                if (!is_read) begin
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                                step <= 2'd0;
                                if (bit_cnt == 7) begin
                                    state <= DATA_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt + 1;
                                end
                            end
                        endcase
                    end
                end
                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: step <= 2'd1;
                            2'd1: step <= 2'd2;
                            2'd2: begin
                                if (!is_read) begin  // slv -> mst send ack
                                    ack_out <= sda_safe;
                                end
                                if (is_read) begin
                                    rx_data <= rx_shift_reg;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: step <= 2'd1;
                            2'd1: step <= 2'd2;
                            2'd2: step <= 2'd3;
                            2'd3: begin
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always_comb begin
        sda_r = 1'b1;
        scl_r = 1'b1;
        case (state)
            IDLE: begin
                sda_r = 1'b1;
                scl_r = 1'b1;
            end
            START: begin
                if (step != 2'd0) sda_r = 1'b0;
                else sda_r = 1'b1;
                if (step == 2'd3) scl_r = 1'b0;
                else scl_r = 1'b1;
            end
            WAIT_CMD: begin
                sda_r = 1'b0;
                scl_r = 1'b0;
            end
            DATA: begin
                if (is_read) sda_r = 1'b1;
                else sda_r = tx_shift_reg[7];
                if (step == 2'd1 | step == 2'd2) scl_r = 1'b1;
                else scl_r = 1'b0;
            end
            DATA_ACK: begin
                if (is_read) sda_r = ack_in_r;
                else sda_r = 1'b1;  // sda input, high z setting
                if (step == 2'd1 | step == 2'd2) scl_r = 1'b1;
                else scl_r = 1'b0;
            end
            STOP: begin
                if (step == 2'd0 | step == 2'd1) sda_r = 1'b0;
                else sda_r = 1'b1;
                if (step == 2'd0) scl_r = 1'b0;
                else scl_r = 1'b1;
            end
        endcase
    end
endmodule
