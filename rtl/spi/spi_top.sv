`timescale 1ns / 1ps

module spi_top (
    input logic       clk,
    input logic       reset,
    // [1] 마스터 제어용 외부 포트
    input logic       cpol,
    input logic       cpha,
    input logic [7:0] clk_div,
    input logic       start,

    input  logic [7:0] m_tx_data,  // 마스터가 보낼 데이터
    output logic [7:0] m_rx_data,  // 마스터가 받은 데이터
    output logic       m_done,
    output logic       m_busy,
    // [2] 슬레이브 제어용 외부 포트
    input  logic [7:0] s_tx_data,  // 슬레이브가 보낼 데이터
    output logic [7:0] s_rx_data,  // 슬레이브가 받은 데이터
    output logic       s_done,
    output logic       s_busy
);
    // [3] 내부 배선 (마스터와 슬레이브를 연결하는 SPI 버스)
    logic w_sclk;
    logic w_cs_n;
    logic w_mosi;
    logic w_miso;
    // [4] Master 모듈 인스턴스 (u_master)
    spi_master U_MASTER (
        .clk    (clk),
        .reset  (reset),
        .cpol   (cpol),
        .cpha   (cpha),
        .clk_div(clk_div),
        .start  (start),
        .tx_data(m_tx_data),  // 탑 모듈의 m_tx_data와 연결
        .rx_data(m_rx_data),
        .done   (m_done),
        .busy   (m_busy),
        // 내부 SPI 버스에 연결
        .sclk   (w_sclk),
        .cs_n   (w_cs_n),
        .mosi   (w_mosi),
        .miso   (w_miso)
    );
    // [5] Slave 모듈 인스턴스 (u_slave)
    spi_slave U_SLAVE (
        .clk    (clk),
        .reset  (reset),
        .tx_data(s_tx_data),  // 탑 모듈의 s_tx_data와 연결
        .rx_data(s_rx_data),
        .done   (s_done),
        .busy   (s_busy),
        // 내부 SPI 버스에 연결 (마스터가 만든 선을 그대로 받아먹음)
        .sclk   (w_sclk),
        .cs_n   (w_cs_n),
        .mosi   (w_mosi),
        .miso   (w_miso)
    );

endmodule
