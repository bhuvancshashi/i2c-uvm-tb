class i2c_sequencer extends uvm_sequencer #(i2c_seq_item);
    `uvm_component_utils(i2c_sequencer)
    function new(string name="i2c_sequencer", uvm_component parent=null); super.new(name,parent); endfunction
endclass

class axi_sequencer extends uvm_sequencer #(axi_stream_seq_item);
    `uvm_component_utils(axi_sequencer)
    function new(string name="axi_sequencer", uvm_component parent=null); super.new(name,parent); endfunction
endclass

class i2c_agent extends uvm_agent;
    `uvm_component_utils(i2c_agent)
    i2c_sequencer sqr;
    i2c_driver drv;
    i2c_monitor mon;
    uvm_analysis_port #(i2c_seq_item) ap;
  
    function new(string name="i2c_agent", uvm_component parent=null); 				super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = i2c_monitor::type_id::create("mon",this);
        ap  = new("ap",this);
        sqr = i2c_sequencer::type_id::create("sqr",this);
        drv = i2c_driver::type_id::create("drv",this);
    endfunction
    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
        mon.ap.connect(ap);
    endfunction
endclass : i2c_agent

class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)
    axi_sequencer sqr; axi_driver drv; axi_monitor mon;
    uvm_analysis_port #(axi_stream_seq_item) ap;
    function new(string name="axi_agent", uvm_component parent=null); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = axi_monitor::type_id::create("mon",this);
        ap  = new("ap",this);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = axi_sequencer::type_id::create("sqr",this);
            drv = axi_driver::type_id::create("drv",this);
        end
    endfunction
    function void connect_phase(uvm_phase phase);
        mon.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass : axi_agent

class i2c_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(i2c_scoreboard)

    uvm_tlm_analysis_fifo #(i2c_seq_item)        i2c_fifo;
    uvm_tlm_analysis_fifo #(axi_stream_seq_item) m_axis_fifo;
    uvm_tlm_analysis_fifo #(axi_stream_seq_item) s_axis_fifo;
    uvm_analysis_export #(i2c_seq_item)          i2c_export;
    uvm_analysis_export #(axi_stream_seq_item)   m_axis_export;
    uvm_analysis_export #(axi_stream_seq_item)   s_axis_export;

    int unsigned num_checked, num_passed, num_failed;
    logic [7:0]  axi_bytes_queue[$];

    function new(string name="i2c_scoreboard", uvm_component parent=null); super.new(name,parent); endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        i2c_fifo      = new("i2c_fifo",      this);
        m_axis_fifo   = new("m_axis_fifo",   this);
        s_axis_fifo   = new("s_axis_fifo",   this);
        i2c_export    = new("i2c_export",    this);
        m_axis_export = new("m_axis_export", this);
        s_axis_export = new("s_axis_export", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        i2c_export.connect(i2c_fifo.analysis_export);
        m_axis_export.connect(m_axis_fifo.analysis_export);
        s_axis_export.connect(s_axis_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item        i2c_txn;
        axi_stream_seq_item axi_pkt;
        logic [7:0]         compare_bytes[$];

        forever begin
            i2c_fifo.get(i2c_txn);
            num_checked++;
            `uvm_info("SB", $sformatf("[CHECK #%0d]%s", num_checked, i2c_txn.convert2string()), UVM_NONE)

            if (i2c_txn.data.size() == 0) begin
                `uvm_info("SB","Zero-byte transaction received — no data to score. PASS.",UVM_NONE)
                num_passed++;
                continue;
            end

            compare_bytes = {};

            while (axi_bytes_queue.size() < i2c_txn.data.size()) begin
                if (i2c_txn.read_write == 1'b0) m_axis_fifo.get(axi_pkt);
                else                            s_axis_fifo.get(axi_pkt);
                if (axi_pkt.data.size() == 0) begin
                    `uvm_error("SB_CHK","AXI packet has 0 bytes")
                    num_failed++; continue;
                end
                foreach (axi_pkt.data[i]) axi_bytes_queue.push_back(axi_pkt.data[i]);
            end

            if (axi_bytes_queue.size() > 32) `uvm_warning("SB","AXI queue growing unexpectedly")

            for (int i=0; i < i2c_txn.data.size(); i++) compare_bytes.push_back(axi_bytes_queue.pop_front());

            if (i2c_txn.read_write == 1'b0) check_write(i2c_txn, compare_bytes);
            else                            check_read (i2c_txn, compare_bytes);
        end
    endtask

    task check_write(i2c_seq_item i2c_txn, logic [7:0] compare_bytes[$]);
        if (compare_bytes.size() != i2c_txn.data.size()) begin
            `uvm_error("SB", $sformatf("Length mismatch: AXI=%0d I2C=%0d", compare_bytes.size(), i2c_txn.data.size()))
            num_failed++; return;
        end
        for (int i=0; i < i2c_txn.data.size(); i++) begin
            if (i2c_txn.data[i] !== compare_bytes[i]) begin
                `uvm_error("SB", $sformatf("WRITE mismatch [%0d]: I2C=8'h%0h AXI=8'h%0h", i, i2c_txn.data[i], compare_bytes[i]))
                num_failed++; return;
            end
        end
        `uvm_info("SB", $sformatf("WRITE PASS: %0d bytes", i2c_txn.data.size()), UVM_NONE)
        num_passed++;
    endtask

    task check_read(i2c_seq_item i2c_txn, logic [7:0] compare_bytes[$]);
        if (compare_bytes.size() != i2c_txn.data.size()) begin
            `uvm_error("SB", $sformatf("Length mismatch: AXI=%0d I2C=%0d", compare_bytes.size(), i2c_txn.data.size()))
            num_failed++; return;
        end
        for (int i=0; i < compare_bytes.size(); i++) begin
            if (compare_bytes[i] !== i2c_txn.data[i]) begin
                `uvm_error("SB", $sformatf("READ mismatch [%0d]: AXI=8'h%0h I2C=8'h%0h", i, compare_bytes[i], i2c_txn.data[i]))
                num_failed++; return;
            end
        end
        `uvm_info("SB", $sformatf("READ PASS: %0d bytes", compare_bytes.size()), UVM_NONE)
        num_passed++;
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("\n===== Scoreboard Summary =====\n  Checked:%0d  Passed:%0d  Failed:%0d\n==============================", num_checked, num_passed, num_failed), UVM_NONE)
        if (num_failed > 0) `uvm_error("SB","TEST FAILED")
        else                `uvm_info("SB","TEST PASSED",UVM_NONE)
    endfunction
endclass : i2c_scoreboard

class env extends uvm_env;
    `uvm_component_utils(env)
    
    i2c_agent             i2c_agnt;
    axi_agent             s_axis_agnt, m_axis_agnt;
    i2c_scoreboard        sb;
    
    // Declare the new coverage collectors
    i2c_cov_collector     i2c_cov;
    axi_cov_collector     s_axis_cov;
    axi_cov_collector     m_axis_cov;

    function new(string name="env", uvm_component parent=null); 
        super.new(name,parent); 
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db #(uvm_active_passive_enum)::set(this,"s_axis_agnt","is_active",UVM_ACTIVE);
        uvm_config_db #(uvm_active_passive_enum)::set(this,"m_axis_agnt","is_active",UVM_PASSIVE);
        uvm_config_db #(string)::set(this,"s_axis_agnt.mon","vif_key","s_axis_vif");
      uvm_config_db #(string)::set(this,"m_axis_agnt.mon","vif_key","m_axis_vif");
        
        i2c_agnt    = i2c_agent::type_id::create("i2c_agnt",    this);
        s_axis_agnt = axi_agent::type_id::create("s_axis_agnt", this);
        m_axis_agnt = axi_agent::type_id::create("m_axis_agnt", this);
        sb          = i2c_scoreboard::type_id::create("sb",     this);
        
        // Build the coverage collectors
        i2c_cov     = i2c_cov_collector::type_id::create("i2c_cov", this);
        s_axis_cov  = axi_cov_collector::type_id::create("s_axis_cov", this);
        m_axis_cov  = axi_cov_collector::type_id::create("m_axis_cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Connect to scoreboard
        i2c_agnt.ap.connect(sb.i2c_export);
        m_axis_agnt.ap.connect(sb.m_axis_export);
        s_axis_agnt.ap.connect(sb.s_axis_export);
        
        // Connect analysis ports to the coverage subscribers
        i2c_agnt.ap.connect(i2c_cov.analysis_export);
        s_axis_agnt.ap.connect(s_axis_cov.analysis_export);
        m_axis_agnt.ap.connect(m_axis_cov.analysis_export);
    endfunction
endclass : env
