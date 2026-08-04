// =============================================================================
// axi4_transaction.sv - randomizable AXI4 transaction
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_transaction;

    localparam int         MAX_BEATS = 8;
    localparam bit [31:0]  ADDR_SPAN = 32'h0000_0400;   // 1KB: valid = 0x000-0x3FC

    rand bit [3:0]  id;
    rand bit [31:0] addr;
    rand bit [7:0]  len;          // AxLEN = beats-1
    rand bit [2:0]  size;
    rand bit [1:0]  burst;        // 00 FIXED, 01 INCR, 10 WRAP
    rand bit        is_write;     // 1 = write, 0 = read
    rand bit        addr_legal;   // steers legal vs illegal address generation

    rand bit [31:0] wdata [MAX_BEATS];
    rand bit [3:0]  wstrb [MAX_BEATS];

    // captured results (filled in by driver/monitor)
    bit [31:0] rdata [MAX_BEATS];
    bit [1:0]  rresp [MAX_BEATS];
    bit [1:0]  bresp;

    function int beats();
        return len + 1;
    endfunction

    // ---------------- Constraints -------------------------------------------

    // burst length restricted to 1, 4, 8 beats  (AWLEN/ARLEN = beats-1)
    constraint c_len { len inside {8'd0, 8'd3, 8'd7}; }

    // burst type limited to FIXED, INCR, WRAP (never the reserved 2'b11)
    constraint c_burst { burst inside {2'b00, 2'b01, 2'b10}; }

    // slave data width is fixed at 32 bits -> 4 bytes/beat
    constraint c_size { size == 3'b010; }

    // word aligned addresses only
    constraint c_align { addr[1:0] == 2'b00; }

    // 70% write / 30% read
    constraint c_rw_dist { is_write dist {1 := 70, 0 := 30}; }

    // 90% legal address / 10% illegal (negative testing)
    constraint c_legal_dist { addr_legal dist {1 := 90, 0 := 10}; }

    // address generation: legal addresses stay fully inside memory (with the
    // whole burst for INCR/WRAP), WRAP bursts must start on a wrap boundary,
    // illegal addresses are deliberately placed beyond the memory window
    constraint c_addr {
        solve len, burst, addr_legal before addr;
        if (addr_legal) {
            if (burst == 2'b10) (addr % ((len + 1) << 2)) == 0;   // WRAP boundary
            if (burst == 2'b00) addr < ADDR_SPAN;                  // FIXED: base only
            else                (addr + (len << 2)) < ADDR_SPAN;   // INCR/WRAP: full burst
        } else {
            addr inside {[ADDR_SPAN : ADDR_SPAN + 32'h0000_03FC]};
        }
    }

    // valid, non-zero byte-enable patterns (single byte, half-word, full word)
    constraint c_wstrb {
        foreach (wstrb[i])
            wstrb[i] inside {4'b0001, 4'b0010, 4'b0100, 4'b1000,
                              4'b0011, 4'b0110, 4'b1100,
                              4'b1111};
    }

    // wdata intentionally left unconstrained (full 32-bit random range)

    function void display(string tag = "");
        $display("[TXN]%s id=%0d %s addr=0x%0h len=%0d(beats=%0d) burst=%0b legal=%0b",
                  tag, id, is_write ? "WRITE" : "READ",
                  addr, len, beats(), burst, addr_legal);
    endfunction

endclass