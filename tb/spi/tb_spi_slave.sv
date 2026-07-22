`timescale 1ns / 1ps

module tb_spi_slave ();
    // 시스템 클럭 (100MHz)
    logic       clk;
    logic       reset;
    
    // SPI Bus (Testbench가 Master 역할을 하며 직접 드라이빙)
    logic       sclk;
    logic       cs_n;
    logic       mosi;
    logic       miso;
    
    // Slave 전용 데이터 핀
    logic [7:0] tx_data; // Slave가 Master에게 보내고 싶은 데이터
    logic [7:0] rx_data;
    logic       done;
    logic       busy;

    // 100MHz 시스템 클럭 생성 (1주기 = 10ns)
    always #5 clk = ~clk;

    // DUT (Device Under Test: 우리가 만든 Slave)
    spi_slave dut (
        .clk    (clk),
        .reset  (reset),
        .sclk   (sclk),
        .cs_n   (cs_n),
        .tx_data(tx_data),
        .mosi   (mosi),
        .miso   (miso),
        .rx_data(rx_data),
        .done   (done),
        .busy   (busy)
    );

    // ========================================================
    // [핵심] 가상의 SPI Master Task (Mode 0, 10MHz SCLK 에뮬레이션)
    // ========================================================
    task master_emulate_mode0(input logic [7:0] send_to_slave);
        integer i;
        begin
            // 1. 통신 시작: cs_n을 0으로 떨어뜨림 (Slave 깨우기)
            cs_n = 1'b0;
            #20; // Slave가 반응할 시간(CDC 딜레이)을 약간 줌

            // 2. 8비트 데이터 송수신 반복 (MSB First)
            for (i = 7; i >= 0; i = i - 1) begin
                // [하강 엣지/초기 상태] Master 송신
                mosi = send_to_slave[i];
                #50; // SCLK 반 주기 (50ns) 대기
                
                // [상승 엣지] Master 수신 (Slave가 miso에 올린 값을 읽는 시점)
                sclk = 1'b1;
                // TB에서 miso를 읽고 싶다면 여기서 $display 로 출력 가능
                #50; // SCLK 반 주기 (50ns) 대기
                
                // 다시 하강 엣지 준비
                sclk = 1'b0;
            end
            
            // 3. 통신 종료: cs_n을 1로 복구
            #20; 
            cs_n = 1'b1;
            #50; // 다음 통신까지의 유휴 시간(Idle)
        end
    endtask

    // ========================================================
    // 메인 시나리오 (Stimulus)
    // ========================================================
    initial begin
        // 초기화
        clk     = 0;
        reset   = 1;
        sclk    = 0;  // Mode 0의 기본 클럭 상태 (CPOL=0)
        cs_n    = 1;  // 기본적으로 Slave 선택 해제
        mosi    = 0;
        tx_data = 8'h00; 

        repeat (3) @(posedge clk);
        reset = 0;
        repeat (3) @(posedge clk);

        // 시나리오 1: Master가 8'hA5 (10100101)를 보내고, Slave는 8'h5A (01011010)를 보냄
        $display("--- Test 1 Start ---");
        tx_data = 8'h5A; // Slave가 보낼 데이터를 미리 세팅
        master_emulate_mode0(8'hA5); // Master가 SCLK를 흔들며 8'hA5를 쏨
        
        // 결과 확인
        @(posedge clk);
        if (rx_data == 8'hA5) $display("PASS: Slave correctly received 8'hA5");
        else                  $display("FAIL: Slave received 8'h%h", rx_data);

        // 시나리오 2: 연달아 통신해보기
        $display("--- Test 2 Start ---");
        tx_data = 8'hFF;
        master_emulate_mode0(8'h33);

        #100;
        $finish;
    end
endmodule
