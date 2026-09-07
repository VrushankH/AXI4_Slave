// =============================================================================
// Design      : AXI4 Full Memory-Mapped Slave
// Description : Burst-capable AXI4 slave with internal 256 x 32-bit memory
// ----------------------------------------------------------------
// Spec (from design notes)
//   - Data width       : 32 bits
//   - Memory size       : 256 x 32-bit words  (1 KB address space, 0x000-0x3FC)
//   - Address width     : 32 bits (bits [31:10] must be 0 for a valid access)
//   - Word alignment     : 32-bit aligned (ADDR_LSB = 2)
//   - Supports           : write burst, single write, address decoding,
//                          byte enables via WSTRB, write response generation,
//                          burst read, FIXED and INCR burst types
//   - Invalid address    : returns SLVERR (2'b10) on B/R response
//   - Reset behaviour     : memory cleared to 0, all channel outputs return to idle
// =============================================================================


module axi4_full_slave #(
    parameter int DATA_WIDTH    = 32,
    parameter int ADDR_WIDTH    = 32,
    parameter int ID_WIDTH      = 4,
    parameter int MEM_WORDS     = 256,                      // 256 x 32-bit words
    parameter int MEM_ADDR_BITS = $clog2(MEM_WORDS)          // 8 bits -> word index
)(
    input  logic                       ACLK,
    input  logic                       ARESETn,

    // ---------------- Write Address Channel ----------------
    input  logic [ID_WIDTH-1:0]        AWID,
    input  logic [ADDR_WIDTH-1:0]      AWADDR,
    input  logic [7:0]                 AWLEN,      // burst length - 1
    input  logic [2:0]                 AWSIZE,     // bytes per beat = 2^AWSIZE
    input  logic [1:0]                 AWBURST,    // 00=FIXED 01=INCR 10=WRAP
    input  logic                       AWVALID,
    output logic                       AWREADY,

    // ---------------- Write Data Channel --------------------
    input  logic [DATA_WIDTH-1:0]      WDATA,
    input  logic [(DATA_WIDTH/8)-1:0]  WSTRB,
    input  logic                       WLAST,
    input  logic                       WVALID,
    output logic                       WREADY,

    // ---------------- Write Response Channel ----------------
    output logic [ID_WIDTH-1:0]        BID,
    output logic [1:0]                 BRESP,
    output logic                       BVALID,
    input  logic                       BREADY,

    // ---------------- Read Address Channel -------------------
    input  logic [ID_WIDTH-1:0]        ARID,
    input  logic [ADDR_WIDTH-1:0]      ARADDR,
    input  logic [7:0]                 ARLEN,
    input  logic [2:0]                 ARSIZE,
    input  logic [1:0]                 ARBURST,
    input  logic                       ARVALID,
    output logic                       ARREADY,

    // ---------------- Read Data Channel -----------------------
    output logic [ID_WIDTH-1:0]        RID,
    output logic [DATA_WIDTH-1:0]      RDATA,
    output logic [1:0]                 RRESP,
    output logic                       RLAST,
    output logic                       RVALID,
    input  logic                       RREADY
);

    // AXI response codes
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;   // used for out-of-range access
    // RESP_DECERR (2'b11) intentionally not used - spec calls for SLVERR on bad address

    // Burst type encodings
    localparam logic [1:0] BURST_FIXED = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01;
    localparam logic [1:0] BURST_WRAP  = 2'b10;

    localparam int          ADDR_LSB  = 2;                 // 32-bit word aligned
    localparam logic [31:0] ADDR_SPAN = 32'h0000_0400;      // 1 KB : valid addr < 0x400

    // -------------------------------------------------------------------
    // Internal Memory : 256 x 32-bit words
    // -------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];

    // Full-range address check: upper bits must be 0 AND base word must be < MEM_WORDS.
    // (word index slice is already bounded 0-255 by construction, so the real guard
    //  is making sure nothing above bit 9 is set - i.e. address truly inside 0-0x3FC)
    function automatic logic addr_base_ok(input logic [ADDR_WIDTH-1:0] addr);
        return (addr < ADDR_SPAN);
    endfunction

    // Burst-bound check: for INCR/WRAP the last beat address must also stay in range.
    // For FIXED, only the base address matters since the address never advances.
    function automatic logic burst_ok(input logic [ADDR_WIDTH-1:0] addr,
                                       input logic [1:0]            burst,
                                       input logic [7:0]            len);
        logic [MEM_ADDR_BITS-1:0] base_idx;
        base_idx = addr[ADDR_LSB +: MEM_ADDR_BITS];
        if (!addr_base_ok(addr))
            return 1'b0;
        if (burst == BURST_FIXED)
            return 1'b1;                                   // address doesn't move
        else
            return ((base_idx + len) < MEM_WORDS);          // INCR / WRAP treated as INCR
    endfunction

    // =====================================================================
    // WRITE CHANNEL  (AW + W + B)  -- FSM based, supports bursts
    // =====================================================================
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wr_state_t;
    wr_state_t wr_state;

    logic [ID_WIDTH-1:0]         awid_r;
    logic [ADDR_WIDTH-1:0]       awaddr_r;
    logic [7:0]                  awlen_r;
    logic [1:0]                  awburst_r;
    logic [7:0]                  wr_beat_cnt;
    logic [MEM_ADDR_BITS-1:0]    wr_word_idx;
    logic                        wr_addr_valid;   // decode result latched at AW accept

    assign wr_word_idx = awaddr_r[ADDR_LSB +: MEM_ADDR_BITS];

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            wr_state      <= W_IDLE;
            AWREADY       <= 1'b0;
            WREADY        <= 1'b0;
            BVALID        <= 1'b0;
            BRESP         <= RESP_OKAY;
            BID           <= '0;
            awid_r        <= '0;
            awaddr_r      <= '0;
            awlen_r       <= '0;
            awburst_r     <= '0;
            wr_beat_cnt   <= '0;
            wr_addr_valid <= 1'b0;
            // Memory cleared to zero on reset
            for (int i = 0; i < MEM_WORDS; i++)
                mem[i] <= '0;
        end else begin
            case (wr_state)
                // -------------------------------------------------
                W_IDLE: begin
                    BVALID  <= 1'b0;
                    AWREADY <= 1'b1;                 // ready to accept a new address
                    if (AWVALID && AWREADY) begin
                        awid_r        <= AWID;
                        awaddr_r      <= AWADDR;
                        awlen_r       <= AWLEN;       // burst length - 1
                        awburst_r     <= AWBURST;
                        wr_beat_cnt   <= '0;
                        wr_addr_valid <= burst_ok(AWADDR, AWBURST, AWLEN);
                        AWREADY <= 1'b0;
                        WREADY  <= 1'b1;
                        wr_state <= W_DATA;
                    end
                end

                // -------------------------------------------------
                W_DATA: begin
                    if (WVALID && WREADY) begin
                        if (wr_addr_valid) begin
                            automatic logic [MEM_ADDR_BITS-1:0] idx;
                            // FIXED burst: always hit the same word.
                            // INCR/WRAP: advance by beat count.
                            idx = (awburst_r == BURST_FIXED)
                                    ? wr_word_idx
                                    : (wr_word_idx + wr_beat_cnt[MEM_ADDR_BITS-1:0]);
                            for (int b = 0; b < (DATA_WIDTH/8); b++) begin
                                if (WSTRB[b])
                                    mem[idx][b*8 +: 8] <= WDATA[b*8 +: 8];
                            end
                        end

                        if (WLAST) begin
                            WREADY   <= 1'b0;
                            BID      <= awid_r;
                            BRESP    <= wr_addr_valid ? RESP_OKAY : RESP_SLVERR;
                            BVALID   <= 1'b1;
                            wr_state <= W_RESP;
                        end else begin
                            wr_beat_cnt <= wr_beat_cnt + 1'b1;
                        end
                    end
                end

                // -------------------------------------------------
                W_RESP: begin
                    if (BVALID && BREADY) begin
                        BVALID   <= 1'b0;
                        wr_state <= W_IDLE;
                    end
                end

                default: wr_state <= W_IDLE;
            endcase
        end
    end

    // =====================================================================
    // READ CHANNEL  (AR + R)  -- FSM based, supports bursts
    // =====================================================================
    typedef enum logic [1:0] {R_IDLE, R_DATA} rd_state_t;
    rd_state_t rd_state;

    logic [ID_WIDTH-1:0]      arid_r;
    logic [ADDR_WIDTH-1:0]    araddr_r;
    logic [7:0]                arlen_r;
    logic [1:0]                arburst_r;
    logic [7:0]                rd_beat_cnt;
    logic [MEM_ADDR_BITS-1:0]  rd_word_idx;
    logic                      rd_addr_valid;

    assign rd_word_idx = araddr_r[ADDR_LSB +: MEM_ADDR_BITS];

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rd_state      <= R_IDLE;
            ARREADY       <= 1'b0;
            RVALID        <= 1'b0;
            RLAST         <= 1'b0;
            RRESP         <= RESP_OKAY;
            RID           <= '0;
            RDATA         <= '0;
            arid_r        <= '0;
            araddr_r      <= '0;
            arlen_r       <= '0;
            arburst_r     <= '0;
            rd_beat_cnt   <= '0;
            rd_addr_valid <= 1'b0;
        end else begin
            case (rd_state)
                // -------------------------------------------------
                // First beat is produced right here, directly off ARADDR,
                // so RDATA is valid on the SAME cycle RVALID first asserts
                // (fixes the one-cycle RVALID/RDATA mismatch).
                R_IDLE: begin
                    ARREADY <= 1'b1;
                    if (ARVALID && ARREADY) begin
                        automatic logic addr_ok;
                        automatic logic [MEM_ADDR_BITS-1:0] idx0;
                        addr_ok = burst_ok(ARADDR, ARBURST, ARLEN);
                        idx0    = ARADDR[ADDR_LSB +: MEM_ADDR_BITS];

                        arid_r        <= ARID;
                        araddr_r      <= ARADDR;
                        arlen_r       <= ARLEN;
                        arburst_r     <= ARBURST;
                        rd_beat_cnt   <= '0;
                        rd_addr_valid <= addr_ok;

                        ARREADY  <= 1'b0;
                        RVALID   <= 1'b1;
                        RID      <= ARID;
                        RDATA    <= addr_ok ? mem[idx0] : '0;
                        RRESP    <= addr_ok ? RESP_OKAY : RESP_SLVERR;
                        RLAST    <= (ARLEN == 8'd0);
                        rd_state <= R_DATA;
                    end
                end

                // -------------------------------------------------
                R_DATA: begin
                    if (RVALID && RREADY) begin
                        if (RLAST) begin
                            RVALID   <= 1'b0;
                            RLAST    <= 1'b0;
                            rd_state <= R_IDLE;
                        end else begin
                            automatic logic [7:0]                next_cnt;
                            automatic logic [MEM_ADDR_BITS-1:0]  next_idx;
                            next_cnt = rd_beat_cnt + 1'b1;
                            // FIXED burst: keep reading the same word.
                            // INCR/WRAP: advance to the next word.
                            next_idx = (arburst_r == BURST_FIXED)
                                        ? rd_word_idx
                                        : (rd_word_idx + next_cnt[MEM_ADDR_BITS-1:0]);

                            rd_beat_cnt <= next_cnt;
                            RID    <= arid_r;
                            RDATA  <= rd_addr_valid ? mem[next_idx] : '0;
                            RRESP  <= rd_addr_valid ? RESP_OKAY : RESP_SLVERR;
                            RLAST  <= (next_cnt == arlen_r);
                        end
                    end
                end

                default: rd_state <= R_IDLE;
            endcase
        end
    end

endmodule
