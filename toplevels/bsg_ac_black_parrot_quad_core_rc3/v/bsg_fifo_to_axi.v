module bsg_fifo_to_axi
 #(parameter dq_data_width_p="inv"
    , parameter axi_id_width_p="inv"
    , parameter axi_addr_width_p="inv"
    , parameter axi_data_width_p="inv"
    , parameter axi_burst_len_p="inv"
    , localparam axi_strb_width_lp=(axi_data_width_p >> 3)
    , localparam dq_group_lp=(dq_data_width_p >> 3)
    , localparam cmd_data_width_lp=(3 + 16 + 7)
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
    , input [cmd_data_width_lp-1:0] fifo_cmd_data_i
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
    , output logic [7:0] axi_awlen_o
    , output logic [2:0] axi_awsize_o
    , output logic [1:0] axi_awburst_o
    , output logic [3:0] axi_awcache_o
    , output logic [1:0] axi_awprot_o
    , output logic axi_awlock_o

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
    , output logic [7:0] axi_arlen_o
    , output logic [2:0] axi_arsize_o
    , output logic [1:0] axi_arburst_o
    , output logic [3:0] axi_arcache_o
    , output logic [1:0] axi_arprot_o
    , output logic axi_arlock_o

    // read data
    , input [axi_id_width_p-1:0] axi_rid_i
    , input [axi_data_width_p-1:0] axi_rdata_i
    , input [1:0] axi_rresp_i
    , input axi_rlast_i
    , input axi_rvalid_i
    , output logic axi_rready_o
    );

    localparam bank_width_lp = 2;
    localparam row_els_lp = 16*1024;
    localparam row_width_lp = `BSG_SAFE_CLOG2(row_els_lp);
    localparam col_els_lp = 2*1024;
    localparam col_width_lp = `BSG_SAFE_CLOG2(col_els_lp);
    localparam axi_dq_ratio_lp = axi_data_width_p/(2*dq_data_width_p);
    localparam axi_wdata_counter_width_lp = `BSG_SAFE_CLOG2(16*dq_data_width_p/axi_data_width_p+1);

    // Command
    logic                         cmd_v_lo;
    logic [cmd_data_width_lp-1:0] cmd_data_lo;
    logic                         cmd_yumi_li;
    logic                   [2:0] bank;
    logic                  [15:0] address;
    logic                         cke_lo;
    logic                         cs_n;
    logic                         ras_n;
    logic                         cas_n;
    logic                         we_n;
    logic                         reset_n;
    logic                         odt;

    bsg_two_fifo 
   #(.width_p(cmd_data_width_lp)
     ,.verbose_p(0)
     ,.allow_enq_deq_on_full_p(0)
     ,.ready_THEN_valid_p(0)
    ) cmd_fifo
    (.clk_i
     ,.reset_i
     ,.ready_o(fifo_cmd_ready_o)
     ,.data_i (fifo_cmd_data_i)
     ,.v_i    (fifo_cmd_v_i) 
     ,.v_o    (cmd_v_lo) 
     ,.data_o (cmd_data_lo) 
     ,.yumi_i (cmd_yumi_li) 
    );

    assign {bank, address, cke_lo, cs_n, ras_n, cas_n, 
            we_n, reset_n, odt} = cmd_data_lo;

    // Command decode
    logic                        bank_row_sel;
    logic                        mode_change;
    logic     [row_width_lp-1:0] row;
    logic [axi_addr_width_p-1:0] axi_addr;

    assign axi_addr = (bank[1:0] * row_els_lp * col_els_lp +
                      row * col_els_lp +
                      {address[11], address[9:0]}) << 2; // byte
    always_comb begin
        bank_row_sel = 0;
        bank_row_sel = 0;
        axi_arvalid_o = 0;
        axi_awvalid_o = 0;
        mode_change = 0;
        cmd_yumi_li = 0;
        axi_awaddr_o = 0;
        axi_awid_o = 0;
        axi_araddr_o = 0;
        axi_arid_o = 0;
        if (cmd_v_lo) begin
            case ({cs_n, ras_n, cas_n, we_n})
                4'b0011: begin
                    // select bank and activate row
                    bank_row_sel = 1;
                    cmd_yumi_li = 1;
                end
                4'b0101: begin
                    // read burst
                    axi_arvalid_o = 1;
                    axi_araddr_o = axi_addr;
                    axi_arid_o = 0; // ignore now
                    cmd_yumi_li = axi_arready_i;
                end
                4'b0100: begin
                    // write burst
                    axi_awvalid_o = 1;
                    axi_awaddr_o = axi_addr;
                    axi_awid_o = 0; // ignore now
                    cmd_yumi_li = axi_awready_i;
                end
                4'b0000: begin
                    // load mode register
                    mode_change = (bank[1:0] == 2'b00);
                    cmd_yumi_li = 1;
                end
                default: begin
                    bank_row_sel = 0;
                    axi_arvalid_o = 0;
                    axi_awvalid_o = 0;
                    mode_change = 0;
                    cmd_yumi_li = 1;
                end
            endcase
        end
    end

    assign axi_awlen_o = (8)'(axi_burst_len_p - 1); // burst len
    assign axi_awsize_o = (3)'(`BSG_SAFE_CLOG2(axi_data_width_p >> 3));
    assign axi_awburst_o = 2'b01;   // incr
    assign axi_awcache_o = 4'b0000; // non-bufferable
    assign axi_awprot_o = 2'b00;    // unprivileged
    assign axi_awlock_o = 1'b0;    // normal access
    assign axi_arlen_o = (8)'(axi_burst_len_p - 1); // burst length
    assign axi_arsize_o = (3)'(`BSG_SAFE_CLOG2(axi_data_width_p >> 3));
    assign axi_arburst_o = 2'b01;   // incr
    assign axi_arcache_o = 4'b0000; // non-bufferable
    assign axi_arprot_o = 2'b00;    // unprevileged
    assign axi_arlock_o = 1'b0;    // normal access

    // Statndard mode register
    // Currently we only support sequential mode
    logic [2:0] mode_burst_len;   // 3'b001: 2
                                  // 3'b010: 4
                                  // 3'b011: 8
                                  // 3'b100: 16
    logic       mode_burst_type;  // 1'b0: sequential
                                  // 1'b1: interleaved
    logic [2:0] mode_cas_latency; // 3'b010: 2
                                  // 3'b011: 3
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            row <= 0;
            mode_burst_len <= 0;
            mode_burst_type <= 0;
            mode_cas_latency <= 0;
        end
        else begin
            if (bank_row_sel) begin
                row <= address[0+:row_width_lp];
            end
            if (mode_change) begin
                mode_burst_len <= address[2:0];
                mode_burst_type <= address[3];
                mode_cas_latency <= address[6:4];
            end
        end
    end

    // wrdata
    logic wr_yumi_li;
    logic wrdata_v_lo, wrmask_v_lo;
    logic wrdata_ready_lo, wrmask_ready_lo;
    logic [2*dq_group_lp*axi_dq_ratio_lp-1:0] axi_wmask_lo;
    logic [axi_data_width_p+axi_dq_ratio_lp*dq_group_lp-1:0] wr_data_lo;
    logic [axi_wdata_counter_width_lp-1:0] axi_wdata_counter_r;
    logic [axi_wdata_counter_width_lp-1:0] axi_wdata_len;

    bsg_serial_in_parallel_out_full
   #(.width_p(2*dq_data_width_p)
     ,.els_p(axi_dq_ratio_lp)
     ,.hi_to_lo_p(0)
     ,.use_minimal_buffering_p(0)
    ) wrdata_sipo
    (.clk_i
     ,.reset_i
     ,.ready_o(wrdata_ready_lo)
     ,.data_i (fifo_wr_data_i[2*dq_group_lp+:2*dq_data_width_p])
     ,.v_i    (fifo_wr_v_i) 
     ,.v_o    (wrdata_v_lo) 
     ,.data_o (axi_wdata_o) 
     ,.yumi_i (wr_yumi_li) 
    );

    bsg_serial_in_parallel_out_full
   #(.width_p(2*dq_group_lp)
     ,.els_p(axi_dq_ratio_lp)
     ,.hi_to_lo_p(0)
     ,.use_minimal_buffering_p(0)
    ) wrmask_sipo
    (.clk_i
     ,.reset_i
     ,.ready_o(wrmask_ready_lo)
     ,.data_i (fifo_wr_data_i[0+:2*dq_group_lp])
     ,.v_i    (fifo_wr_v_i) 
     ,.v_o    (wrmask_v_lo) 
     ,.data_o (axi_wmask_lo) 
     ,.yumi_i (wr_yumi_li) 
    );

    assign axi_wstrb_o = ~axi_wmask_lo;
    assign fifo_wr_ready_o = wrdata_ready_lo & wrmask_ready_lo;
    assign wr_yumi_li = wrdata_v_lo & axi_wready_i;
    assign axi_wvalid_o = wrdata_v_lo & wrmask_v_lo;
    assign axi_wlast_o = axi_wvalid_o & (axi_wdata_counter_r == axi_wdata_len - 1); // really nead wvalid?
    always_comb begin
        case (mode_burst_len)
            3'b001: begin
                if (2 * dq_data_width_p < axi_data_width_p)
                    axi_wdata_len = 1;
                else
                    axi_wdata_len = 2 * dq_data_width_p / axi_data_width_p;
            end
            3'b010: begin
                if (4 * dq_data_width_p < axi_data_width_p)
                    axi_wdata_len = 1;
                else
                    axi_wdata_len = 4 * dq_data_width_p / axi_data_width_p;
            end
            3'b011: begin
                if (8 * dq_data_width_p < axi_data_width_p)
                    axi_wdata_len = 1;
                else
                    axi_wdata_len = 8 * dq_data_width_p / axi_data_width_p;
            end
            3'b100: begin
                if (16 * dq_data_width_p < axi_data_width_p)
                    axi_wdata_len = 1;
                else
                    axi_wdata_len = 16 * dq_data_width_p / axi_data_width_p;
            end
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            axi_wdata_counter_r <= 0;
        end
        else begin
            if (mode_change & (mode_burst_len !== address[2:0] )) begin
                axi_wdata_counter_r <= 0;
            end
            else begin
                if (axi_wvalid_o & wr_yumi_li) begin
                    if (axi_wdata_counter_r + 1 == axi_wdata_len) 
                        axi_wdata_counter_r <= 0;
                    else
                        axi_wdata_counter_r <= axi_wdata_counter_r + 1;
                end
            end
        end
    end

    assign axi_bready_o = 1;

    // rddata
    bsg_parallel_in_serial_out 
    #(.width_p(2*dq_data_width_p)
      ,.els_p(axi_dq_ratio_lp)
      ,.hi_to_lo_p(0)
     ) rddata_piso
    (.clk_i
     ,.reset_i
     ,.valid_i (axi_rvalid_i)
     ,.data_i  (axi_rdata_i)
     ,.ready_o (axi_rready_o)
     ,.valid_o (fifo_rd_v_o)
     ,.data_o  (fifo_rd_data_o)
     ,.yumi_i  (fifo_rd_yumi_i)
    );



endmodule
