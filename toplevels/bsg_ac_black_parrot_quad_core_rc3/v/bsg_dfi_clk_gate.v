// 
// bsg_dfi_clk_gate.v
// 
// Paul Gao   07/2020
// 
// 

module bsg_dfi_clk_gate

 #(// set number of sync flops for clock domain crossing
   parameter  num_sync_stages_p = 2
  )
  
  (input  dfi_raw_clk_i
  ,input  dfi_reset_i

  ,input  axi_clk_i
  ,input  axi_reset_i
  
  ,input  axi_fifo_error_i
  ,output user_clk_gate_o
  );

  // dfi clock edge detection
  // 
  logic dfi_toggle_r;
  bsg_dff_reset #(.width_p(1)) dfi_toggle_r_dff
  (.clk_i  (dfi_raw_clk_i)
  ,.reset_i(dfi_reset_i)
  ,.data_i (~dfi_toggle_r)
  ,.data_o (dfi_toggle_r)
  );
  
  logic dfi_toggle_rr;
  bsg_dff_chain 
 #(.width_p(1)
  ,.num_stages_p(num_sync_stages_p)
  ) dfi_toggle_rr_dff
  (.clk_i  (axi_clk_i)
  ,.data_i (dfi_toggle_r)
  ,.data_o (dfi_toggle_rr)
  );
  
  logic dfi_toggle_rrr;
  bsg_dff #(.width_p(1)) dfi_toggle_rrr_dff
  (.clk_i  (axi_clk_i)
  ,.data_i (dfi_toggle_rr)
  ,.data_o (dfi_toggle_rrr)
  );
  
  wire dfi_raw_clk_edge_detected = dfi_toggle_rr ^ dfi_toggle_rrr;


  // user clock gate signal generation
  //
  bsg_dff_reset_en #(.width_p(1)) user_clk_gate_dff
  (.clk_i  (axi_clk_i)
  ,.reset_i(axi_reset_i)
  ,.data_i (axi_fifo_error_i)
  ,.en_i   (dfi_raw_clk_edge_detected)
  ,.data_o (user_clk_gate_o)
  );

endmodule