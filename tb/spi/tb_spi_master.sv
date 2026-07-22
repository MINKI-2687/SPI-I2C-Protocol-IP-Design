`timescale 1ns / 1ps

module tb_spi_master ();
    logic       clk;
    logic       reset;
    logic [7:0] clk_div;
    logic [7:0] tx_data;
    logic       start;
    logic [7:0] rx_data;
    logic       done;
    logic       busy;
    logic       sclk;
    logic       mosi;
    logic       miso;
    logic       cs_n;
    logic       cpol;
    logic       cpha;

    always #5 clk = ~clk;

    assign miso = mosi;

    spi_master dut (
        .clk    (clk),
        .reset  (reset),
        .cpol   (cpol),
        .cpha   (cpha),
        .clk_div(clk_div),
        .tx_data(tx_data),
        .start  (start),
        .rx_data(rx_data),
        .done   (done),
        .busy   (busy),
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (cs_n)
    );

    task spi_set_mode(logic [1:0] mode);
        {cpol, cpha} = mode;
        @(posedge clk);
    endtask

    task spi_send_data(logic [7:0] data);
        tx_data = data;
        start   = 1'b1;
        @(posedge clk);
        start = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);
        clk_div = 4;  // SCLK = 10Mhz: (100Mhz / (10Mhz * 2)) - 1
        @(posedge clk);

        spi_set_mode(0);
        spi_send_data(8'h55);

        spi_set_mode(1);
        spi_send_data(8'h55);

        spi_set_mode(2);
        spi_send_data(8'h55);

        spi_set_mode(3);
        spi_send_data(8'h55);

        @(posedge clk);
        #20;
        $finish;

    end
endmodule
