// =============================================================================
// axi4_scoreboard.sv - golden reference memory model + self-checking compare
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_scoreboard;

    mailbox #(axi4_transaction) mon2scb;

    localparam bit [31:0] ADDR_SPAN = 32'h0000_0400;

    bit [31:0] ref_mem [0:255];
    int        pass_cnt;
    int        fail_cnt;

    function new(mailbox #(axi4_transaction) mon2scb);
        this.mon2scb = mon2scb;
        reset_model();
    endfunction

    // memory is cleared to zero on reset - keep the golden model in sync
    function void reset_model();
        foreach (ref_mem[i]) ref_mem[i] = '0;
    endfunction

    function bit addr_legal(bit [31:0] addr, bit [1:0] burst, bit [7:0] len);
        if (burst == 2'b00) return (addr < ADDR_SPAN);
        else                 return ((addr + (len << 2)) < ADDR_SPAN);
    endfunction

    function int word_idx(bit [31:0] addr, bit [1:0] burst, int beat);
        int base = addr[9:2];
        return (burst == 2'b00) ? base : (base + beat);   // FIXED stays put, else advances
    endfunction

    task run();
        axi4_transaction tr;
        forever begin
            mon2scb.get(tr);
            if (tr.is_write) check_write(tr);
            else              check_read(tr);
        end
    endtask

    task check_write(axi4_transaction tr);
        int beats       = tr.beats();
        bit legal       = addr_legal(tr.addr, tr.burst, tr.len);
        bit [1:0] exp_r = legal ? 2'b00 : 2'b10;

        if (legal) begin
            for (int i = 0; i < beats; i++) begin
                int idx = word_idx(tr.addr, tr.burst, i);
                for (int b = 0; b < 4; b++)
                    if (tr.wstrb[i][b])
                        ref_mem[idx][b*8 +: 8] = tr.wdata[i][b*8 +: 8];
            end
        end

        if (tr.bresp === exp_r) begin
            pass_cnt++;
            $display("[SCB] WRITE PASS addr=0x%0h burst=%0b len=%0d bresp=%0b",
                      tr.addr, tr.burst, tr.len, tr.bresp);
        end else begin
            fail_cnt++;
            $error("[SCB] WRITE FAIL addr=0x%0h expected BRESP=%0b got=%0b",
                    tr.addr, exp_r, tr.bresp);
        end
    endtask

    task check_read(axi4_transaction tr);
        int beats       = tr.beats();
        bit legal       = addr_legal(tr.addr, tr.burst, tr.len);
        bit [1:0] exp_r = legal ? 2'b00 : 2'b10;

        for (int i = 0; i < beats; i++) begin
            int idx             = word_idx(tr.addr, tr.burst, i);
            bit [31:0] exp_data = legal ? ref_mem[idx] : 32'h0;
            bit exp_last        = (i == beats - 1);
            bit beat_ok = (tr.rresp[i] === exp_r) &&
                          (!legal || (tr.rdata[i] === exp_data));

            if (beat_ok) begin
                pass_cnt++;
                $display("[SCB] READ  PASS beat=%0d addr=0x%0h data=0x%0h resp=%0b",
                          i, tr.addr, tr.rdata[i], tr.rresp[i]);
            end else begin
                fail_cnt++;
                $error("[SCB] READ  FAIL beat=%0d addr=0x%0h expected data=0x%0h resp=%0b got data=0x%0h resp=%0b",
                        i, tr.addr, exp_data, exp_r, tr.rdata[i], tr.rresp[i]);
            end
        end
    endtask

    function void report();
        $display("=====================================================");
        $display(" SCOREBOARD SUMMARY : PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        $display("=====================================================");
    endfunction

endclass