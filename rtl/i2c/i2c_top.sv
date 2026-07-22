`timescale 1ns / 1ps

module i2c_top (
    input  logic       clk,
    input  logic       reset,
    // Master User Interface (마스터 측 CPU와 연결)
    input  logic       mst_cmd_start,
    input  logic       mst_cmd_write,
    input  logic       mst_cmd_read,
    input  logic       mst_cmd_stop,
    input  logic [7:0] mst_tx_data,
    input  logic       mst_ack_in,
    output logic [7:0] mst_rx_data,
    output logic       mst_done,
    output logic       mst_busy,
    output logic       mst_ack_out,
    // Slave User Interface (슬레이브 측 CPU와 연결)
    input  logic [7:0] slv_tx_data,
    input  logic       slv_ack_in,
    output logic [7:0] slv_rx_data,
    output logic       slv_ack_out,
    output logic       slv_rx_done,
    output logic       slv_tx_req,
    output logic       slv_busy,
    // Physical I2C Bus (파형 측정 및 풀업용)
    inout  wire        sda,
    output wire        scl
);
    wire slv_sda_o;

    // Slave의 inout 제어 (Master와 동일한 원리)
    assign sda = slv_sda_o ? 1'bz : 1'b0;

    I2C_Master u_master (
        .clk      (clk),
        .reset    (reset),
        .cmd_start(mst_cmd_start),
        .cmd_write(mst_cmd_write),
        .cmd_read (mst_cmd_read),
        .cmd_stop (mst_cmd_stop),
        .tx_data  (mst_tx_data),
        .ack_in   (mst_ack_in),
        .rx_data  (mst_rx_data),
        .done     (mst_done),
        .busy     (mst_busy),
        .ack_out  (mst_ack_out),
        .sda      (sda),            // 내부 버스 연결
        .scl      (scl)             // 내부 버스 연결
    );
    i2c_slave #(
        .SLAVE_ADDR(7'h12)
    ) u_slave (
        .clk    (clk),
        .reset  (reset),
        .tx_data(slv_tx_data),
        .ack_in (slv_ack_in),
        .rx_data(slv_rx_data),
        .ack_out(slv_ack_out),
        .rx_done(slv_rx_done),
        .tx_req (slv_tx_req),
        .busy   (slv_busy),
        .scl    (scl),
        .sda_i  (sda),
        .sda_o  (slv_sda_o)
    );
endmodule
