class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    env e;
    function new(string name="base_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); e = env::type_id::create("e",this); endfunction
    function void end_of_elaboration_phase(uvm_phase phase); uvm_top.print_topology(); endfunction
    
    task run_stretch_watchdog(virtual i2c_if vif, string tag="STRETCH_WD");
        time stretch_start, stretch_duration; bit is_stretching = 0;
        forever begin
            @(posedge vif.clk);
            if (vif.scl_i === 1'b1 && vif.scl_o === 1'b0) begin
                if (!is_stretching) begin is_stretching = 1; stretch_start = $time; end
            end else begin
                if (is_stretching) begin
                    stretch_duration = $time - stretch_start;
                    if (stretch_duration > 100) `uvm_info(tag, $sformatf("Clock stretch detected: %0t", stretch_duration), UVM_NONE)
                    is_stretching = 0;
                end
            end
        end
    endtask
endclass : base_test

class write_test extends base_test;
    `uvm_component_utils(write_test)
    function new(string name="write_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_write_seq seq;
        phase.raise_objection(this);
        seq = i2c_write_seq::type_id::create("seq");
        seq.start(e.i2c_agnt.sqr);
        #200; phase.drop_objection(this);
    endtask
endclass

class read_test extends base_test;
    `uvm_component_utils(read_test)
    function new(string name="read_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_read_seq i2c_seq; axi_push_seq axi_seq;
        phase.raise_objection(this);
        i2c_seq = i2c_read_seq::type_id::create("i2c_seq");
        axi_seq = axi_push_seq::type_id::create("axi_seq");
        if (!axi_seq.randomize()) `uvm_fatal("RAND","read_test: axi_seq failed")
        i2c_seq.req_size = axi_seq.pkt_size;
        fork
            begin axi_seq.start(e.s_axis_agnt.sqr); end
            begin #200; i2c_seq.start(e.i2c_agnt.sqr); end
        join
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc06_addr_miss_test extends base_test;
    `uvm_component_utils(tc06_addr_miss_test)
    virtual i2c_if vif;
    function new(string name="tc06_addr_miss_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","tc06: vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_addr_miss_seq seq;
        phase.raise_objection(this);
        seq = i2c_addr_miss_seq::type_id::create("seq");
        fork
            begin seq.start(e.i2c_agnt.sqr); end
            begin
                forever begin
                    @(posedge vif.clk);
                    if (vif.bus_addressed === 1'b1) `uvm_error("TC06","DUT asserted bus_addressed for mismatched address!")
                end
            end
        join_any
        disable fork;
        #200; phase.drop_objection(this);
    endtask
endclass

class tc07_addr_mask_test extends base_test;
    `uvm_component_utils(tc07_addr_mask_test)
    function new(string name="tc07_addr_mask_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_addr_mask_seq seq;
        phase.raise_objection(this);
        seq = i2c_addr_mask_seq::type_id::create("seq");
        seq.start(e.i2c_agnt.sqr);
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc08_write_stretch_test extends base_test;
    `uvm_component_utils(tc08_write_stretch_test)
    virtual i2c_if vif; virtual axi_stream_if m_vif;
    function new(string name="tc08_write_stretch_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","tc08: vif not found"); if (!uvm_config_db #(virtual axi_stream_if)::get(this,"","m_axis_vif",m_vif)) `uvm_fatal("CFG","tc08: m_axis_vif not found"); endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq seq;
        phase.raise_objection(this);
        seq = i2c_nbyte_write_seq::type_id::create("seq"); seq.n_bytes = 8;
        fork
            begin
                fork
                    begin seq.start(e.i2c_agnt.sqr); end
                    begin #15000; m_vif.tready = 1'b0; #10000; m_vif.tready = 1'b1; end
                join
            end
            begin run_stretch_watchdog(vif,"TC08_STRETCH"); end
        join_any
        disable fork;
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc09_read_stretch_test extends base_test;
    `uvm_component_utils(tc09_read_stretch_test)
    virtual i2c_if vif;
    function new(string name="tc09_read_stretch_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","tc09: vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_read_seq i2c_seq; axi_push_seq axi_seq;
        phase.raise_objection(this);
        i2c_seq = i2c_read_seq::type_id::create("i2c_seq"); axi_seq = axi_push_seq::type_id::create("axi_seq");
        if (!axi_seq.randomize()) `uvm_fatal("RAND","tc09: axi_seq failed")
        i2c_seq.req_size = axi_seq.pkt_size;
        fork
            begin
                fork
                    begin i2c_seq.start(e.i2c_agnt.sqr); end
                    begin #5000; axi_seq.start(e.s_axis_agnt.sqr); end
                join
            end
            begin run_stretch_watchdog(vif,"TC09_STRETCH"); end
        join_any
        disable fork;
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc10_axi_backpressure_test extends base_test;
    `uvm_component_utils(tc10_axi_backpressure_test)
    virtual axi_stream_if m_vif;
    function new(string name="tc10_axi_backpressure_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual axi_stream_if)::get(this,"","m_axis_vif",m_vif)) `uvm_fatal("CFG","tc10: m_axis_vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq seq;
        phase.raise_objection(this);
        seq = i2c_nbyte_write_seq::type_id::create("seq"); seq.n_bytes = 8;
        fork
            begin seq.start(e.i2c_agnt.sqr); end
            begin
                m_vif.tready = 1'b1;
                forever begin #($urandom_range(50,400)); m_vif.tready = ~m_vif.tready; end
            end
        join_any
        disable fork;
        m_vif.tready = 1'b1;
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc11_repeated_start_test extends base_test;
    `uvm_component_utils(tc11_repeated_start_test)
    virtual i2c_if vif;
    localparam int WRITE_N = 2; localparam int READ_N  = 2;
    function new(string name="tc11_repeated_start_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","tc11: vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_repeated_start_seq i2c_seq; axi_push_seq axi_seq;
        phase.raise_objection(this);
        i2c_seq = i2c_repeated_start_seq::type_id::create("i2c_seq"); axi_seq = axi_push_seq::type_id::create("axi_seq");
        i2c_seq.write_bytes = WRITE_N; i2c_seq.read_bytes  = READ_N;
        if (!axi_seq.randomize() with { pkt_size == READ_N; }) `uvm_fatal("RAND","tc11: axi_seq failed")
        fork
            begin
                fork
                    begin i2c_seq.start(e.i2c_agnt.sqr); end
                    begin #2000; axi_seq.start(e.s_axis_agnt.sqr); end
                join 
            end
            begin run_stretch_watchdog(vif,"TC11_STRETCH"); end
        join_any
        disable fork;
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc12_rand_burst_write_test extends base_test;
    `uvm_component_utils(tc12_rand_burst_write_test)
    function new(string name="tc12_rand_burst_write_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq seq;
        phase.raise_objection(this);
        repeat(3) begin
            seq = i2c_nbyte_write_seq::type_id::create("seq");
            seq.n_bytes = $urandom_range(2, 8);
            seq.start(e.i2c_agnt.sqr);
        end
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc13_rand_zero_byte_test extends base_test;
    `uvm_component_utils(tc13_rand_zero_byte_test)
    function new(string name="tc13_rand_zero_byte_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_zero_byte_seq seq; i2c_nbyte_write_seq recovery_seq;
        phase.raise_objection(this);
        seq = i2c_zero_byte_seq::type_id::create("seq"); seq.start(e.i2c_agnt.sqr);
        recovery_seq = i2c_nbyte_write_seq::type_id::create("recovery_seq"); recovery_seq.n_bytes = 1; recovery_seq.start(e.i2c_agnt.sqr);
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc14_rand_early_nack_test extends base_test;
    `uvm_component_utils(tc14_rand_early_nack_test)
    function new(string name="tc14_rand_early_nack_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_read_seq i2c_seq; axi_push_seq axi_seq;
        phase.raise_objection(this);
        i2c_seq = i2c_read_seq::type_id::create("i2c_seq"); axi_seq = axi_push_seq::type_id::create("axi_seq");
        if (!axi_seq.randomize() with { pkt_size == 4; }) `uvm_fatal("RAND","tc14: axi_seq failed")
        i2c_seq.req_size = 2;
        fork
            begin axi_seq.start(e.s_axis_agnt.sqr); end
            begin #200; i2c_seq.start(e.i2c_agnt.sqr); end
        join
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc15_rand_axi_starvation_test extends base_test;
    `uvm_component_utils(tc15_rand_axi_starvation_test)
    virtual i2c_if vif;
    function new(string name="tc15_rand_axi_starvation_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_read_seq i2c_seq; axi_push_seq axi_seq1, axi_seq2;
        phase.raise_objection(this);
        i2c_seq  = i2c_read_seq::type_id::create("i2c_seq");
        axi_seq1 = axi_push_seq::type_id::create("axi_seq1"); axi_seq2 = axi_push_seq::type_id::create("axi_seq2");
        if (!axi_seq1.randomize() with { pkt_size == 2; }) `uvm_fatal("RAND","")
        if (!axi_seq2.randomize() with { pkt_size == 2; }) `uvm_fatal("RAND","")
        i2c_seq.req_size = 4;
        fork
            begin
                fork
                    begin i2c_seq.start(e.i2c_agnt.sqr); end
                    begin axi_seq1.start(e.s_axis_agnt.sqr); #5000; axi_seq2.start(e.s_axis_agnt.sqr); end
                join
            end
            begin run_stretch_watchdog(vif,"TC15_STRETCH"); end
        join_any
        disable fork;
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc16_rand_back_to_back_test extends base_test;
    `uvm_component_utils(tc16_rand_back_to_back_test)
    function new(string name="tc16_rand_back_to_back_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq wseq; i2c_read_seq rseq; axi_push_seq axi_seq;
        phase.raise_objection(this);
        wseq = i2c_nbyte_write_seq::type_id::create("wseq1"); wseq.n_bytes = $urandom_range(1, 4); wseq.start(e.i2c_agnt.sqr);
        rseq = i2c_read_seq::type_id::create("rseq"); axi_seq = axi_push_seq::type_id::create("axi_seq");
        if (!axi_seq.randomize() with { pkt_size inside {[1:4]}; }) `uvm_fatal("RAND","tc16 failed")
        rseq.req_size = axi_seq.pkt_size;
        fork
            begin axi_seq.start(e.s_axis_agnt.sqr); end
            begin #200; rseq.start(e.i2c_agnt.sqr); end
        join
        wseq = i2c_nbyte_write_seq::type_id::create("wseq2"); wseq.n_bytes = $urandom_range(1, 4); wseq.start(e.i2c_agnt.sqr);
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc17_rand_sr_stress_test extends base_test;
    `uvm_component_utils(tc17_rand_sr_stress_test)
    virtual i2c_if vif;
    function new(string name="tc17_rand_sr_stress_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_repeated_start_seq i2c_seq; axi_push_seq axi_seq; int wn, rn;
        phase.raise_objection(this);
        repeat(2) begin
            i2c_seq = i2c_repeated_start_seq::type_id::create("i2c_seq"); axi_seq = axi_push_seq::type_id::create("axi_seq");
            wn = $urandom_range(1, 3); rn = $urandom_range(1, 3);
            i2c_seq.write_bytes = wn; i2c_seq.read_bytes  = rn;
            if (!axi_seq.randomize() with { pkt_size == rn; }) `uvm_fatal("RAND","tc17 failed")
            fork
                begin
                    fork
                        begin i2c_seq.start(e.i2c_agnt.sqr); end
                        begin #2000; axi_seq.start(e.s_axis_agnt.sqr); end
                    join
                end
                begin run_stretch_watchdog(vif,"TC17_STRETCH"); end
            join_any
            disable fork;
            #1000;
        end
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc18_rand_max_stress_test extends base_test;
    `uvm_component_utils(tc18_rand_max_stress_test)
    virtual axi_stream_if m_vif;
    function new(string name="tc18_rand_max_stress_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db #(virtual axi_stream_if)::get(this,"","m_axis_vif",m_vif)) `uvm_fatal("CFG","vif not found") endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq wseq;
        phase.raise_objection(this);
        fork
            begin
                repeat(3) begin
                    wseq = i2c_nbyte_write_seq::type_id::create("wseq");
                    wseq.n_bytes = $urandom_range(4, 8);
                    wseq.start(e.i2c_agnt.sqr);
                end
            end
            begin
                m_vif.tready = 1'b1;
                forever begin #($urandom_range(20, 100)); m_vif.tready = ~m_vif.tready; end
            end
        join_any
        disable fork;
        m_vif.tready = 1'b1; 
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

// =============================================================================
// NEW INTEGRATED TESTS (TC20, 21, 22, 23, 25, 26)
// =============================================================================

class tc20_nack_stop_test extends base_test;
    `uvm_component_utils(tc20_nack_stop_test)
    function new(string name="tc20_nack_stop_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_addr_miss_seq nack_seq;
        i2c_nbyte_write_seq recovery_seq;
        phase.raise_objection(this);

        nack_seq = i2c_addr_miss_seq::type_id::create("nack_seq");
        nack_seq.start(e.i2c_agnt.sqr);
        `uvm_info("TC20","NACK transaction done; verifying bus still functional",UVM_NONE)

        #300;
        recovery_seq = i2c_nbyte_write_seq::type_id::create("recovery_seq");
        recovery_seq.n_bytes = 3;
        recovery_seq.start(e.i2c_agnt.sqr);

        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass



class tc21_data_integrity_test extends base_test;
    `uvm_component_utils(tc21_data_integrity_test)
    function new(string name="tc21_data_integrity_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        tc21_data_integrity_seq seq;
        phase.raise_objection(this);
        seq = tc21_data_integrity_seq::type_id::create("seq");
        seq.start(e.i2c_agnt.sqr);
        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc22_continuous_stream_test extends base_test;
    `uvm_component_utils(tc22_continuous_stream_test)
    function new(string name="tc22_continuous_stream_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq seq;
        phase.raise_objection(this);
        repeat(8) begin
            seq = i2c_nbyte_write_seq::type_id::create("seq");
            seq.n_bytes = $urandom_range(1, 8);
            seq.start(e.i2c_agnt.sqr);
            #100; // Minimal inter-frame gap
        end
        phase.phase_done.set_drain_time(this, 4000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc23_extreme_backpressure_test extends base_test;
    `uvm_component_utils(tc23_extreme_backpressure_test)
    virtual i2c_if          vif;
    virtual axi_stream_if   m_vif;
    function new(string name="tc23_extreme_backpressure_test", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","tc23: vif not found")
        if (!uvm_config_db #(virtual axi_stream_if)::get(this,"","m_axis_vif",m_vif)) `uvm_fatal("CFG","tc23: m_axis_vif not found")
    endfunction
    task run_phase(uvm_phase phase);
        i2c_nbyte_write_seq seq;
        phase.raise_objection(this);
        seq = i2c_nbyte_write_seq::type_id::create("seq");
        seq.n_bytes = 8;
        
        fork
            begin
                fork
                    begin seq.start(e.i2c_agnt.sqr); end
                    begin
                        m_vif.tready = 1'b0;
                        `uvm_info("TC23","tready LOW – extreme backpressure start",UVM_NONE)
                        #25000;
                        m_vif.tready = 1'b1;
                        `uvm_info("TC23","tready HIGH – backpressure released",UVM_NONE)
                    end
                join
            end
            begin run_stretch_watchdog(vif,"TC23_STRETCH"); end
        join_any
        disable fork;
        
        phase.phase_done.set_drain_time(this, 4000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc25_stop_mid_transfer_test extends base_test;
    `uvm_component_utils(tc25_stop_mid_transfer_test)
    function new(string name="tc25_stop_mid_transfer_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        tc25_stop_mid_transfer_seq early_seq;
        i2c_nbyte_write_seq        recovery_seq;
        phase.raise_objection(this);

        early_seq = tc25_stop_mid_transfer_seq::type_id::create("early_seq");
        early_seq.stop_after = 2;
        early_seq.start(e.i2c_agnt.sqr);

        `uvm_info("TC25","Early STOP sent; verifying partial delivery and recovery",UVM_NONE)
        #300;

        recovery_seq = i2c_nbyte_write_seq::type_id::create("recovery_seq");
        recovery_seq.n_bytes = 3;
        recovery_seq.start(e.i2c_agnt.sqr);

        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass

class tc26_missing_stop_recovery_test extends base_test;
    `uvm_component_utils(tc26_missing_stop_recovery_test)
    function new(string name="tc26_missing_stop_recovery_test", uvm_component parent=null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        tc26_missing_stop_seq no_stop_seq;
        i2c_nbyte_write_seq follow_seq;
        phase.raise_objection(this);

        no_stop_seq = tc26_missing_stop_seq::type_id::create("no_stop_seq");
        no_stop_seq.start(e.i2c_agnt.sqr);

        `uvm_info("TC26","No-STOP write done; issuing follow-up write (acts as restart)",UVM_NONE)
        #200;

        follow_seq = i2c_nbyte_write_seq::type_id::create("follow_seq");
        follow_seq.n_bytes = 3;
        follow_seq.start(e.i2c_agnt.sqr);

        phase.phase_done.set_drain_time(this, 2000ns);
        #200; phase.drop_objection(this);
    endtask
endclass
