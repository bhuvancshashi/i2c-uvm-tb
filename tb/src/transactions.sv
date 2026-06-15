class i2c_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(i2c_seq_item)
        `uvm_field_int(device_address,      UVM_ALL_ON)
        `uvm_field_int(dut_address,         UVM_ALL_ON)
        `uvm_field_int(dut_mask,            UVM_ALL_ON)
        `uvm_field_int(read_write,          UVM_ALL_ON)
        `uvm_field_array_int(data,          UVM_ALL_ON)
        `uvm_field_int(enable,              UVM_ALL_ON)
        `uvm_field_int(release_bus,         UVM_ALL_ON)
        `uvm_field_int(send_stop,           UVM_ALL_ON)
    `uvm_object_utils_end

  rand logic [6:0] device_address;
    rand logic [6:0] dut_address;
    rand logic [6:0] dut_mask;
    rand logic       read_write;
    rand logic [7:0] data[];
    rand logic       enable, release_bus;
    rand logic       send_stop;

    constraint c_enable        { enable == 1'b1; }
    constraint c_release_bus   { release_bus == 1'b0; }
    constraint c_valid_address { device_address inside {[7'h08:7'h77]}; }
    constraint c_dut_addr      { soft dut_address == 7'h55; }
    constraint c_dut_mask      { soft dut_mask == 7'h7F; }
    constraint c_match_addr    { soft device_address == dut_address; }
    constraint c_data_size     { data.size() inside {[1:8]}; }
    constraint c_send_stop     { soft send_stop == 1'b1; }

    function new(string name="i2c_seq_item"); 
      super.new(name); 
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("\n--- I2C Transaction ---");
        s = {s, $sformatf("\n  DUT Pin   : 7'h%0h (Mask: 7'h%0h)", dut_address, dut_mask)};
        s = {s, $sformatf("\n  Bus Addr  : 7'h%0h", device_address)};
        s = {s, $sformatf("\n  Direction : %s", read_write ? "READ":"WRITE")};
        s = {s, $sformatf("\n  Bytes     : %0d", data.size())};
        foreach (data[i]) s = {s, $sformatf("\n    [%0d]=8'h%0h", i, data[i])};
        s = {s, $sformatf("\n  STOP      : %0b", send_stop)};
        s = {s, "\n-----------------------"};
        return s;
    endfunction
endclass : i2c_seq_item

class axi_stream_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(axi_stream_seq_item)
        `uvm_field_array_int(data,       UVM_ALL_ON)
        `uvm_field_int(tready_delay,     UVM_ALL_ON)
    `uvm_object_utils_end

    rand logic [7:0]  data[];
    rand int unsigned tready_delay;

    constraint c_data_size    { data.size() inside {[1:8]}; }
    constraint c_tready_delay { tready_delay dist { 0:=80, [1:5]:=20 }; }

    function new(string name="axi_stream_seq_item"); 
      super.new(name);
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("\n--- AXI Stream Packet ---");
        s = {s, $sformatf("\n  Bytes       : %0d", data.size())};
        s = {s, $sformatf("\n  tready_delay: %0d", tready_delay)};
        foreach (data[i]) s = {s, $sformatf("\n    [%0d]=8'h%0h", i, data[i])};
        s = {s, "\n-------------------------"};
        return s;
    endfunction
endclass : axi_stream_seq_item
