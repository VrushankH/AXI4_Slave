// =============================================================================
// axi4_coverage.sv - functional coverage collector
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_coverage;

    mailbox #(axi4_transaction) mon2cov;
    axi4_transaction            tr;

    covergroup cg;
        option.per_instance = 1;

        cp_burst_type: coverpoint tr.burst {
            bins fixed = {2'b00};
            bins incr  = {2'b01};
            bins wrap  = {2'b10};
        }

        cp_burst_len: coverpoint tr.len {
            bins len1 = {8'd0};
            bins len4 = {8'd3};
            bins len8 = {8'd7};
        }

        cp_rw: coverpoint tr.is_write {
            bins write = {1};
            bins read  = {0};
        }

        // write-strobe patterns (writes only)
        cp_wstrb: coverpoint tr.wstrb[0] iff (tr.is_write) {
            bins single_byte[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
            bins half_word[]   = {4'b0011, 4'b0110, 4'b1100};
            bins full_word     = {4'b1111};
        }

        // response type - OKAY vs SLVERR, from BRESP on writes, RRESP[0] on reads
        cp_resp: coverpoint (tr.is_write ? tr.bresp : tr.rresp[0]) {
            bins okay   = {2'b00};
            bins slverr = {2'b10};
        }

        cp_addr_range: coverpoint tr.addr {
            bins low     = {[32'h000 : 32'h0FC]};
            bins mid     = {[32'h100 : 32'h2FC]};
            bins high    = {[32'h300 : 32'h3FC]};
            bins illegal = {[32'h400 : 32'hFFFF_FFFF]};
        }

        // cross coverage: burst type against read/write selection
        cx_burst_rw: cross cp_burst_type, cp_rw;
    endgroup

    function new(mailbox #(axi4_transaction) mon2cov);
        this.mon2cov = mon2cov;
        cg = new();
    endfunction

    task run();
        forever begin
            mon2cov.get(tr);
            cg.sample();
        end
    endtask

    function real get_coverage();
        return cg.get_coverage();
    endfunction

endclass