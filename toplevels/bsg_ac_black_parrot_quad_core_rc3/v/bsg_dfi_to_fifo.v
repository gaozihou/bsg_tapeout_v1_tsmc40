// 
// bsg_dfi_to_fifo.v
// 
// Paul Gao   06/2020
// 
// This module converts DDR-PHY (dfi) interface to bsg fifo interface.
//
// User Guide:
// 1. dfi_clk and fifo_clk can be asynchronous. 
// 2. fifo_clk must be at least 6x faster than dfi_clk.
// 3. dfi_clk must be gated (stalled at 1'b0) when fifo_error_o is asserted.
// 4. max_delay of all datapaths between dfi_clk and fifo_clk are 
//    smaller than fifo_clk_period.
// 

module bsg_dfi_to_fifo 

 #(parameter  dq_data_width_p   = "inv"
  // set PHY's read latency (defined by PHY)
  // rddata_valid_o is asserted phy_rdlat_p cycles after rddata_en_i asserted
  ,parameter  phy_rdlat_p       = "inv"
  // set number of sync flops for clock domain crossing
  ,parameter  num_sync_stages_p = 2
  ,localparam dq_group_lp       = dq_data_width_p >> 3
  )
  
  (// dfi interface signals
   input                          dfi_clk_1x_i
  ,input                          dfi_clk_2x_i // not used
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
  
  // fifo interface signals
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
  // 
  // There are possibilities that fifo interface is not fast enough to
  // handle dfi requests within required time period. Therefore we need
  // to enable clock gating on dfi_clk when this happens, until fifo 
  // interface catch up with the pace.
  // 
  // The most common case is that read data do not come back in time. Rare
  // cases are wrdata get backed-up, cmd get backed-up. All of which will
  // trigger fifo_error_o signal and enable clock gating.
  // 
  logic fifo_wr_error_lo, fifo_cmd_error_lo, fifo_rd_error_lo;
  assign fifo_error_o = fifo_wr_error_lo | fifo_cmd_error_lo | fifo_rd_error_lo;
  

  
  // handle dfi clock edge detection
  // 
  // Since dfi interface is master and fifo interface is slave, and fifo_clk
  // runs much faster than dfi_clk, we first wait for rising edge of dfi_clk, 
  // then process the dfi request in remaining cycles (with fast fifo_clk).
  // 
  // Toggle register in dfi_clk
  logic dfi_toggle_r;
  bsg_dff_reset #(.width_p(1)) dfi_toggle_r_dff
  (.clk_i  (dfi_clk_1x_i)
  ,.reset_i(dfi_rst_i)
  ,.data_i (~dfi_toggle_r)
  ,.data_o (dfi_toggle_r)
  );
  
  // Sync flops for clock domain crossing, from dfi_clk to fifo_clk
  logic dfi_toggle_rr;
  bsg_dff_chain 
 #(.width_p(1)
  ,.num_stages_p(num_sync_stages_p)
  ) dfi_toggle_rr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (dfi_toggle_r)
  ,.data_o (dfi_toggle_rr)
  );
  
  // Toggle register in fifo_clk
  logic dfi_toggle_rrr;
  bsg_dff #(.width_p(1)) dfi_toggle_rrr_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (dfi_toggle_rr)
  ,.data_o (dfi_toggle_rrr)
  );
  
  // dfi_clk_edge detected when current and registered values are different
  wire dfi_clk_edge_detected = dfi_toggle_rr ^ dfi_toggle_rrr;
  
  // Registered edge_detected signal, used for read error monitor
  logic dfi_clk_edge_detected_r;
  bsg_dff #(.width_p(1)) dfi_edge_r_dff
  (.clk_i  (fifo_clk_i)
  ,.data_i (dfi_clk_edge_detected)
  ,.data_o (dfi_clk_edge_detected_r)
  );



  // handle write data
  // 
  // Wrdata is hard-wired between dfi and fifo without synchronization
  // Valid signal is asserted when dfi_clk_edge is detected
  // 
  assign fifo_wr_data_o = {dfi_wrdata_i, dfi_wrdata_mask_i};
  assign fifo_wr_v_o = dfi_wrdata_en_i & dfi_clk_edge_detected;
  
  // write error monitor, detecting wrdata backup
  bsg_dff_reset #(.width_p(1)) wr_error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (~fifo_wr_ready_i)
  ,.data_o (fifo_wr_error_lo)
  );


  // handle cmd
  // 
  // Cmd is hard-wired between dfi and fifo without synchronization
  // Valid signal is asserted when dfi_clk_edge is detected
  // 
  assign fifo_cmd_data_o = {dfi_bank_i, dfi_address_i, dfi_cke_i, dfi_cs_n_i, dfi_ras_n_i, dfi_cas_n_i, dfi_we_n_i, dfi_reset_n_i, dfi_odt_i};
  assign fifo_cmd_v_o = (~dfi_cs_n_i) & dfi_clk_edge_detected;
  
  // cmd error monitor, detecting cmd backup
  bsg_dff_reset #(.width_p(1)) cmd_error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (~fifo_cmd_ready_i)
  ,.data_o (fifo_cmd_error_lo)
  );



  // handle read data
  // 
  // Read data should appear on dfi interface phy_rdlat_p cycles after 
  // rddata_en is asserted, use this dff_chain to generate rddata_valid signal
  bsg_dff_chain 
 #(.width_p     (1)
  ,.num_stages_p(phy_rdlat_p)
  ) rdvalid_dff
  (.clk_i       (dfi_clk_1x_i)
  ,.data_i      (dfi_rddata_en_i)
  ,.data_o      (dfi_rddata_valid_o)
  );
  
  // Registered rddata_valid signal
  logic dfi_rddata_valid_r;
  bsg_dff #(.width_p(1)) rdvalid_r_dff
  (.clk_i (dfi_clk_1x_i)
  ,.data_i(dfi_rddata_valid_o)
  ,.data_o(dfi_rddata_valid_r)
  );
  
  // Rddata is hard-wired between dfi and fifo without synchronization
  // Read data fifo is dequeued when the following (not current) rising edge of 
  // dfi_clk is detected.
  assign dfi_rddata_o = fifo_rd_data_i;
  assign fifo_rd_yumi_o = dfi_rddata_valid_r & dfi_clk_edge_detected;

  // read error monitor
  // 
  // When read data finally come back, we need to wait a short period of
  // time to let rddata propagate to dfi interface. Use this chain of 
  // flops to delay the disabling of clock gating.
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
  
  // Read error appears when
  // 1. dfi_rddata should be valid in current cycle, and
  // 2. Actual read data has not come back to fifo interface
  //
  // Read error register is only updated when
  // 1. One cycle after dfi_clk edge detected, or
  // 2. Clock gating should be disabled
  bsg_dff_reset_en #(.width_p(1)) rd_error_dff
  (.clk_i  (fifo_clk_i)
  ,.reset_i(fifo_reset_i)
  ,.data_i (dfi_rddata_valid_o & ~fifo_rd_v_i)
  ,.en_i   (dfi_clk_edge_detected_r | (& fifo_rd_v_r))
  ,.data_o (fifo_rd_error_lo)
  );

endmodule