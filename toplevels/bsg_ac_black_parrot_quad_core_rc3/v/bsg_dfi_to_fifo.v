
module bsg_dfi_to_fifo 

 #(parameter  dq_data_width_p = "inv"
  ,parameter  num_sync_stages_p = 2
  ,localparam dq_group_lp     = dq_data_width_p >> 3
  )
  
  (// dfi interface signals
   input                          dfi_clk_1x_i
  ,input                          dfi_clk_2x_i
  ,input                          dfi_rst_i
  ,input                    [2:0] dfi_bank_i
  ,input                   [15:0] dfi_address_i
  ,input                          dfi_cke_i
  ,input                          dfi_cs_n_i
  ,input                          dfi_ras_n_i
  ,input                          dfi_cas_n_i
  ,input                          dfi_we_n_i
  ,input                          dfi_reset_n_i
  ,input                          dfi_odt_i
  ,input                          dfi_wrdata_en_i
  ,input  [2*dq_data_width_p-1:0] dfi_wrdata_i
  ,input      [2*dq_group_lp-1:0] dfi_wrdata_mask_i
  ,input                          dfi_rddata_en_i
  ,output [2*dq_data_width_p-1:0] dfi_rddata_o
  ,output                         dfi_rddata_valid_o
  
  // fifo signals
  ,input                                        fifo_clk_i
  ,input                                        fifo_reset_i
  ,output                                       fifo_error_o
  
  ,output                                       fifo_wr_v_o
  ,output [2*dq_data_width_p+2*dq_group_lp-1:0] fifo_wr_data_o
  ,input                                        fifo_wr_ready_i
  
  ,output                                       fifo_cmd_v_o
  ,output                          [3+16+7-1:0] fifo_cmd_data_o
  ,input                                        fifo_cmd_ready_i
  
  ,input                                        fifo_rd_v_i
  ,input                [2*dq_data_width_p-1:0] fifo_rd_data_i
  ,output                                       fifo_rd_yumi_o
  );
  
  // handle error detection
  logic fifo_wr_error_lo, fifo_cmd_error_lo, fifo_rd_error_lo;
  assign fifo_error_o = fifo_wr_error_lo | fifo_cmd_error_lo | fifo_rd_error_lo;
  
  
  // handle dfi clock edge detection
  logic dfi_toggle_r;
  bsg_dff_reset #(.width_p(1)) dfi_toggle_r_dff
  (.clk_i  (dfi_clk_1x_i)
  ,.reset_i(dfi_rst_i)
  ,.data_i (~dfi_toggle_r)
  ,.data_o (dfi_toggle_r)
  );
  
  logic dfi_toggle_rr;
  bsg_dff_chain 
 #(.width_p(1)
  ,.num_stages_p(num_sync_stages_p)
  ) dfi_toggle_rr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (dfi_toggle_r)
  ,.data_o (dfi_toggle_rr)
  );
  
  logic dfi_toggle_rrr;
  bsg_dff #(.width_p(1)) dfi_toggle_rrr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (dfi_toggle_rr)
  ,.data_o (dfi_toggle_rrr)
  );
  
  wire dfi_clk_edge_detected = dfi_toggle_rr ^ dfi_toggle_rrr;
  
  logic dfi_clk_edge_detected_r;
  bsg_dff #(.width_p(1)) dfi_edge_r_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (dfi_clk_edge_detected)
  ,.data_o (dfi_clk_edge_detected_r)
  );


  // handle write data
  assign fifo_wr_data_o = {dfi_wrdata_i, dfi_wrdata_mask_i};
  assign fifo_wr_v_o = dfi_wrdata_en_i & dfi_clk_edge_detected;
  
  // write error monitor
  bsg_dff_reset #(.width_p(1)) wr_error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (~fifo_wr_ready_i)
  ,.data_o (fifo_wr_error_lo)
  );


  // handle cmd
  assign fifo_cmd_data_o = {dfi_bank_i, dfi_address_i, dfi_cke_i, dfi_cs_n_i, dfi_ras_n_i, dfi_cas_n_i, dfi_we_n_i, dfi_reset_n_i, dfi_odt_i};
  assign fifo_cmd_v_o = (~dfi_cs_n_i) & dfi_clk_edge_detected;
  
  // cmd error monitor
  bsg_dff_reset #(.width_p(1)) cmd_error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (~fifo_cmd_ready_i)
  ,.data_o (fifo_cmd_error_lo)
  );


  // handle read data
  bsg_dff_chain 
 #(.width_p     (1)
  ,.num_stages_p(2) // FIXED, DO NOT MODIFY
  ) rdvalid_dff
  (.clk_i       (dfi_clk_1x_i)
  ,.data_i      (dfi_rddata_en_i)
  ,.data_o      (dfi_rddata_valid_o)
  );
  
  logic dfi_rddata_valid_r;
  bsg_dff #(.width_p(1)) rdvalid_r_dff
  (.clk_i (dfi_clk_1x_i)
  ,.data_i(dfi_rddata_valid_o)
  ,.data_o(dfi_rddata_valid_r)
  );
  
  assign dfi_rddata_o = fifo_rd_data_i;
  assign fifo_rd_yumi_o = dfi_rddata_valid_r & dfi_clk_edge_detected;
  
  // read error monitor
  logic [num_sync_stages_p:0] fifo_rd_v_r;
  assign fifo_rd_v_r[0] = fifo_rd_v_i;
  for (genvar i = 0; i < num_sync_stages_p; i++)
  begin: rd_v_r_loop
    bsg_dff #(.width_p(1)) dff
    (.clk_i (fifo_clk_i)
    ,.data_i(fifo_rd_v_r[i])
    ,.data_o(fifo_rd_v_r[i+1])
    );
  end
  
  bsg_dff_reset_en #(.width_p(1)) rd_error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (dfi_rddata_valid_o & ~fifo_rd_v_i)
  ,.en_i   (dfi_clk_edge_detected_r | (& fifo_rd_v_r))
  ,.data_o (fifo_rd_error_lo)
  );

endmodule