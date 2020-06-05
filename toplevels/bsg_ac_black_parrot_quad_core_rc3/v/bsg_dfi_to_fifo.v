
module bsg_dfi_to_fifo 

 #(parameter  clk_ratio_p     = "inv"
  ,parameter  dq_data_width_p = "inv"
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

  // handle write data
  logic wr_toggle_r;
  bsg_dff_reset #(.width_p(1)) wr_toggle_r_dff
  (.clk_i  (dfi_clk_1x_i)
  ,.reset_i(dfi_rst_i)
  ,.data_i (~wr_toggle_r)
  ,.data_o (wr_toggle_r)
  );
  
  logic wr_toggle_rr;
  bsg_dff_chain 
 #(.width_p(1)
  ,.num_stages_p(num_sync_stages_p)
  ) wr_toggle_rr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (wr_toggle_r)
  ,.data_o (wr_toggle_rr)
  );
  
  logic wr_toggle_rrr;
  bsg_dff_chain #(.width_p(1)) wr_toggle_rrr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (wr_toggle_rr)
  ,.data_o (wr_toggle_rrr)
  );
  
  assign fifo_wr_data_o = {dfi_wrdata_i, dfi_wrdata_mask_i};
  assign fifo_wr_v_o = dfi_wrdata_en_i & (wr_toggle_rr ^ wr_toggle_rrr);
  
/*
  wire w_async_fifo_full_lo;
  bsg_async_fifo
 #(.lg_size_p(3)
  ,.width_p  (2*dq_data_width_p+2*dq_group_lp)
  ) w_async_fifo
  (.w_clk_i  (dfi_clk_1x_i)
  ,.w_reset_i(dfi_rst_i)
  ,.w_enq_i  (dfi_wrdata_en_i)
  ,.w_data_i ({dfi_wrdata_i, dfi_wrdata_mask_i})
  ,.w_full_o (w_async_fifo_full_lo)

  ,.r_clk_i  (fifo_clk_i)
  ,.r_reset_i(fifo_reset_i)
  ,.r_deq_i  (fifo_wr_v_o & fifo_wr_ready_i)
  ,.r_data_o (fifo_wr_data_o)
  ,.r_valid_o(fifo_wr_v_o)
  );
*/

  // handle cmd
  logic cmd_toggle_r;
  bsg_dff_reset #(.width_p(1)) cmd_toggle_r_dff
  (.clk_i  (dfi_clk_1x_i)
  ,.reset_i(dfi_rst_i)
  ,.data_i (~cmd_toggle_r)
  ,.data_o (cmd_toggle_r)
  );
  
  logic cmd_toggle_rr;
  bsg_dff_chain 
 #(.width_p(1)
  ,.num_stages_p(num_sync_stages_p)
  ) cmd_toggle_rr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (cmd_toggle_r)
  ,.data_o (cmd_toggle_rr)
  );
  
  logic cmd_toggle_rrr;
  bsg_dff #(.width_p(1)) cmd_toggle_rrr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (cmd_toggle_rr)
  ,.data_o (cmd_toggle_rrr)
  );
  
  assign fifo_cmd_data_o = {dfi_bank_i, dfi_address_i, dfi_cke_i, dfi_cs_n_i, dfi_ras_n_i, dfi_cas_n_i, dfi_we_n_i, dfi_reset_n_i, dfi_odt_i};
  assign fifo_cmd_v_o = (~dfi_cs_n_i) & (cmd_toggle_rr ^ cmd_toggle_rrr);

/*
  wire cmd_async_fifo_full_lo;
  bsg_async_fifo
 #(.lg_size_p(3)
  ,.width_p  (3+16+7)
  ) cmd_async_fifo
  (.w_clk_i  (dfi_clk_1x_i)
  ,.w_reset_i(dfi_rst_i)
  ,.w_enq_i  (~dfi_cs_n_i)
  ,.w_data_i ({dfi_bank_i, dfi_address_i, dfi_cke_i, dfi_cs_n_i, dfi_ras_n_i, dfi_cas_n_i, dfi_we_n_i, dfi_reset_n_i, dfi_odt_i})
  ,.w_full_o (cmd_async_fifo_full_lo)

  ,.r_clk_i  (fifo_clk_i)
  ,.r_reset_i(fifo_reset_i)
  ,.r_deq_i  (fifo_cmd_v_o & fifo_cmd_ready_i)
  ,.r_data_o (fifo_cmd_data_o)
  ,.r_valid_o(fifo_cmd_v_o)
  );
*/

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
  
  logic rd_toggle_r;
  bsg_dff_reset #(.width_p(1)) rd_toggle_r_dff
  (.clk_i  (dfi_clk_1x_i)
  ,.reset_i(dfi_rst_i)
  ,.data_i (~rd_toggle_r)
  ,.data_o (rd_toggle_r)
  );
  
  logic rd_toggle_rr;
  bsg_dff_chain 
 #(.width_p(1)
  ,.num_stages_p(num_sync_stages_p)
  ) rd_toggle_rr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (rd_toggle_r)
  ,.data_o (rd_toggle_rr)
  );
  
  logic rd_toggle_rrr;
  bsg_dff #(.width_p(1)) rd_toggle_rrr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (rd_toggle_rr)
  ,.data_o (rd_toggle_rrr)
  );
  
  assign dfi_rddata_o = fifo_rd_data_i;
  wire rd_clk_edge_detected = rd_toggle_rr ^ rd_toggle_rrr;
  assign fifo_rd_yumi_o = dfi_rddata_valid_r & rd_clk_edge_detected;
  
  bsg_dff_reset_en #(.width_p(1)) error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (dfi_rddata_valid_o & ~fifo_rd_v_i)
  ,.en_i   (rd_clk_edge_detected | fifo_rd_v_i)
  ,.data_o (fifo_error_o)
  );

endmodule