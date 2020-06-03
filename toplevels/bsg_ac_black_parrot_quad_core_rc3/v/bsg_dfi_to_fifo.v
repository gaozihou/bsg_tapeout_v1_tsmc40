
module bsg_dfi_to_fifo 

 #(parameter  clk_ratio_p     = "inv"
  ,parameter  dq_data_width_p = "inv"
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
  
  // error signal
  logic wr_error_r, wr_error_n;
  logic cmd_error_r, cmd_error_n;
  logic rd_error_r, rd_error_n;
  assign fifo_error_o = wr_error_r | cmd_error_r | rd_error_r;


  // handle write data
  assign fifo_wr_data_o = {dfi_wrdata_i, dfi_wrdata_mask_i};
  
  logic fifo_wr_v_lo;
  assign fifo_wr_v_o = fifo_wr_v_lo;
  
  logic [7:0] wr_count_r, wr_count_n;
  always_ff @(posedge fifo_clk_i)
  begin
    if (fifo_reset_i)
      begin
        wr_count_r <= '0;
        wr_error_r <= 1'b0;
      end
    else
      begin
        wr_count_r <= wr_count_n;
        wr_error_r <= wr_error_n;
      end
  end
  
  always_comb
  begin
    wr_count_n = wr_count_r;
    wr_error_n = wr_error_r;
    fifo_wr_v_lo = 1'b0;
    if (dfi_wrdata_en_i)
      begin
        fifo_wr_v_lo = (wr_count_r == 0);
        wr_error_n = (wr_count_r == 0) && (~fifo_wr_ready_i);
        wr_count_n = wr_count_r + 1;
        if (wr_count_r == (clk_ratio_p-1))
          begin
            wr_count_n = 0;
          end
      end
  end


  // handle cmd
  assign fifo_cmd_data_o = {dfi_bank_i, dfi_address_i, dfi_cke_i, dfi_cs_n_i, dfi_ras_n_i, dfi_cas_n_i, dfi_we_n_i, dfi_reset_n_i, dfi_odt_i};
  
  logic fifo_cmd_v_lo;
  assign fifo_cmd_v_o = fifo_cmd_v_lo;
  
  logic [7:0] cmd_count_r, cmd_count_n;
  always_ff @(posedge fifo_clk_i)
  begin
    if (fifo_reset_i)
      begin
        cmd_count_r <= '0;
        cmd_error_r <= 1'b0;
      end
    else
      begin
        cmd_count_r <= cmd_count_n;
        cmd_error_r <= cmd_error_n;
      end
  end
  
  always_comb
  begin
    cmd_count_n = cmd_count_r;
    cmd_error_n = cmd_error_r;
    fifo_cmd_v_lo = 1'b0;
    if (~dfi_cs_n_i)
      begin
        fifo_cmd_v_lo = (cmd_count_r == 0);
        cmd_error_n = (cmd_count_r == 0) && (~fifo_cmd_ready_i);
        cmd_count_n = cmd_count_r + 1;
        if (cmd_count_r == (clk_ratio_p-1))
          begin
            cmd_count_n = 0;
          end
      end
  end


  // handle read data
  bsg_dff_chain 
 #(.width_p     (1)
  ,.num_stages_p(2)
  ) rdvalid_dff
  (.clk_i       (dfi_clk_1x_i)
  ,.data_i      (dfi_rddata_en_i)
  ,.data_o      (dfi_rddata_valid_o)
  );
  
  assign dfi_rddata_o = fifo_rd_data_i;
  
  logic fifo_rd_yumi_lo;
  assign fifo_rd_yumi_o = fifo_rd_yumi_lo;
  
  logic [7:0] rd_count_r, rd_count_n;
  always_ff @(posedge fifo_clk_i)
  begin
    if (fifo_reset_i)
      begin
        rd_count_r <= '0;
        rd_error_r <= 1'b0;
      end
    else
      begin
        rd_count_r <= rd_count_n;
        rd_error_r <= rd_error_n;
      end
  end
  
  always_comb
  begin
    rd_count_n = rd_count_r;
    rd_error_n = rd_error_r;
    fifo_rd_yumi_lo = 1'b0;
    if (dfi_rddata_valid_o)
      begin
        fifo_rd_yumi_lo = (rd_count_r == (clk_ratio_p-1));
        rd_error_n = (rd_count_r == (clk_ratio_p-1)) && (~fifo_rd_v_i);
        rd_count_n = rd_count_r + 1;
        if (rd_count_r == (clk_ratio_p-1))
          begin
            rd_count_n = 0;
          end
      end
  end

endmodule