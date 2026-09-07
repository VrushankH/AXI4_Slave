// =============================================================================
// axi4_if.sv - AXI4 interface + protocol assertions
// No ports on the interface: ACLK/ARESETn are internal signals so the
// environment/test can drive reset directly through the virtual interface.
// Top-level module drives ACLK only.
// =============================================================================

interface axi4_if;

    logic        ACLK;
    logic        ARESETn;

    // Write Address Channel
    logic [3:0]  AWID;
    logic [31:0] AWADDR;
    logic [7:0]  AWLEN;
    logic [2:0]  AWSIZE;
    logic [1:0]  AWBURST;
    logic        AWVALID;
    logic        AWREADY;

    // Write Data Channel
    logic [31:0] WDATA;
    logic [3:0]  WSTRB;
    logic        WLAST;
    logic        WVALID;
    logic        WREADY;

    // Write Response Channel
    logic [3:0]  BID;
    logic [1:0]  BRESP;
    logic        BVALID;
    logic        BREADY;

    // Read Address Channel
    logic [3:0]  ARID;
    logic [31:0] ARADDR;
    logic [7:0]  ARLEN;
    logic [2:0]  ARSIZE;
    logic [1:0]  ARBURST;
    logic        ARVALID;
    logic        ARREADY;

    // Read Data Channel
    logic [3:0]  RID;
    logic [31:0] RDATA;
    logic [1:0]  RRESP;
    logic        RLAST;
    logic        RVALID;
    logic        RREADY;

    modport DRIVER (
        input  ACLK, ARESETn,
        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID, input AWREADY,
        output WDATA, WSTRB, WLAST, WVALID, input WREADY,
        input  BID, BRESP, BVALID, output BREADY,
        output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID, input ARREADY,
        input  RID, RDATA, RRESP, RLAST, RVALID, output RREADY
    );

    modport MONITOR (
        input ACLK, ARESETn,
        input AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID, AWREADY,
        input WDATA, WSTRB, WLAST, WVALID, WREADY,
        input BID, BRESP, BVALID, BREADY,
        input ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID, ARREADY,
        input RID, RDATA, RRESP, RLAST, RVALID, RREADY
    );

    // =========================================================================
    // Protocol assertions
    // =========================================================================

    // A1: no channel VALID may be asserted while in reset
    property p_reset_idle;
        @(posedge ACLK) !ARESETn |-> (!AWVALID && !WVALID && !BVALID && !ARVALID && !RVALID);
    endproperty
    a_reset_idle: assert property (p_reset_idle)
        else $error("[ASSERT] A channel VALID is high during reset");

    // A2/A3/A4: VALID must stay high & stable once asserted, until the READY handshake completes
    property p_awvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn) (AWVALID && !AWREADY) |=> AWVALID;
    endproperty
    a_awvalid_stable: assert property (p_awvalid_stable)
        else $error("[ASSERT] AWVALID dropped before AWREADY handshake");

    property p_wvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn) (WVALID && !WREADY) |=> WVALID;
    endproperty
    a_wvalid_stable: assert property (p_wvalid_stable)
        else $error("[ASSERT] WVALID dropped before WREADY handshake");

    property p_arvalid_stable;
        @(posedge ACLK) disable iff (!ARESETn) (ARVALID && !ARREADY) |=> ARVALID;
    endproperty
    a_arvalid_stable: assert property (p_arvalid_stable)
        else $error("[ASSERT] ARVALID dropped before ARREADY handshake");

    // A5: only OKAY/SLVERR are legal responses from this slave
    property p_bresp_legal;
        @(posedge ACLK) disable iff (!ARESETn) BVALID |-> (BRESP inside {2'b00, 2'b10});
    endproperty
    a_bresp_legal: assert property (p_bresp_legal)
        else $error("[ASSERT] Illegal BRESP value");

    property p_rresp_legal;
        @(posedge ACLK) disable iff (!ARESETn) RVALID |-> (RRESP inside {2'b00, 2'b10});
    endproperty
    a_rresp_legal: assert property (p_rresp_legal)
        else $error("[ASSERT] Illegal RRESP value");

    // A6: no unknowns on VALID signals once out of reset
    property p_no_x_valid;
        @(posedge ACLK) disable iff (!ARESETn)
            !$isunknown({AWVALID, WVALID, BVALID, ARVALID, RVALID});
    endproperty
    a_no_x_valid: assert property (p_no_x_valid)
        else $error("[ASSERT] X detected on a VALID signal");

    // Note: RLAST-vs-burst-length correctness (i.e. RLAST appears on exactly the
    // Nth beat of an N-beat burst) is checked functionally in the scoreboard,
    // since it needs the burst length context (AxLEN) that a single-cycle
    // property can't cleanly carry.

endinterface