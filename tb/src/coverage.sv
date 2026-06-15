class i2c_cov_collector extends uvm_subscriber #(i2c_seq_item);
    `uvm_component_utils(i2c_cov_collector)

    i2c_seq_item txn;

    covergroup i2c_cg;
        option.per_instance = 1;
        option.name = "I2C_Functional_Coverage";

        
        cp_rw: coverpoint txn.read_write {
            bins read  = {1'b1};
            bins write = {1'b0};
        }

        
        cp_addr_match: coverpoint (txn.device_address == txn.dut_address) {
            bins match    = {1'b1};
            bins mismatch = {1'b0};
        }

       
        cp_data_size: coverpoint txn.data.size() {
            bins zero_byte = {0};
            bins single    = {1};
            bins typical   = {[2:7]};
            bins max       = {8};
        }

        
        cp_stop: coverpoint txn.send_stop {
            bins stop_sent               = {1'b1};
            bins repeated_start_intended = {1'b0};
        }

      
        cross_rw_size: cross cp_rw, cp_data_size;
        cross_rw_addr: cross cp_rw, cp_addr_match;
    endgroup

    function new(string name="i2c_cov_collector", uvm_component parent=null);
        super.new(name, parent);
        i2c_cg = new();
    endfunction

    virtual function void write(i2c_seq_item t);
        txn = t;
        i2c_cg.sample();
    endfunction
endclass : i2c_cov_collector


class axi_cov_collector extends uvm_subscriber #(axi_stream_seq_item);
    `uvm_component_utils(axi_cov_collector)

    axi_stream_seq_item pkt;

    covergroup axi_cg;
        option.per_instance = 1;
        option.name = "AXI_Stream_Functional_Coverage";

        cp_data_size: coverpoint pkt.data.size() {
            bins single_byte = {1};
            bins typical     = {[2:7]};
            bins max_burst   = {8};
        }

        
        cp_tready_delay: coverpoint pkt.tready_delay {
            bins no_backpressure = {0};
            bins mild_delay      = {[1:2]};
            bins heavy_delay     = {[3:5]};
        }

        cross_size_delay: cross cp_data_size, cp_tready_delay;
    endgroup

    function new(string name="axi_cov_collector", uvm_component parent=null);
        super.new(name, parent);
        axi_cg = new();
    endfunction

    virtual function void write(axi_stream_seq_item t);
        pkt = t;
        axi_cg.sample();
    endfunction
endclass : axi_cov_collector
