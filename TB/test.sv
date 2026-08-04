// =============================================================================
// axi4_test.sv - top-level test sequence: runs all mandatory test cases
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_test;

    virtual axi4_if     vif;
    axi4_environment    env;

    function new(virtual axi4_if vif);
        this.vif = vif;
        env = new(vif);
    endfunction

    task run();
        env.run();

        $display("\n================ TC1: RESET VERIFICATION ================");
        tc_reset();

        $display("\n================ TC2: SINGLE WRITE / SINGLE READ ================");
        tc_single_wr_rd();

        $display("\n================ TC3: 4-BEAT INCR BURST WRITE/READ ================");
        tc_incr4_burst();

        $display("\n================ TC4: FIXED BURST TRANSFER ================");
        tc_fixed_burst();

        $display("\n================ TC5: WRAPPING BURST TRANSFER ================");
        tc_wrap_burst();

        $display("\n================ TC6: PARTIAL WRITE USING WSTRB ================");
        tc_partial_wstrb();

        $display("\n================ TC7: INVALID ADDRESS ACCESS ================");
        tc_invalid_addr();

        $display("\n================ TC9: CONSECUTIVE BURST TRANSACTIONS ================");
        tc_consecutive_bursts();

        $display("\n================ TC10: ADDRESS-RANGE COVERAGE (MID / HIGH) ================");
        tc_addr_range_cov();

        $display("\n================ TC11: WSTRB PATTERN COVERAGE (SINGLE-BYTE / HALF-WORD) ================");
        tc_wstrb_patterns();

        $display("\n================ TC8: 20 RANDOM TRANSACTIONS ================");
        env.run_random(20);

        #100;
        env.scb.report();
        $display("Functional coverage = %0.2f %%", env.cov.get_coverage());
        $finish;
    endtask

    // ---- TC1: reset ---------------------------------------------------------
    task tc_reset();
        env.apply_reset(4);
        if (vif.AWVALID || vif.WVALID || vif.BVALID || vif.ARVALID || vif.RVALID)
            $error("[TC1] FAIL: a channel VALID signal is not idle after reset");
        else
            $display("[TC1] PASS: all channel VALID signals idle after reset, memory model cleared");
    endtask

    // ---- TC2: single beat write + read --------------------------------------
    task tc_single_wr_rd();
        bit [31:0] d[8] = '{0: 32'hDEAD_BEEF, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, default: 0};
        env.do_write(32'h0000_0010, 8'd0, 2'b01, d, s);
        env.do_read (32'h0000_0010, 8'd0, 2'b01);
    endtask

    // ---- TC3: 4-beat INCR burst ----------------------------------------------
    task tc_incr4_burst();
        bit [31:0] d[8] = '{0: 32'h1111_1111, 1: 32'h2222_2222, 2: 32'h3333_3333, 3: 32'h4444_4444, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, 1: 4'b1111, 2: 4'b1111, 3: 4'b1111, default: 0};
        env.do_write(32'h0000_0020, 8'd3, 2'b01, d, s);
        env.do_read (32'h0000_0020, 8'd3, 2'b01);
    endtask

    // ---- TC4: FIXED burst (same address, every beat) -------------------------
    task tc_fixed_burst();
        bit [31:0] d[8] = '{0: 32'hAAAA_0001, 1: 32'hAAAA_0002, 2: 32'hAAAA_0003, 3: 32'hAAAA_0004, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, 1: 4'b1111, 2: 4'b1111, 3: 4'b1111, default: 0};
        env.do_write(32'h0000_0040, 8'd3, 2'b00, d, s);
        env.do_read (32'h0000_0040, 8'd3, 2'b00);
    endtask

    // ---- TC5: WRAP burst (4 beats -> 16-byte wrap boundary, 0x50 is aligned) --
    task tc_wrap_burst();
        bit [31:0] d[8] = '{0: 32'hBEEF_0001, 1: 32'hBEEF_0002, 2: 32'hBEEF_0003, 3: 32'hBEEF_0004, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, 1: 4'b1111, 2: 4'b1111, 3: 4'b1111, default: 0};
        env.do_write(32'h0000_0050, 8'd3, 2'b10, d, s);
        env.do_read (32'h0000_0050, 8'd3, 2'b10);
    endtask

    // ---- TC6: partial write using WSTRB (lower half-word only) ---------------
    task tc_partial_wstrb();
        bit [31:0] d[8] = '{0: 32'hFFFF_FFFF, default: 0};
        bit [3:0]  s[8] = '{0: 4'b0011, default: 0};
        env.do_write(32'h0000_0060, 8'd0, 2'b01, d, s);
        env.do_read (32'h0000_0060, 8'd0, 2'b01);
    endtask

    // ---- TC7: invalid (out-of-range) address access -> expect SLVERR ---------
    task tc_invalid_addr();
        bit [31:0] d[8] = '{0: 32'hCAFE_CAFE, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, default: 0};
        env.do_write(32'h0000_0800, 8'd0, 2'b01, d, s);   // beyond 0x3FC
        env.do_read (32'h0000_0900, 8'd0, 2'b01);
    endtask

    // ---- TC9: consecutive bursts issued back-to-back --------------------------
    task tc_consecutive_bursts();
        bit [31:0] d[8] = '{0: 32'h0BAD_0001, 1: 32'h0BAD_0002, 2: 32'h0BAD_0003, 3: 32'h0BAD_0004, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, 1: 4'b1111, 2: 4'b1111, 3: 4'b1111, default: 0};
        env.do_write(32'h0000_0070, 8'd3, 2'b01, d, s);
        env.do_read (32'h0000_0070, 8'd3, 2'b01);
        env.do_write(32'h0000_0080, 8'd7, 2'b01, d, s);   // 8-beat burst immediately after
        env.do_read (32'h0000_0080, 8'd7, 2'b01);
    endtask

    // ---- TC10: hit the 'mid' (0x100-0x2FC) and 'high' (0x300-0x3FC)
    //            address-range coverage bins directly, rather than relying
    //            on random transactions to land there by chance --------------
    task tc_addr_range_cov();
        bit [31:0] d[8] = '{0: 32'hA0A0_A0A0, default: 0};
        bit [3:0]  s[8] = '{0: 4'b1111, default: 0};

        // mid range : 0x100 - 0x2FC
        env.do_write(32'h0000_0180, 8'd0, 2'b01, d, s);
        env.do_read (32'h0000_0180, 8'd0, 2'b01);

        // high range : 0x300 - 0x3FC
        env.do_write(32'h0000_0380, 8'd0, 2'b01, d, s);
        env.do_read (32'h0000_0380, 8'd0, 2'b01);
    endtask

    // ---- TC11: hit every remaining WSTRB bin (single-byte x4, and the
    //            half-word patterns not already exercised by TC6) so
    //            cp_wstrb closes without depending on randomization ---------
    task tc_wstrb_patterns();
        bit [31:0] d[8];
        bit [3:0]  s[8];
        bit [3:0]  patterns[6] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000, 4'b0110, 4'b1100};
        bit [31:0] base_addr = 32'h0000_0090;   // stays inside the 'low' address bin

        foreach (patterns[i]) begin
            d = '{0: 32'hB0B0_0000 + i, default: 0};
            s = '{0: patterns[i], default: 0};
            env.do_write(base_addr + (i*4), 8'd0, 2'b01, d, s);
            env.do_read (base_addr + (i*4), 8'd0, 2'b01);
        end
    endtask

endclass