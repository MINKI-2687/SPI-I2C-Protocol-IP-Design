`include "uvm_macros.svh"
import uvm_pkg::*;

interface spi_if (input logic clk, input logic reset);
    // [1] 마스터 제어용 외부 포트
    logic       cpol;
    logic       cpha;
    logic [7:0] clk_div;
    logic       start;

    logic [7:0] m_tx_data;  // 마스터가 보낼 데이터
    logic [7:0] m_rx_data;  // 마스터가 받은 데이터
    logic       m_done;
    logic       m_busy;
    // [2] 슬레이브 제어용 외부 포트
    logic [7:0] s_tx_data;  // 슬레이브가 보낼 데이터
    logic [7:0] s_rx_data;  // 슬레이브가 받은 데이터
    logic       s_done;
    logic       s_busy;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output cpol;
        output cpha;
        output clk_div;
        output start;
        output m_tx_data;
        output s_tx_data;

        input  m_rx_data;
        input  m_done;
        input  m_busy;
        input  s_rx_data;
        input  s_done;
        input  s_busy;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input cpol;
        input cpha;
        input clk_div;
        input start;
        input m_tx_data;
        input m_rx_data;
        input m_done;
        input m_busy;
        input s_tx_data;
        input s_rx_data;
        input s_done;
        input s_busy;
    endclocking
endinterface

// 1. Sequence Item
class spi_seq_item extends uvm_sequence_item;
    rand logic [7:0] m_tx_data;
    rand logic [7:0] s_tx_data;
    rand logic [7:0] clk_div;

    logic [7:0] m_rx_data;
    logic [7:0] s_rx_data;

    // Clock Div
    constraint clk_div_dist_c {
        clk_div dist {
            8'd3       := 20,
            8'd20      := 20,
            [8'd4:8'd19] :/ 60
        };
    }
    // M_TX Data
    constraint m_tx_dist_c {
        m_tx_data dist {
            8'h00 := 10,
            8'hFF := 10,
            8'h55 := 15,
            8'hAA := 15,
            8'h01 := 10,
            8'h80 := 10,
            [8'h00:8'hFF] :/ 30
        };
    }
    // S_TX Data
    constraint s_tx_dist_c {
        s_tx_data dist {
            8'h00 := 10,
            8'hFF := 10,
            8'h55 := 15,
            8'hAA := 15,
            8'h01 := 10,
            8'h80 := 10,
            [8'h00:8'hFF] :/ 30
        };
    }

    `uvm_object_utils_begin(spi_seq_item)
    `uvm_field_int(m_tx_data, UVM_ALL_ON)
    `uvm_field_int(s_tx_data, UVM_ALL_ON)
    `uvm_field_int(clk_div,   UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(m_rx_data, UVM_ALL_ON)
    `uvm_field_int(s_rx_data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("Div=%0d | M_TX=0x%02h, M_RX=0x%02h | S_TX=0x%02h, S_RX=0x%02h",
            clk_div, m_tx_data, m_rx_data, s_tx_data, s_rx_data);
    endfunction
endclass

// 2. Sequence
class spi_rand_seq extends uvm_sequence#(spi_seq_item);
    `uvm_object_utils(spi_rand_seq)
    int num_trans = 50; 

    function new(string name = "spi_rand_seq");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        repeat(num_trans) begin
            item = spi_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize()) begin
                `uvm_fatal(get_type_name(), "spi_seq_item randomize() fail!")
            end
            finish_item(item);
        end
    endtask
endclass

// 3. Driver
class spi_driver extends uvm_driver#(spi_seq_item);
    `uvm_component_utils(spi_driver)
    virtual spi_if s_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if))
            `uvm_fatal(get_type_name(), "Cannot find s_if!")
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;

        // 초기화 (Mode 0 강제 고정)
        s_if.drv_cb.cpol  <= 1'b0;
        s_if.drv_cb.cpha  <= 1'b0;
        s_if.drv_cb.start <= 1'b0;

        wait(s_if.reset == 0);
        repeat(3) @(s_if.drv_cb);

        forever begin
            seq_item_port.get_next_item(item);

            // 데이터 
            s_if.drv_cb.clk_div   <= item.clk_div;
            s_if.drv_cb.m_tx_data <= item.m_tx_data;
            s_if.drv_cb.s_tx_data <= item.s_tx_data;
            @(s_if.drv_cb);

            // Start 펄스 발생 (1클럭)
            s_if.drv_cb.start <= 1'b1;
            @(s_if.drv_cb);
            s_if.drv_cb.start <= 1'b0;

            // 통신이 끝날 때까지 대기
            while(!s_if.drv_cb.m_done) @(s_if.drv_cb);

            seq_item_port.item_done();
        end
    endtask
endclass

// 4. Monitor
class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)
    uvm_analysis_port#(spi_seq_item) ap;
    virtual spi_if s_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "s_if", s_if))
            `uvm_fatal(get_type_name(), "Cannot find s_if!")
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;
        forever begin
            @(s_if.mon_cb);
            // SPI 통신은 m_done이 뜨는 순간 양방향 데이터가 완벽히 교환됨을 의미
            if (s_if.mon_cb.m_done) begin
                item = spi_seq_item::type_id::create("item");
                item.clk_div   = s_if.mon_cb.clk_div;
                item.m_tx_data = s_if.mon_cb.m_tx_data;
                item.s_tx_data = s_if.mon_cb.s_tx_data;
                item.m_rx_data = s_if.mon_cb.m_rx_data;
                item.s_rx_data = s_if.mon_cb.s_rx_data;
                ap.write(item);
            end
        end
    endtask
endclass

// 5. Scoreboard 
class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)
    uvm_analysis_imp#(spi_seq_item, spi_scoreboard) ap_imp;

    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(spi_seq_item item);
        // SPI Full-Duplex 교차 검증: 마스터 송신 == 슬레이브 수신 & 슬레이브 송신 == 마스터 수신
        if ((item.m_tx_data !== item.s_rx_data) || (item.s_tx_data !== item.m_rx_data)) begin
            fail_cnt++;
            `uvm_error(get_type_name(), $sformatf("MISMATCH! %s", item.convert2string()))
        end else begin
            pass_cnt++;
            `uvm_info(get_type_name(), $sformatf("MATCH! %s", item.convert2string()), UVM_MEDIUM)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "===== Scoreboard Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Total transactions: %0d",
            pass_cnt + fail_cnt), UVM_LOW)

        `uvm_info(get_type_name(), $sformatf("  Pass: %0d", pass_cnt), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Fail: %0d", fail_cnt), UVM_LOW)
        if (fail_cnt > 0) `uvm_error(get_type_name(), "TEST FAILED!")
        else              `uvm_info(get_type_name(), "TEST PASSED!", UVM_LOW)
    endfunction
endclass

// 6. Coverage
class spi_coverage extends uvm_subscriber#(spi_seq_item);
    `uvm_component_utils(spi_coverage)

    logic [7:0] cov_m_tx;
    logic [7:0] cov_s_tx;
    logic [7:0] cov_clk_div;

    covergroup cg_spi;
        // M_TX coverpoint
        cp_m_tx: coverpoint cov_m_tx {
            bins zero     = {8'h00};
            bins max      = {8'hFF};
            bins alt_55   = {8'h55};
            bins alt_AA   = {8'hAA};
            bins lsb_only = {8'h01};
            bins msb_only = {8'h80};
            bins others   = default;
        }
        // S_TX coverpoint
        cp_s_tx: coverpoint cov_s_tx {
            bins zero     = {8'h00};
            bins max      = {8'hFF};
            bins alt_55   = {8'h55};
            bins alt_AA   = {8'hAA};
            bins lsb_only = {8'h01};
            bins msb_only = {8'h80};
            bins others   = default;
        }
        // clk_div coverpoint
        cp_clk_div: coverpoint cov_clk_div {
            bins fastest = {3};
            bins slowest = {20};
            bins typical = {[4:19]};
        }
        // cross coverage: Hz, data
        cross_speed_m_tx: cross cp_clk_div, cp_m_tx;
        cross_speed_s_tx: cross cp_clk_div, cp_s_tx;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_spi = new();
    endfunction

    function void write(spi_seq_item t);
        cov_m_tx    = t.m_tx_data;
        cov_s_tx    = t.s_tx_data;
        cov_clk_div = t.clk_div;
        cg_spi.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "\n\n===== SPI Coverage Summary =====", UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("     Overall            : %.1f%%", cg_spi.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("     M_TX Data          : %.1f%%", cg_spi.cp_m_tx.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("     S_TX Data          : %.1f%%", cg_spi.cp_s_tx.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("     Clock Div          : %.1f%%",
                cg_spi.cp_clk_div.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("     Cross (Div x M_TX) : %.1f%%",
                cg_spi.cross_speed_m_tx.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(),
            $sformatf("     Cross (Div x S_TX) : %.1f%%",
                cg_spi.cross_speed_s_tx.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), "===== SPI Coverage Summary =====\n\n", UVM_LOW)
    endfunction
endclass

// 7. Agent, Env, Test 
class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)
    spi_driver  drv;
    spi_monitor mon;
    uvm_sequencer#(spi_seq_item) sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = spi_driver::type_id::create("drv", this);
        mon = spi_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(spi_seq_item)::type_id::create("sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)
    spi_agent      agt;
    spi_scoreboard scb;
    spi_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = spi_agent::type_id::create("agt", this);
        scb = spi_scoreboard::type_id::create("scb", this);
        cov = spi_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass

class spi_rand_test extends uvm_test;
    `uvm_component_utils(spi_rand_test)
    spi_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = spi_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        spi_rand_seq seq;
        phase.raise_objection(this);
        seq = spi_rand_seq::type_id::create("seq");
        seq.num_trans = 200;
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask
endclass



module tb_spi ();
    logic clk;
    logic reset;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        repeat(3) @(posedge clk);
        reset = 0;
        @(posedge clk);
    end

    spi_if s_if (.clk(clk), .reset(reset));

    spi_top dut (
        .clk      (clk),
        .reset    (reset),
        .cpol     (s_if.cpol),
        .cpha     (s_if.cpha),
        .clk_div  (s_if.clk_div),
        .start    (s_if.start),
        .m_tx_data(s_if.m_tx_data),
        .m_rx_data(s_if.m_rx_data),
        .m_done   (s_if.m_done),
        .m_busy   (s_if.m_busy),
        .s_tx_data(s_if.s_tx_data),
        .s_rx_data(s_if.s_rx_data),
        .s_done   (s_if.s_done),
        .s_busy   (s_if.s_busy)
    );

    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "*", "s_if", s_if);
        run_test();
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_spi, "+all");
    end
endmodule
