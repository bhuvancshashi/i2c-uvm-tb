`include "interfaces.sv"
`include "tb_pkg.sv"

`include "uvm_macros.svh"
import uvm_pkg::*;
import tb_pkg::*;

module tb_top;

    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    logic rst;
  initial begin rst = 1'b1;
    repeat(5) @(posedge clk); 
    rst = 1'b0;
  end

    initial begin $dumpfile("dump.vcd"); $dumpvars(0, tb_top); end

    i2c_if        i2c_bus  (.clk(clk), .rst(rst));
    axi_stream_if s_axis_if(.clk(clk), .rst(rst));
    axi_stream_if m_axis_if(.clk(clk), .rst(rst));

   
    wire sda, scl;
    pullup(sda);
    pullup(scl);

   
    assign sda = ((!i2c_bus.sda_t && !i2c_bus.sda_o) || i2c_bus.m_sda_drive_low) ? 1'b0 : 1'bz;
    assign scl = ((!i2c_bus.scl_t && !i2c_bus.scl_o) || i2c_bus.m_scl_drive_low) ? 1'b0 : 1'bz;

    assign i2c_bus.sda_i = sda;
    assign i2c_bus.scl_i = scl;
   

    i2c_slave #(.FILTER_LEN(4)) dut (
        .clk                 (clk),
        .rst                 (rst),
        .scl_i               (i2c_bus.scl_i), 
        .scl_o               (i2c_bus.scl_o), 
        .scl_t               (i2c_bus.scl_t), 
        .sda_i               (i2c_bus.sda_i),
        .sda_o               (i2c_bus.sda_o),
        .sda_t               (i2c_bus.sda_t),
        .release_bus         (i2c_bus.release_bus),
        .enable              (i2c_bus.enable),
        .device_address      (i2c_bus.device_address),
        .device_address_mask (i2c_bus.device_address_mask),
        .busy                (i2c_bus.busy),
        .bus_address         (i2c_bus.bus_address),
        .bus_addressed       (i2c_bus.bus_addressed),
        .bus_active          (i2c_bus.bus_active),
        .s_axis_data_tdata   (s_axis_if.tdata),
        .s_axis_data_tvalid  (s_axis_if.tvalid),
        .s_axis_data_tready  (s_axis_if.tready),
        .s_axis_data_tlast   (s_axis_if.tlast),
        .m_axis_data_tdata   (m_axis_if.tdata),
        .m_axis_data_tvalid  (m_axis_if.tvalid),
        .m_axis_data_tready  (m_axis_if.tready),
        .m_axis_data_tlast   (m_axis_if.tlast)
    );

    initial begin
        m_axis_if.tready = 1'b1;
        
      uvm_config_db #(virtual i2c_if)::set(null, "*", "vif", i2c_bus);
        uvm_config_db #(virtual axi_stream_if)::set(null, "*", "s_axis_vif", s_axis_if);
        uvm_config_db #(virtual axi_stream_if)::set(null, "*", "m_axis_vif", m_axis_if); 
      
      //uvm_top.finish_on_completion = 0;        
      run_test("write_test");
    end

endmodule : tb_top
