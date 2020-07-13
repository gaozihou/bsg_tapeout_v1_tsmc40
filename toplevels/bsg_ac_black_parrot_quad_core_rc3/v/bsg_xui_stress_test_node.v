
module bsg_xui_stress_test_node

 #(parameter addr_width_p    = "inv"
  ,parameter data_width_p    = "inv"
  ,parameter num_requests_p  = "inv"
  ,parameter nonblock_read_p = 0
  )

  (input                          clk_i
  ,input                          reset_i
  ,output                         done_o

  // xilinx user interface
  ,output [addr_width_p-1:0]      app_addr_o
  ,output [2:0]                   app_cmd_o
  ,output                         app_en_o
  ,input                          app_rdy_i
  ,output                         app_wdf_wren_o
  ,output [data_width_p-1:0]      app_wdf_data_o
  ,output [(data_width_p>>3)-1:0] app_wdf_mask_o
  ,output                         app_wdf_end_o
  ,input                          app_wdf_rdy_i
  ,input                          app_rd_data_valid_i
  ,input  [data_width_p-1:0]      app_rd_data_i
  ,input                          app_rd_data_end_i
  );

  logic [31:0] counter_r;
  assign done_o = (counter_r == num_requests_p);
  
  always_ff @(posedge clk_i)
    if (reset_i)
        counter_r <= '0;
    else
        counter_r <= (app_en_o)? counter_r + 1 : counter_r;
  
  logic wait_read_r, wait_read_n;
  always_ff @(posedge clk_i)
    if (reset_i)
        wait_read_r <= 1'b0;
    else 
        wait_read_r <= wait_read_n;
  
  always_comb
  begin
    wait_read_n = wait_read_r;
    if (wait_read_r == 0)
      begin
        wait_read_n = (nonblock_read_p == 0 & app_en_o);
      end
    else
      begin
        wait_read_n = ~app_rd_data_valid_i;
      end
  end
  
  assign app_addr_o      = counter_r;
  assign app_cmd_o       = 1'b1;
  assign app_en_o        = ~reset_i & ~done_o & ~wait_read_r & app_rdy_i;
  assign app_wdf_wren_o  = 1'b0;
  assign app_wdf_data_o  = '0;
  assign app_wdf_mask_o  = '0;
  assign app_wdf_end_o   = app_wdf_wren_o;
  
  always_ff @(negedge clk_i)
  begin
    if (done_o)
      begin
        $display("xui node finished, terminating...");
        $finish();
      end
  end

endmodule

