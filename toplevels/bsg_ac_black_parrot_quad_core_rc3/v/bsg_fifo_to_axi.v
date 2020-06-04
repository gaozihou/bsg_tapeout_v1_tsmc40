module bsg_fifo_to_axi
 #(parameter dq_data_width_p="inv"
    , parameter axi_id_width_p="inv"
    , parameter axi_addr_width_p="inv"
    , parameter axi_data_width_p="inv"
    , parameter axi_burst_len_p="inv"
    , localparam axi_strb_width_lp=(axi_data_width_p>>3)
    , localparam dq_group_lp=(dq_data_width_p >> 3)
  )
  (
    input clk_i
    , input reset_i

    // fifo interface
    , input fifo_error_i
    
    , input fifo_wr_v_i
    , input [2*dq_data_width_p+2*dq_group_lp-1:0] fifo_wr_data_i
    , output logic fifo_wr_ready_o
    
    , input fifo_cmd_v_i
    , input [3+16+7-1:0] fifo_cmd_data_i
    , output logic fifo_cmd_ready_o
    
    , input fifo_rd_yumi_i
    , output fifo_rd_v_o
    , output logic [2*dq_data_width_p-1:0] fifo_rd_data_o

    // AXI interface
    // write addr
    , input axi_awready_i
    , output logic [axi_id_width_p-1:0] axi_awid_o
    , output logic [axi_addr_width_p-1:0] axi_awaddr_o
    , output logic axi_awvalid_o

    // write data
    , input axi_wready_i
    , output logic [axi_data_width_p-1:0] axi_wdata_o
    , output logic [axi_strb_width_lp-1:0] axi_wstrb_o
    , output logic axi_wlast_o
    , output logic axi_wvalid_o

    // write response
    , input [axi_id_width_p-1:0] axi_bid_i
    , input [1:0] axi_bresp_i
    , input axi_bvalid_i
    , output logic axi_bready_o

    // read addr
    , input axi_arready_i
    , output logic [axi_id_width_p-1:0] axi_arid_o
    , output logic [axi_addr_width_p-1:0] axi_araddr_o
    , output logic axi_arvalid_o

    // read data
    , input [axi_id_width_p-1:0] axi_rid_i
    , input [axi_data_width_p-1:0] axi_rdata_i
    , input [1:0] axi_rresp_i
    , input axi_rlast_i
    , input axi_rvalid_i
    , output logic axi_rready_o
    );

    assign fifo_cmd_ready_o = 1'b1;
    assign fifo_wr_ready_o = 1'b1;
    assign fifo_rd_v_o = 1'b1;
    assign fifo_rd_data_o = 64'hdeadbeefdeadbeef;

endmodule
