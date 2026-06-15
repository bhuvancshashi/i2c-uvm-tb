class i2c_write_seq extends uvm_sequence #(i2c_seq_item);
  
    `uvm_object_utils(i2c_write_seq)
  
    function new(string name="i2c_write_seq");
      super.new(name);
    endfunction
  
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        if (!txn.randomize() with { read_write == 1'b0; }) `uvm_fatal("RAND","i2c_write_seq failed")
        finish_item(txn);
    endtask
endclass


class i2c_read_seq extends uvm_sequence #(i2c_seq_item);	
  
    `uvm_object_utils(i2c_read_seq)
  
    int unsigned req_size;
  
    function new(string name="i2c_read_seq");
      super.new(name);
    endfunction
  
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        if (!txn.randomize() with { read_write == 1'b1; data.size() == req_size; }) `uvm_fatal("RAND","i2c_read_seq failed")
        finish_item(txn);
    endtask
endclass


class axi_push_seq extends uvm_sequence #(axi_stream_seq_item);
  
    `uvm_object_utils(axi_push_seq)
  
    rand int unsigned pkt_size;
  
    constraint c_size { pkt_size inside {[1:8]}; }
  
    function new(string name="axi_push_seq");
      super.new(name);
    endfunction
  
    task body();
        axi_stream_seq_item pkt = axi_stream_seq_item::type_id::create("pkt");
        start_item(pkt);
        if (!pkt.randomize() with { tready_delay == 0; data.size() == pkt_size; }) `uvm_fatal("RAND","axi_push_seq failed")
        finish_item(pkt);
    endtask
endclass

class axi_backpressure_seq extends uvm_sequence #(axi_stream_seq_item);
    `uvm_object_utils(axi_backpressure_seq)
    function new(string name="axi_backpressure_seq"); super.new(name); endfunction
    task body();
        axi_stream_seq_item pkt = axi_stream_seq_item::type_id::create("pkt");
        start_item(pkt);
        if (!pkt.randomize() with { tready_delay inside {[1:5]}; }) `uvm_fatal("RAND","axi_backpressure_seq failed")
        finish_item(pkt);
    endtask
endclass

class i2c_nbyte_write_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_nbyte_write_seq)
    int unsigned n_bytes = 8;
    function new(string name="i2c_nbyte_write_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        if (!txn.randomize() with { read_write == 1'b0; data.size() == n_bytes; }) `uvm_fatal("RAND","i2c_nbyte_write_seq failed")
        finish_item(txn);
    endtask
endclass

class i2c_repeated_start_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_repeated_start_seq)
    int unsigned write_bytes = 2;
    int unsigned read_bytes  = 2;
    function new(string name="i2c_repeated_start_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item w_txn, r_txn;
        w_txn = i2c_seq_item::type_id::create("w_txn");
        start_item(w_txn);
        if (!w_txn.randomize() with { read_write == 1'b0; data.size() == write_bytes; send_stop == 1'b0; }) `uvm_fatal("RAND","failed")
        finish_item(w_txn);

        r_txn = i2c_seq_item::type_id::create("r_txn");
        start_item(r_txn);
        if (!r_txn.randomize() with { read_write == 1'b1; data.size() == read_bytes; send_stop == 1'b1; dut_address == w_txn.dut_address; device_address == w_txn.device_address; }) `uvm_fatal("RAND","failed")
        finish_item(r_txn);
    endtask
endclass

class i2c_zero_byte_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_zero_byte_seq)
    function new(string name="i2c_zero_byte_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        txn.c_data_size.constraint_mode(0);
        if (!txn.randomize() with { read_write == 1'b0; data.size() == 0; }) `uvm_fatal("RAND","i2c_zero_byte_seq failed")
        finish_item(txn);
    endtask
endclass

class i2c_addr_miss_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_addr_miss_seq)
    function new(string name="i2c_addr_miss_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        if (!txn.randomize() with { dut_address == 7'h55; device_address == 7'h2A; read_write == 1'b0; data.size() == 1; }) `uvm_fatal("RAND","failed")
        finish_item(txn);
    endtask
endclass

class i2c_addr_mask_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(i2c_addr_mask_seq)
    function new(string name="i2c_addr_mask_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn1");
        start_item(txn);
        if (!txn.randomize() with { dut_address == 7'h50; dut_mask == 7'h78; device_address == 7'h55; read_write == 1'b0; data.size() == 1; }) `uvm_fatal("RAND","failed")
        finish_item(txn);

        txn = i2c_seq_item::type_id::create("txn2");
        start_item(txn);
        if (!txn.randomize() with { dut_address == 7'h50; dut_mask == 7'h78; device_address == 7'h2A; read_write == 1'b0; data.size() == 1; }) `uvm_fatal("RAND","failed")
        finish_item(txn);
    endtask
endclass

class tc21_data_integrity_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(tc21_data_integrity_seq)
    function new(string name="tc21_data_integrity_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        txn.c_data_size.constraint_mode(0);
        if (!txn.randomize() with { read_write == 1'b0; data.size() == 8; }) 
            `uvm_fatal("RAND","tc21_data_integrity_seq failed")
        
        foreach (txn.data[i]) txn.data[i] = 8'h01 << i; // Overwrite with walking-ones pattern
        finish_item(txn);
    endtask
endclass 

class tc25_stop_mid_transfer_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(tc25_stop_mid_transfer_seq)
    int unsigned stop_after = 2;  
    function new(string name="tc25_stop_mid_transfer_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        txn.c_data_size.constraint_mode(0);
        if (!txn.randomize() with { read_write == 1'b0; data.size() == stop_after; send_stop == 1'b1; }) 
            `uvm_fatal("RAND","tc25_stop_mid_transfer_seq failed")
        finish_item(txn);
    endtask
endclass

class tc26_missing_stop_seq extends uvm_sequence #(i2c_seq_item);
    `uvm_object_utils(tc26_missing_stop_seq)
    function new(string name="tc26_missing_stop_seq"); super.new(name); endfunction
    task body();
        i2c_seq_item txn = i2c_seq_item::type_id::create("txn");
        start_item(txn);
        if (!txn.randomize() with { read_write == 1'b0; data.size() == 2; send_stop == 1'b0; }) 
            `uvm_fatal("RAND","tc26 sequence failed")
        finish_item(txn);
    endtask
endclass
