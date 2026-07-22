`timescale 1ns / 1ps

module spi_slave (
    input  logic       clk,
    input  logic       reset,
    input  logic       sclk,
    input  logic       cs_n,
    input  logic [7:0] tx_data,
    input  logic       mosi,
    output logic       miso,
    output logic [7:0] rx_data,
    output logic       done,
    output logic       busy
);
    typedef enum logic {
        IDLE = 1'b0,
        DATA
    } spi_state_e;

    spi_state_e       state;
    logic       [7:0] tx_shift_reg;
    logic       [7:0] rx_shift_reg;
    logic       [2:0] bit_cnt;
    logic             miso_r;
    logic       [2:0] sclk_sync;
    logic       [2:0] cs_n_sync;
    logic             sclk_rising_edge;
    logic             sclk_falling_edge;
    logic             cs_n_rising_edge;
    logic             cs_n_falling_edge;

    assign miso = (!cs_n) ? miso_r : 1'bz;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 3'b111;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_n_sync <= {cs_n_sync[1:0], cs_n};
        end
    end

    assign sclk_rising_edge  = (sclk_sync[2:1] == 2'b01);
    assign sclk_falling_edge = (sclk_sync[2:1] == 2'b10);

    assign cs_n_falling_edge = (cs_n_sync[2:1] == 2'b10);
    assign cs_n_rising_edge  = (cs_n_sync[2:1] == 2'b01);

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            miso_r       <= 1'b1;
            rx_data      <= 0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
            done         <= 1'b0;
            busy         <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    miso_r  <= 1'b1;
                    bit_cnt <= 0;
                    if (cs_n_falling_edge) begin
                        state        <= DATA;
                        busy         <= 1'b1;
                        miso_r       <= tx_data[7];
                        tx_shift_reg <= {tx_data[6:0], 1'b0};
                    end
                end
                DATA: begin
                    if (sclk_rising_edge) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], mosi};
                        if (bit_cnt == 7) begin
                            state   <= IDLE;
                            done    <= 1'b1;
                            busy    <= 1'b0;
                            rx_data <= {rx_shift_reg[6:0], mosi};
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else if (sclk_falling_edge) begin
                        //if (bit_cnt < 7) begin
                            miso_r       <= tx_shift_reg[7];
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        //end
                    end
                    if (cs_n_rising_edge) begin
                        state <= IDLE;
                        busy  <= 1'b0;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
