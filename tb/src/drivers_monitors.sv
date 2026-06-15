class i2c_driver extends uvm_driver #(i2c_seq_item);
    `uvm_component_utils(i2c_driver)

    parameter int SCL_HALF_PERIOD = 25;
    virtual i2c_if vif;

    function new(string name="i2c_driver", uvm_component parent=null); 
        super.new(name,parent); 
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) 
            `uvm_fatal("CFG","i2c_driver: vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item txn;
        
        // Initialize Master State (Release the bus)
        vif.master_cb.m_scl_drive_low <= 1'b0; 
        vif.master_cb.m_sda_drive_low <= 1'b0;
        
        vif.master_cb.enable              <= 1'b1;
        vif.master_cb.release_bus         <= 1'b0;
        vif.master_cb.device_address      <= 7'h55;
        vif.master_cb.device_address_mask <= 7'h7F;
        
        forever begin
            seq_item_port.get_next_item(txn);
            `uvm_info("I2C_DRV", $sformatf("[DRIVING]%s", txn.convert2string()), UVM_NONE)
            
            vif.master_cb.device_address      <= txn.dut_address;
            vif.master_cb.device_address_mask <= txn.dut_mask;
            vif.master_cb.enable              <= txn.enable;
            @(vif.master_cb);
            
            drive_transaction(txn);
            
            `uvm_info("I2C_DRV","[DONE]",UVM_NONE)
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(i2c_seq_item txn);
        logic nack;
        send_start();
        send_byte({txn.device_address, txn.read_write});
        receive_ack(nack);
        if (nack) begin
            `uvm_info("I2C_DRV","Address NACK. Issuing STOP.",UVM_NONE)
            send_stop(); 
            return;
        end
        if (!txn.read_write) begin
            foreach (txn.data[i]) begin
                send_byte(txn.data[i]);
                receive_ack(nack);
                if (nack) begin
                    `uvm_error("I2C_DRV","Unexpected NACK during WRITE phase")
                    break;
                end
            end
        end else begin
            foreach (txn.data[i]) begin
                receive_byte(txn.data[i]);
                send_ack((i == txn.data.size()-1) ? 1'b1 : 1'b0);
            end
        end
        if (txn.send_stop) send_stop();
    endtask

    task cb_wait(int n); repeat(n) @(vif.master_cb); endtask

    task release_scl_and_wait();
        int t = 0;
        vif.master_cb.m_scl_drive_low <= 1'b0; // Release clock
        // Monitor physical wire (scl_i) to wait for slave to also release it
        while (vif.master_cb.scl_i !== 1'b1) begin 
            @(vif.master_cb);
            if (++t > 50000) `uvm_fatal("I2C_DRV","Clock stretch timeout!")
        end
    endtask

    task send_start();
        vif.master_cb.m_sda_drive_low <= 1'b0; 
        release_scl_and_wait();                
        cb_wait(SCL_HALF_PERIOD);
        vif.master_cb.m_sda_drive_low <= 1'b1; 
        cb_wait(SCL_HALF_PERIOD);
        vif.master_cb.m_scl_drive_low <= 1'b1; 
        cb_wait(SCL_HALF_PERIOD);
    endtask

    task send_stop();
        vif.master_cb.m_sda_drive_low <= 1'b1; // Pull SDA low FIRST
        cb_wait(SCL_HALF_PERIOD);              // FIXED: Added delay before releasing SCL
        
        release_scl_and_wait();                // Let SCL float HIGH
        cb_wait(SCL_HALF_PERIOD);
        
        vif.master_cb.m_sda_drive_low <= 1'b0; // Let SDA float HIGH to create STOP
        cb_wait(SCL_HALF_PERIOD);
    endtask

    task send_byte(input logic [7:0] data);
        for (int i=7; i>=0; i--) begin
            vif.master_cb.m_sda_drive_low <= ~data[i]; 
            cb_wait(SCL_HALF_PERIOD);
            release_scl_and_wait();         
            cb_wait(SCL_HALF_PERIOD);
            vif.master_cb.m_scl_drive_low <= 1'b1;    
            cb_wait(SCL_HALF_PERIOD);
        end
    endtask

    task automatic receive_byte(output logic [7:0] data);
        vif.master_cb.m_sda_drive_low <= 1'b0; 
        for (int i=7; i>=0; i--) begin
            vif.master_cb.m_scl_drive_low <= 1'b1;
            cb_wait(SCL_HALF_PERIOD);
            release_scl_and_wait();
            cb_wait(SCL_HALF_PERIOD/2);
            data[i] = vif.master_cb.sda_i; // Sample physical wire
            cb_wait(SCL_HALF_PERIOD/2);
        end
        vif.master_cb.m_scl_drive_low <= 1'b1;
    endtask

    task receive_ack(output logic nack);
        vif.master_cb.m_sda_drive_low <= 1'b0; 
        cb_wait(SCL_HALF_PERIOD);
        release_scl_and_wait();
        cb_wait(SCL_HALF_PERIOD/2);
        nack = vif.master_cb.sda_i;            
        cb_wait(SCL_HALF_PERIOD/2);
        vif.master_cb.m_scl_drive_low <= 1'b1; 
        cb_wait(SCL_HALF_PERIOD);
        `uvm_info("I2C_DRV", $sformatf("[ACK_SLOT] %s", nack?"NACK":"ACK"), UVM_HIGH)
    endtask

    task send_ack(input logic nack);
        vif.master_cb.m_sda_drive_low <= ~nack; 
        cb_wait(SCL_HALF_PERIOD);
        release_scl_and_wait();      
        cb_wait(SCL_HALF_PERIOD);
        vif.master_cb.m_scl_drive_low <= 1'b1; 
        cb_wait(SCL_HALF_PERIOD);
        vif.master_cb.m_sda_drive_low <= 1'b0; 
        cb_wait(SCL_HALF_PERIOD);
    endtask
endclass : i2c_driver
          
          
class axi_driver extends uvm_driver #(axi_stream_seq_item);
    `uvm_component_utils(axi_driver)
    virtual axi_stream_if vif;

    function new(string name="axi_driver", uvm_component parent=null); 
        super.new(name,parent); 
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi_stream_if)::get(this,"","s_axis_vif",vif)) 
            `uvm_fatal("CFG","axi_driver: s_axis_vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        axi_stream_seq_item pkt;
        
       
        vif.source_cb.tvalid <= 1'b0;
        vif.source_cb.tlast  <= 1'b0;
        vif.source_cb.tdata  <= 8'h00;
        
        forever begin
            seq_item_port.get_next_item(pkt);
            `uvm_info("AXI_DRV", $sformatf("[DRIVING]%s", pkt.convert2string()), UVM_NONE)
            drive_packet(pkt);
            `uvm_info("AXI_DRV","[DONE]",UVM_NONE)
            seq_item_port.item_done();
        end
    endtask

    task drive_packet(axi_stream_seq_item pkt);
        foreach (pkt.data[i]) begin
            repeat(pkt.tready_delay) begin
              
                vif.source_cb.tvalid <= 1'b0;
                @(vif.source_cb);
            end
            vif.source_cb.tdata  <= pkt.data[i];
            vif.source_cb.tvalid <= 1'b1;
            vif.source_cb.tlast  <= (i == pkt.data.size()-1);
            
            @(vif.source_cb);
            while (!vif.source_cb.tready) @(vif.source_cb);
            
           
            vif.source_cb.tvalid <= 1'b0;
            vif.source_cb.tlast  <= 1'b0;
        end
        vif.source_cb.tdata <= 8'h00;
        @(vif.source_cb);
    endtask
endclass : axi_driver

class i2c_monitor extends uvm_monitor;
    `uvm_component_utils(i2c_monitor)
    virtual i2c_if vif;
    uvm_analysis_port #(i2c_seq_item) ap;

    function new(string name="i2c_monitor", uvm_component parent=null); 
        super.new(name,parent); 
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual i2c_if)::get(this,"","vif",vif)) 
            `uvm_fatal("CFG","i2c_monitor: vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        i2c_seq_item txn;
        logic got_rstart = 1'b0; 

        forever begin
            if (!got_rstart) wait_for_start();
            got_rstart = 1'b0;

            txn = i2c_seq_item::type_id::create("mon_txn");

            begin
                logic [7:0] addr_byte;
                collect_byte(addr_byte, 1'b0);
                txn.device_address = addr_byte[7:1];
                txn.dut_address    = addr_byte[7:1];
                txn.read_write     = addr_byte[0];
            end

            `uvm_info("I2C_MON", $sformatf("[START] addr=7'h%0h dir=%s", txn.device_address, txn.read_write?"READ":"WRITE"), UVM_NONE)

            begin
                logic nack;
                sample_ack(1'b1, nack);
                if (nack) begin
                    `uvm_info("I2C_MON","Address NACK. Dropping transaction.",UVM_NONE)
                    continue;
                end
            end

            txn.data = new[0];

            begin
                logic [7:0] byte_val;
                logic got_stop_l, got_rstart_l;

                forever begin
                    collect_byte_or_stop(byte_val, got_stop_l, got_rstart_l, txn.read_write);

                    if (got_stop_l || got_rstart_l) begin
                        if (got_rstart_l) begin
                            `uvm_info("I2C_MON","[REPEATED_START]",UVM_NONE)
                            got_rstart = 1'b1;
                            txn.send_stop = 1'b0; // FIXED
                        end else begin
                            `uvm_info("I2C_MON","[STOP]",UVM_NONE)
                            txn.send_stop = 1'b1; // FIXED
                        end
                        break;
                    end

                    txn.data = new[txn.data.size() + 1](txn.data);
                    txn.data[txn.data.size() - 1] = byte_val;
                    `uvm_info("I2C_MON", $sformatf("[BYTE] [%0d]=8'h%0h", txn.data.size()-1, byte_val), UVM_NONE)

                    begin
                        logic ack;
                        if (!txn.read_write) begin
                            sample_ack(1'b1, ack);
                            if (ack) `uvm_error("I2C_MON","Data NACK (WRITE)")
                        end else begin
                            sample_ack(1'b0, ack);
                        end
                    end
                end
            end

            if (txn.data.size() == 0) begin
                `uvm_info("I2C_MON","[ZERO-BYTE TXN] Not forwarded to scoreboard.",UVM_NONE)
            end else begin
                `uvm_info("I2C_MON", $sformatf("[COMPLETE]%s", txn.convert2string()), UVM_NONE)
                ap.write(txn);
            end
        end
    endtask

    
    task wait_for_start();
        @(negedge vif.sda_i iff vif.scl_i === 1'b1);
    endtask

    task collect_byte(output logic [7:0] data, input bit read_phase);
        for (int i=7; i>=0; i--) begin
            @(posedge vif.scl_i);
            repeat(2) @(posedge vif.clk);
            if (read_phase) data[i] = vif.sda_o;
            else            data[i] = vif.sda_i;
        end
    endtask

    task collect_byte_or_stop(output logic [7:0] data, output logic got_stop, output logic got_rstart, input bit dir);
        got_stop   = 1'b0;
        got_rstart = 1'b0;

        for (int i=7; i>=0; i--) begin
            fork
                begin : wait_scl_high
                    @(posedge vif.scl_i);
                    repeat(2) @(posedge vif.clk);
                    if (dir) data[i] = vif.sda_o;
                    else     data[i] = vif.sda_i;
                    fork
                        begin : inner_rstart
                            @(negedge vif.sda_i iff vif.scl_i === 1'b1);
                            got_rstart = 1'b1;
                        end
                        begin : inner_scl_fall
                            @(negedge vif.scl_i);
                        end
                    join_any
                    disable fork; 
                end
                begin : wait_stop
                    @(posedge vif.sda_i iff vif.scl_i === 1'b1);
                    got_stop = 1'b1;
                end
            join_any
            disable fork;

            if (got_stop || got_rstart) return;
        end
    endtask

    task sample_ack(input bit from_slave, output logic bit_val);
        @(posedge vif.scl_i);
        repeat(2) @(posedge vif.clk);
        if (from_slave) bit_val = vif.sda_o;
        else            bit_val = vif.sda_i;
        @(negedge vif.scl_i);
    endtask
endclass : i2c_monitor

class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)
    virtual axi_stream_if vif;
    uvm_analysis_port #(axi_stream_seq_item) ap;

    function new(string name="axi_monitor", uvm_component parent=null); super.new(name,parent); endfunction

    function void build_phase(uvm_phase phase);
        string vif_key = "axi_vif";
        super.build_phase(phase);
        ap = new("ap", this);
        void'(uvm_config_db #(string)::get(this,"","vif_key",vif_key));
        if (!uvm_config_db #(virtual axi_stream_if)::get(this,"",vif_key,vif))
            `uvm_fatal("CFG", $sformatf("axi_monitor: vif not found (key=%s)",vif_key))
    endfunction

    task run_phase(uvm_phase phase);
        axi_stream_seq_item pkt;
        forever begin
            pkt = axi_stream_seq_item::type_id::create("mon_pkt");
            pkt.data = new[0];
            forever begin
                @(posedge vif.clk); #1step;
                if (vif.tvalid && vif.tready) begin
                    pkt.data = new[pkt.data.size() + 1](pkt.data);
                    pkt.data[pkt.data.size() - 1] = vif.tdata;
                    `uvm_info("AXI_MON", $sformatf("[BEAT] [%0d]=8'h%0h tlast=%0b", pkt.data.size()-1, vif.tdata, vif.tlast), UVM_NONE)
                    if (vif.tlast) break;
                end
            end
            `uvm_info("AXI_MON", $sformatf("[COMPLETE %0d bytes]%s", pkt.data.size(), pkt.convert2string()), UVM_NONE)
            ap.write(pkt);
        end
    endtask
endclass : axi_monitor
