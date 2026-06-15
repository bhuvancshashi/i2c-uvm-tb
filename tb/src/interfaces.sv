import uvm_pkg::*;
`include "uvm_macros.svh"

interface i2c_if (input logic clk, input logic rst);

    logic scl_i, sda_i;
    
    
    logic scl_o, scl_t;
    logic sda_o, sda_t;

    logic       release_bus, enable;
    logic [6:0] device_address, device_address_mask;
    logic       busy, bus_addressed, bus_active;
    logic [6:0] bus_address;


    logic m_scl_drive_low = 1'b0; 
    logic m_sda_drive_low = 1'b0;

   
    clocking master_cb @(posedge clk);
        default input  #1step;
        default output #1;
        

        output m_scl_drive_low, m_sda_drive_low;
        output release_bus, enable, device_address, device_address_mask;
        
       
        input  scl_i, sda_i;
        input  busy, bus_address, bus_addressed, bus_active;
    endclocking

   
    let is_start = $fell(sda_i) && $past(scl_i);
    let is_stop  = $rose(sda_i) && $past(scl_i);

    // Master SDA must be stable when SCL is HIGH (except START/STOP)
    // FIXED: Using valid SVA 'or' sequence operator to allow ##1 pull-up resolution
    property p_sda_master_valid;
        @(posedge clk) disable iff (rst)
        (scl_i && !$stable(sda_i)) |-> (is_start || is_stop) or (##1 is_stop);
    endproperty
    CHK_SDA_MASTER: assert property(p_sda_master_valid)
        else `uvm_error("I2C_SVA", "SDA changed while SCL HIGH (not START/STOP)");

    // Global X check
    property p_no_x_anytime;
        @(posedge clk) disable iff (rst)
        !$isunknown({scl_i, sda_i});
    endproperty
    CHK_NO_X: assert property(p_no_x_anytime)
        else `uvm_error("I2C_SVA", "X/Z detected on physical I2C lines");

    // STOP timing (2-cycle hold)
    property p_stop_quiet_time;
        @(posedge clk) disable iff (rst)
        is_stop |-> scl_i ##1 scl_i;
    endproperty
    CHK_STOP_QUIET: assert property(p_stop_quiet_time)
        else `uvm_error("I2C_SVA", "SCL dropped too early after STOP");

endinterface : i2c_if


interface axi_stream_if (input logic clk, input logic rst);

   
    logic [7:0] tdata;
    logic       tvalid, tready, tlast;

    
    clocking source_cb @(posedge clk);
        default input  #1step;
        default output #1;
        output tdata, tvalid, tlast;
        input  tready;
    endclocking

    clocking sink_cb @(posedge clk);
        default input #1step;
        input tdata, tvalid, tlast, tready;
    endclocking

    modport slave_mp   (clocking source_cb, input clk, input rst);
    modport master_mp  (clocking sink_cb,   input clk, input rst);
    modport monitor_mp (input clk, input rst, tdata, tvalid, tready, tlast);

   
    property p_no_x_control;
        @(posedge clk) disable iff (rst)
        !$isunknown({tvalid, tready});
    endproperty
    CHK_NO_X_CTRL: assert property(p_no_x_control)
        else `uvm_error("AXI_SVA", "tvalid/tready X/Z!");

    // Payload must be valid when tvalid is asserted
    property p_no_x_payload;
        @(posedge clk) disable iff (rst)
        tvalid |-> (!$isunknown(tdata) && !$isunknown(tlast));
    endproperty
    CHK_NO_X_PAYLOAD: assert property(p_no_x_payload)
        else `uvm_error("AXI_SVA", "tdata/tlast X/Z!");

    property p_tvalid_hold;
        @(posedge clk) disable iff (rst)
        (tvalid && !tready) |=> tvalid;
    endproperty
    CHK_TVALID_HOLD: assert property(p_tvalid_hold)
        else `uvm_error("AXI_SVA", "tvalid dropped before handshake");

    property p_tdata_hold;
        @(posedge clk) disable iff (rst)
        (tvalid && !tready) |=> $stable(tdata);
    endproperty
    CHK_TDATA_HOLD: assert property(p_tdata_hold)
        else `uvm_error("AXI_SVA", "tdata changed before handshake");

    property p_tlast_hold;
        @(posedge clk) disable iff (rst)
        (tvalid && !tready) |=> $stable(tlast);
    endproperty
    CHK_TLAST_HOLD: assert property(p_tlast_hold)
        else `uvm_error("AXI_SVA", "tlast changed before handshake");



    COVER_BACKPRESSURE: cover property (
        @(posedge clk) disable iff (rst)
        (tvalid && !tready)
    );

    COVER_PACKET_END: cover property (
        @(posedge clk) disable iff (rst)
        (tvalid && tready && tlast)
    );

endinterface : axi_stream_if
