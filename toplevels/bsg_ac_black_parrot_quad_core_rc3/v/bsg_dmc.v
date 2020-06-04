module bsg_dmc
  import bsg_tag_pkg::bsg_tag_s;
  import bsg_dmc_pkg::bsg_dmc_s;
 #(parameter  num_adgs_p         = 1
  ,parameter  ui_addr_width_p    = "inv"
  ,parameter  ui_data_width_p    = "inv"
  ,parameter  burst_data_width_p = "inv"
  ,parameter  dq_data_width_p    = "inv"
  ,parameter  clk_ratio_p        = "inv"
  ,parameter  axi_id_width_p     = "inv"
  ,parameter  axi_addr_width_p   = "inv"
  ,parameter  axi_data_width_p   = "inv"
  ,parameter  axi_burst_len_p    = "inv"
  ,localparam ui_mask_width_lp   = ui_data_width_p >> 3
  ,localparam dfi_data_width_lp  = dq_data_width_p << 1
  ,localparam dfi_mask_width_lp  = (dq_data_width_p >> 3) << 1
  ,localparam axi_strb_width_lp  = axi_data_width_p>>3
  ,localparam dq_group_lp        = dq_data_width_p >> 3)
  // Tag lines
  (input bsg_tag_s                   async_reset_tag_i
  ,input bsg_tag_s [dq_group_lp-1:0] bsg_dly_tag_i
  ,input bsg_tag_s [dq_group_lp-1:0] bsg_dly_trigger_tag_i
  ,input bsg_tag_s                   bsg_ds_tag_i
  // 
  ,input bsg_dmc_s                   dmc_p_i
  //
  ,input                             sys_reset_i
  // User interface signals
  ,input       [ui_addr_width_p-1:0] app_addr_i
  ,input                       [2:0] app_cmd_i
  ,input                             app_en_i
  ,output                            app_rdy_o
  ,input                             app_wdf_wren_i
  ,input       [ui_data_width_p-1:0] app_wdf_data_i
  ,input      [ui_mask_width_lp-1:0] app_wdf_mask_i
  ,input                             app_wdf_end_i
  ,output                            app_wdf_rdy_o
  ,output                            app_rd_data_valid_o
  ,output      [ui_data_width_p-1:0] app_rd_data_o
  ,output                            app_rd_data_end_o
  // Reserved to be compatible with Xilinx IPs
  ,input                             app_ref_req_i
  ,output                            app_ref_ack_o
  ,input                             app_zq_req_i
  ,output                            app_zq_ack_o
  ,input                             app_sr_req_i
  ,output                            app_sr_active_o
  // Status signal
  ,output                            init_calib_complete_o
  // DDR interface signals
  // Command and Address interface
  ,output                            ddr_ck_p_o
  ,output                            ddr_ck_n_o
  ,output                            ddr_cke_o
  ,output                      [2:0] ddr_ba_o
  ,output                     [15:0] ddr_addr_o
  ,output                            ddr_cs_n_o
  ,output                            ddr_ras_n_o
  ,output                            ddr_cas_n_o
  ,output                            ddr_we_n_o
  ,output                            ddr_reset_n_o
  ,output                            ddr_odt_o
  // Data interface
  ,output          [dq_group_lp-1:0] ddr_dm_oen_o
  ,output          [dq_group_lp-1:0] ddr_dm_o
  ,output          [dq_group_lp-1:0] ddr_dqs_p_oen_o
  ,output          [dq_group_lp-1:0] ddr_dqs_p_ien_o
  ,output          [dq_group_lp-1:0] ddr_dqs_p_o
  ,input           [dq_group_lp-1:0] ddr_dqs_p_i
  ,output          [dq_group_lp-1:0] ddr_dqs_n_oen_o
  ,output          [dq_group_lp-1:0] ddr_dqs_n_ien_o
  ,output          [dq_group_lp-1:0] ddr_dqs_n_o
  ,input           [dq_group_lp-1:0] ddr_dqs_n_i
  ,output      [dq_data_width_p-1:0] ddr_dq_oen_o
  ,output      [dq_data_width_p-1:0] ddr_dq_o
  ,input       [dq_data_width_p-1:0] ddr_dq_i
  // Clock interface signals
  ,input                             ui_clk_i
  ,input                             dfi_clk_2x_i
  ,output                            dfi_clk_1x_o
  //
  ,output                            ui_clk_sync_rst_o
  // Reserved to be compatible with Xilinx IPs
  ,output                     [11:0] device_temp_o
  // AXI interface 
  ,input                             axi_clk_i
  ,input                             axi_reset_i
  ,input                             axi_awready_i
  ,output       [axi_id_width_p-1:0] axi_awid_o
  ,output     [axi_addr_width_p-1:0] axi_awaddr_o
  ,output                            axi_awvalid_o
  // write data
  ,input                             axi_wready_i
  ,output     [axi_data_width_p-1:0] axi_wdata_o
  ,output    [axi_strb_width_lp-1:0] axi_wstrb_o
  ,output                            axi_wlast_o
  ,output                            axi_wvalid_o
  // write response
  ,input        [axi_id_width_p-1:0] axi_bid_i
  ,input                       [1:0] axi_bresp_i
  ,input                             axi_bvalid_i
  ,output                            axi_bready_o
  // read addr
  ,input                             axi_arready_i
  ,output       [axi_id_width_p-1:0] axi_arid_o
  ,output     [axi_addr_width_p-1:0] axi_araddr_o
  ,output                            axi_arvalid_o
  // read data
  ,input        [axi_id_width_p-1:0] axi_rid_i
  ,input      [axi_data_width_p-1:0] axi_rdata_i
  ,input                       [1:0] axi_rresp_i
  ,input                             axi_rlast_i
  ,input                             axi_rvalid_i
  ,output                            axi_rready_o
);

  wire                               dfi_clk_1x_lo;

  wire                               sys_reset;
  wire                               ui_reset;
  wire                               dfi_reset;

  wire                         [2:0] dfi_bank;
  wire                        [15:0] dfi_address;
  wire                               dfi_cke;
  wire                               dfi_cs_n;
  wire                               dfi_ras_n;
  wire                               dfi_cas_n;
  wire                               dfi_we_n;
  wire                               dfi_reset_n;
  wire                               dfi_odt;
  wire                               dfi_wrdata_en;
  wire       [dfi_data_width_lp-1:0] dfi_wrdata;
  wire       [dfi_mask_width_lp-1:0] dfi_wrdata_mask;
  wire                               dfi_rddata_en;
  wire       [dfi_data_width_lp-1:0] dfi_rddata;
  wire                               dfi_rddata_valid;

  wire             [dq_group_lp-1:0] dqs_p_li;

  wire                                       fifo_error;
  wire                                       fifo_wr_v;
  wire [2*dq_data_width_p+2*dq_group_lp-1:0] fifo_wr_data;
  wire                                       fifo_wr_ready;
  wire                                       fifo_cmd_v;
  wire                          [3+16+7-1:0] fifo_cmd_data;
  wire                                       fifo_cmd_ready;
  wire                                       fifo_rd_yumi;
  wire                                       fifo_rd_v;
  wire               [2*dq_data_width_p-1:0] fifo_rd_data;

  assign device_temp_o = 12'd0;

  bsg_dmc_clk_rst_gen #
    (.num_adgs_p  ( num_adgs_p  )
    ,.num_lines_p ( dq_group_lp ))
  dmc_clk_rst_gen
    // tag lines
    (.async_reset_tag_i     ( async_reset_tag_i     )
    ,.bsg_dly_tag_i         ( bsg_dly_tag_i         )
    ,.bsg_dly_trigger_tag_i ( bsg_dly_trigger_tag_i )
    ,.bsg_ds_tag_i          ( bsg_ds_tag_i          )

    ,.async_reset_o         ( sys_reset             )

    ,.clk_i                 ( ddr_dqs_p_i           )
    ,.clk_o                 ( dqs_p_li              )

    ,.clk_2x_i              ( dfi_clk_2x_i          )
    ,.clk_1x_o              ( dfi_clk_1x_lo         ));

  assign dfi_clk_1x_o = dfi_clk_1x_lo;

  bsg_sync_sync #(.width_p(1)) ui_reset_inst
    (.oclk_i      ( ui_clk_i    )
    ,.iclk_data_i ( sys_reset_i )
    ,.oclk_data_o ( ui_reset    ));

  bsg_sync_sync #(.width_p(1)) dfi_reset_inst
    (.oclk_i      ( dfi_clk_1x_lo   )
    ,.iclk_data_i ( sys_reset_i     )
    ,.oclk_data_o ( dfi_reset       ));

  assign ui_clk_sync_rst_o = ui_reset;

  bsg_dmc_controller #
    (.ui_addr_width_p       ( ui_addr_width_p       )
    ,.ui_data_width_p       ( ui_data_width_p       )
    ,.burst_data_width_p    ( burst_data_width_p    )
    ,.dfi_data_width_p      ( dfi_data_width_lp     ))
  dmc_controller
    // User interface clock and reset
    (.ui_clk_i              ( ui_clk_i              )
    ,.ui_clk_sync_rst_i     ( ui_reset              )
    // User interface signals
    ,.app_addr_i            ( app_addr_i            )
    ,.app_cmd_i             ( app_cmd_i             )
    ,.app_en_i              ( app_en_i              )
    ,.app_rdy_o             ( app_rdy_o             )
    ,.app_wdf_wren_i        ( app_wdf_wren_i        )
    ,.app_wdf_data_i        ( app_wdf_data_i        )
    ,.app_wdf_mask_i        ( app_wdf_mask_i        )
    ,.app_wdf_end_i         ( app_wdf_end_i         )
    ,.app_wdf_rdy_o         ( app_wdf_rdy_o         )
    ,.app_rd_data_valid_o   ( app_rd_data_valid_o   )
    ,.app_rd_data_o         ( app_rd_data_o         )
    ,.app_rd_data_end_o     ( app_rd_data_end_o     )
    ,.app_ref_req_i         ( app_ref_req_i         )
    ,.app_ref_ack_o         ( app_ref_ack_o         )
    ,.app_zq_req_i          ( app_zq_req_i          )
    ,.app_zq_ack_o          ( app_zq_ack_o          )
    ,.app_sr_req_i          ( app_sr_req_i          )
    ,.app_sr_active_o       ( app_sr_active_o       )
    // DDR PHY interface clock and reset
    ,.dfi_clk_i             ( dfi_clk_1x_lo         )
    ,.dfi_clk_sync_rst_i    ( dfi_reset             )
    // DDR PHY interface signals
    ,.dfi_bank_o            ( dfi_bank              )
    ,.dfi_address_o         ( dfi_address           )
    ,.dfi_cke_o             ( dfi_cke               )
    ,.dfi_cs_n_o            ( dfi_cs_n              )
    ,.dfi_ras_n_o           ( dfi_ras_n             )
    ,.dfi_cas_n_o           ( dfi_cas_n             )
    ,.dfi_we_n_o            ( dfi_we_n              )
    ,.dfi_reset_n_o         ( dfi_reset_n           )
    ,.dfi_odt_o             ( dfi_odt               )
    ,.dfi_wrdata_en_o       ( dfi_wrdata_en         )
    ,.dfi_wrdata_o          ( dfi_wrdata            )
    ,.dfi_wrdata_mask_o     ( dfi_wrdata_mask       )
    ,.dfi_rddata_en_o       ( dfi_rddata_en         )
    ,.dfi_rddata_i          ( dfi_rddata            )
    ,.dfi_rddata_valid_i    ( dfi_rddata_valid      )
    // Control and Status Registers
    ,.dmc_p_i               ( dmc_p_i               )
    //
    ,.init_calib_complete_o ( init_calib_complete_o ));

  bsg_dmc_phy #(.dq_data_width_p(dq_data_width_p)) dmc_phy
    // DDR PHY interface clock and reset
    (.dfi_clk_1x_i        ( dfi_clk_1x_lo       )
    ,.dfi_clk_2x_i        ( dfi_clk_2x_i        )
    ,.dfi_rst_i           ( dfi_reset           )
    // DFI interface signals
    ,.dfi_bank_i          ( dfi_bank            )
    ,.dfi_address_i       ( dfi_address         )
    ,.dfi_cke_i           ( dfi_cke             )
    ,.dfi_cs_n_i          ( dfi_cs_n            )
    ,.dfi_ras_n_i         ( dfi_ras_n           )
    ,.dfi_cas_n_i         ( dfi_cas_n           )
    ,.dfi_we_n_i          ( dfi_we_n            )
    ,.dfi_reset_n_i       ( dfi_reset_n         )
    ,.dfi_odt_i           ( dfi_odt             )
    ,.dfi_wrdata_en_i     ( dfi_wrdata_en       )
    ,.dfi_wrdata_i        ( dfi_wrdata          )
    ,.dfi_wrdata_mask_i   ( dfi_wrdata_mask     )
    ,.dfi_rddata_en_i     ( dfi_rddata_en       )
    ,.dfi_rddata_o        ( dfi_rddata          )
    ,.dfi_rddata_valid_o  ( dfi_rddata_valid    )
    // DDR interface signals
    ,.ck_p_o              ( ddr_ck_p_o          )
    ,.ck_n_o              ( ddr_ck_n_o          )
    ,.cke_o               ( ddr_cke_o           )
    ,.ba_o                ( ddr_ba_o            )
    ,.a_o                 ( ddr_addr_o          )
    ,.cs_n_o              ( ddr_cs_n_o          )
    ,.ras_n_o             ( ddr_ras_n_o         )
    ,.cas_n_o             ( ddr_cas_n_o         )
    ,.we_n_o              ( ddr_we_n_o          )
    ,.reset_o             ( ddr_reset_n_o       )
    ,.odt_o               ( ddr_odt_o           )
    ,.dm_oe_n_o           ( ddr_dm_oen_o        )
    ,.dm_o                ( ddr_dm_o            )
    ,.dqs_p_oe_n_o        ( ddr_dqs_p_oen_o     )
    ,.dqs_p_ie_n_o        ( ddr_dqs_p_ien_o     )
    ,.dqs_p_o             ( ddr_dqs_p_o         )
    ,.dqs_p_i             ( dqs_p_li            )
    ,.dqs_n_oe_n_o        ( ddr_dqs_n_oen_o     )
    ,.dqs_n_ie_n_o        ( ddr_dqs_n_ien_o     )
    ,.dqs_n_o             ( ddr_dqs_n_o         )
    ,.dqs_n_i             ( ~dqs_p_li           )
    ,.dq_oe_n_o           ( ddr_dq_oen_o        )
    ,.dq_o                ( ddr_dq_o            )
    ,.dq_i                ( ddr_dq_i            )
    // Control and Status Registers
    ,.dqs_sel_cal         ( dmc_p_i.dqs_sel_cal ));
    
    
  bsg_dfi_to_fifo 
 #(.clk_ratio_p    (clk_ratio_p)
  ,.dq_data_width_p(dq_data_width_p)
  ) dfi_to_fifo
  // DDR PHY interface clock and reset
  (.dfi_clk_1x_i        ( dfi_clk_1x_lo       )
  ,.dfi_clk_2x_i        ( dfi_clk_2x_i        )
  ,.dfi_rst_i           ( dfi_reset           )
  // DFI interface signals
  ,.dfi_bank_i          ( dfi_bank            )
  ,.dfi_address_i       ( dfi_address         )
  ,.dfi_cke_i           ( dfi_cke             )
  ,.dfi_cs_n_i          ( dfi_cs_n            )
  ,.dfi_ras_n_i         ( dfi_ras_n           )
  ,.dfi_cas_n_i         ( dfi_cas_n           )
  ,.dfi_we_n_i          ( dfi_we_n            )
  ,.dfi_reset_n_i       ( dfi_reset_n         )
  ,.dfi_odt_i           ( dfi_odt             )
  ,.dfi_wrdata_en_i     ( dfi_wrdata_en       )
  ,.dfi_wrdata_i        ( dfi_wrdata          )
  ,.dfi_wrdata_mask_i   ( dfi_wrdata_mask     )
  ,.dfi_rddata_en_i     ( dfi_rddata_en       )
  ,.dfi_rddata_o        (           )
  ,.dfi_rddata_valid_o  (     )
  // fifo signals
  ,.fifo_clk_i      (axi_clk_i)
  ,.fifo_reset_i    (axi_reset_i)
  ,.fifo_error_o    (fifo_error)

  ,.fifo_wr_v_o     (fifo_wr_v)
  ,.fifo_wr_data_o  (fifo_wr_data)
  ,.fifo_wr_ready_i (fifo_wr_ready)

  ,.fifo_cmd_v_o    (fifo_cmd_v)
  ,.fifo_cmd_data_o (fifo_cmd_data)
  ,.fifo_cmd_ready_i(fifo_cmd_ready)

  ,.fifo_rd_v_i     (fifo_rd_v)
  ,.fifo_rd_data_i  (fifo_rd_data)
  ,.fifo_rd_yumi_o  (fifo_rd_yumi)
  );

  bsg_fifo_to_axi
 #( .dq_data_width_p (dq_data_width_p)
   ,.axi_id_width_p  (axi_id_width_p)
   ,.axi_addr_width_p(axi_addr_width_p)
   ,.axi_data_width_p(axi_data_width_p)
   ,.axi_burst_len_p (axi_burst_len_p)
  ) fifo_to_axi
  (.clk_i           (axi_clk_i)
  ,.reset_i         (axi_reset_i)
  ,.fifo_error_i    (fifo_error)
  ,.fifo_wr_v_i     (fifo_wr_v)
  ,.fifo_wr_data_i  (fifo_wr_data)
  ,.fifo_wr_ready_o (fifo_wr_ready)
  ,.fifo_cmd_v_i    (fifo_cmd_v)
  ,.fifo_cmd_data_i (fifo_cmd_data)
  ,.fifo_cmd_ready_o(fifo_cmd_ready)
  ,.fifo_rd_yumi_i  (fifo_rd_yumi)
  ,.fifo_rd_v_o     (fifo_rd_v)
  ,.fifo_rd_data_o  (fifo_rd_data)
  ,.axi_awready_i
  ,.axi_awid_o
  ,.axi_awaddr_o
  ,.axi_awvalid_o
  ,.axi_wready_i
  ,.axi_wdata_o
  ,.axi_wstrb_o
  ,.axi_wlast_o
  ,.axi_wvalid_o
  ,.axi_bid_i
  ,.axi_bresp_i
  ,.axi_bvalid_i
  ,.axi_bready_o
  ,.axi_arready_i
  ,.axi_arid_o
  ,.axi_araddr_o
  ,.axi_arvalid_o
  ,.axi_rid_i
  ,.axi_rdata_i
  ,.axi_rresp_i
  ,.axi_rlast_i
  ,.axi_rvalid_i
  ,.axi_rready_o
  );
    

endmodule
