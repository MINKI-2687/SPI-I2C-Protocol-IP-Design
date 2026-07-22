`timescale 1ns / 1ps
module tb_spi_top ();
    logic       clk;
    logic       reset;
    logic       cpol;
    logic       cpha;
    logic [7:0] clk_div;
    logic       start;
    logic [7:0] m_tx_data;  // 마스터가 보낼 데이터
    logic [7:0] m_rx_data;  // 마스터가 받은 데이터
    logic       m_done;
    logic       m_busy;
    logic [7:0] s_tx_data;  // 슬레이브가 보낼 데이터
    logic [7:0] s_rx_data;  // 슬레이브가 받은 데이터
    logic       s_done;
    logic       s_busy;

    spi_top dut (.*);

    always #5 clk = ~clk;

    initial begin
        // ==========================================
        // 1. 초기화 및 리셋 (Initialization & Reset)
        // ==========================================
        clk       = 0;
        reset     = 1;
        start     = 0;
        cpol      = 0;  // 슬레이브가 Mode 0 전용이므로 무조건 0
        cpha      = 0;  // 무조건 0
        clk_div   = 4;  // 100MHz 시스템 클럭 -> 10MHz SCLK ( (100/(10*2)) - 1 )
        m_tx_data = 8'h00;
        s_tx_data = 8'h00;

        repeat (5) @(posedge clk);
        reset = 0; // 리셋 해제
        repeat (5) @(posedge clk);

        $display("========================================");
        $display(" SPI Top-level Integration Test Started");
        $display("========================================");

        // ==========================================
        // 2. 첫 번째 통신 테스트: A5 <-> C3 교환
        // ==========================================
        $display("[Test 1] Master sends 8'hA5, Slave sends 8'hC3");
        
        // 마스터와 슬레이브 양쪽의 송신 버퍼에 데이터를 장전!
        m_tx_data = 8'hA5; // 1010_0101
        s_tx_data = 8'hC3; // 1100_0011
        @(posedge clk);

        // 마스터에게 "통신 시작!" 명령 (1클럭 펄스)
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // 마스터가 통신을 끝내고 done 플래그를 띄울 때까지 무한 대기
        wait (m_done == 1'b1);
        @(posedge clk);

        // 결과 검증 (Self-Checking)
        if (s_rx_data == 8'hA5 && m_rx_data == 8'hC3) begin
            $display("  -> [PASS] Data exchanged perfectly!");
        end else begin
            $display("  -> [FAIL] Expected M:C3, S:A5 / Got M:%h, S:%h", m_rx_data, s_rx_data);
        end

        // ==========================================
        // 3. 두 번째 통신 테스트: 55 <-> AA 교환 (연속 통신)
        // ==========================================
        #100; // 잠시 쉬었다가 다음 통신
        $display("[Test 2] Master sends 8'h55, Slave sends 8'hAA");
        
        m_tx_data = 8'h55; 
        s_tx_data = 8'hAA; 
        @(posedge clk);

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (m_done == 1'b1);
        @(posedge clk);

        if (s_rx_data == 8'h55 && m_rx_data == 8'hAA) begin
            $display("  -> [PASS] Data exchanged perfectly!");
        end else begin
            $display("  -> [FAIL] M:%h, S:%h", m_rx_data, s_rx_data);
        end

        // 시뮬레이션 종료
        #200;
        $display("========================================");
        $display(" All Tests Completed.");
        $display("========================================");
        $finish;
    end

endmodule
