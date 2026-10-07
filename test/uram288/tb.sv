`timescale 1ps/1ps
// Random two-port traffic into a chain of DEPTH URAMs built from the model (URAM288_MODEL, this
// repository's URAM288.v renamed) and one from Vivado's unisims URAM288, side by side; every cycle every
// output of every URAM must agree.  DEPTH 1 is a stand-alone URAM (CASCADE_ORDER NONE), DEPTH 2 and more a
// cascade (FIRST, MIDDLE.., LAST) whose URAMs are selected by ADDR[13:12].  Only the first URAM's port
// pins matter in a cascade; the others get random pins all the same.  xsim only.
module tb;
  parameter integer DEPTH = 1;
  parameter OREG_A = "TRUE", OREG_B = "TRUE", EXT_A = "FALSE", EXT_B = "FALSE", BWE_MODE = "PARITY_INDEPENDENT";
  parameter REG_CAS = "FALSE";
  parameter integer RST_PCT = 0;
  localparam [10:0] MASK = DEPTH == 1 ? 11'h7FF : DEPTH == 2 ? 11'h7FE : 11'h7FC;
  reg clk = 0; always #2500 clk = ~clk;
  reg [22:0] addr_a [DEPTH], addr_b [DEPTH]; reg [71:0] din_a [DEPTH], din_b [DEPTH];
  reg [8:0] bwe_a [DEPTH], bwe_b [DEPTH];
  reg en_a [DEPTH], en_b [DEPTH], wr_a [DEPTH], wr_b [DEPTH], rst_a [DEPTH], rst_b [DEPTH], ce_a [DEPTH], ce_b [DEPTH];
  // all outputs of URAM i (O0 unisim, O1 model); C[i] = O[i-1] feeds URAM i's CAS_IN_* (C[0] = 0)
  wire [511:0] O0 [DEPTH], O1 [DEPTH], C0 [DEPTH+1], C1 [DEPTH+1];
  assign C0[0] = 512'h0; assign C1[0] = 512'h0;
`define URAM(MOD, NAME, O, C) MOD #(.OREG_A(OREG_A), .OREG_B(OREG_B), .USE_EXT_CE_A(EXT_A), .USE_EXT_CE_B(EXT_B), \
    .BWE_MODE_A(BWE_MODE), .BWE_MODE_B(BWE_MODE), .CASCADE_ORDER_A(ORD), .CASCADE_ORDER_B(ORD), .REG_CAS_A(REG_CAS), \
    .REG_CAS_B(REG_CAS), .SELF_ADDR_A(SELF), .SELF_ADDR_B(SELF), .SELF_MASK_A(MASK), .SELF_MASK_B(MASK)) NAME \
  (.CLK(clk), .ADDR_A(addr_a[i]), .ADDR_B(addr_b[i]), .DIN_A(din_a[i]), .DIN_B(din_b[i]), .BWE_A(bwe_a[i]), .BWE_B(bwe_b[i]), \
    .EN_A(en_a[i]), .EN_B(en_b[i]), .RDB_WR_A(wr_a[i]), .RDB_WR_B(wr_b[i]), .RST_A(rst_a[i]), .RST_B(rst_b[i]), \
    .OREG_CE_A(ce_a[i]), .OREG_CE_B(ce_b[i]), .OREG_ECC_CE_A(1'b1), .OREG_ECC_CE_B(1'b1), .INJECT_DBITERR_A(1'b0), \
    .INJECT_DBITERR_B(1'b0), .INJECT_SBITERR_A(1'b0), .INJECT_SBITERR_B(1'b0), .SLEEP(1'b0), \
    .CAS_IN_ADDR_A(C[i][511:489]), .CAS_IN_ADDR_B(C[i][488:466]), .CAS_IN_BWE_A(C[i][465:457]), .CAS_IN_BWE_B(C[i][456:448]), \
    .CAS_IN_DBITERR_A(C[i][447]), .CAS_IN_DBITERR_B(C[i][446]), .CAS_IN_DIN_A(C[i][445:374]), .CAS_IN_DIN_B(C[i][373:302]), \
    .CAS_IN_DOUT_A(C[i][301:230]), .CAS_IN_DOUT_B(C[i][229:158]), .CAS_IN_EN_A(C[i][157]), .CAS_IN_EN_B(C[i][156]), \
    .CAS_IN_RDACCESS_A(C[i][155]), .CAS_IN_RDACCESS_B(C[i][154]), .CAS_IN_RDB_WR_A(C[i][153]), .CAS_IN_RDB_WR_B(C[i][152]), \
    .CAS_IN_SBITERR_A(C[i][151]), .CAS_IN_SBITERR_B(C[i][150]), \
    .CAS_OUT_ADDR_A(O[i][511:489]), .CAS_OUT_ADDR_B(O[i][488:466]), .CAS_OUT_BWE_A(O[i][465:457]), .CAS_OUT_BWE_B(O[i][456:448]), \
    .CAS_OUT_DBITERR_A(O[i][447]), .CAS_OUT_DBITERR_B(O[i][446]), .CAS_OUT_DIN_A(O[i][445:374]), .CAS_OUT_DIN_B(O[i][373:302]), \
    .CAS_OUT_DOUT_A(O[i][301:230]), .CAS_OUT_DOUT_B(O[i][229:158]), .CAS_OUT_EN_A(O[i][157]), .CAS_OUT_EN_B(O[i][156]), \
    .CAS_OUT_RDACCESS_A(O[i][155]), .CAS_OUT_RDACCESS_B(O[i][154]), .CAS_OUT_RDB_WR_A(O[i][153]), .CAS_OUT_RDB_WR_B(O[i][152]), \
    .CAS_OUT_SBITERR_A(O[i][151]), .CAS_OUT_SBITERR_B(O[i][150]), .DBITERR_A(O[i][149]), .DBITERR_B(O[i][148]), \
    .DOUT_A(O[i][147:76]), .DOUT_B(O[i][75:4]), .RDACCESS_A(O[i][3]), .RDACCESS_B(O[i][2]), .SBITERR_A(O[i][1]), .SBITERR_B(O[i][0]))
  for (genvar i = 0; i < DEPTH; i++) begin : u
    localparam ORD = DEPTH == 1 ? "NONE" : i == 0 ? "FIRST" : i == DEPTH - 1 ? "LAST" : "MIDDLE";
    localparam [10:0] SELF = i;
    `URAM(URAM288, ref_, O0, C0);
    `URAM(URAM288_MODEL, dut, O1, C1);
    assign C0[i + 1] = O0[i]; assign C1[i + 1] = O1[i];
  end
  integer cyc, bad = 0, n, i, d;
  initial begin
    if (!$value$plusargs("n=%d", n)) n = 20000;
    for (i = 0; i < DEPTH; i++) begin
      addr_a[i] = 0; addr_b[i] = 0; din_a[i] = 0; din_b[i] = 0; bwe_a[i] = 0; bwe_b[i] = 0;
      en_a[i] = 0; en_b[i] = 0; wr_a[i] = 0; wr_b[i] = 0; rst_a[i] = 0; rst_b[i] = 0; ce_a[i] = 1; ce_b[i] = 1;
    end
    repeat (30) @(posedge clk);                     // past glbl's GSR
    for (cyc = 0; cyc < n; cyc++) begin
      @(negedge clk);
      d = 0;
      for (i = 0; i < DEPTH; i++)
        if (O0[i] !== O1[i]) begin
          d = 1; if (bad < 10) $display("cycle %0d URAM %0d: ref %h\n model %h", cyc, i, O0[i], O1[i]);
        end
      bad += d;
      for (i = 0; i < DEPTH; i++) begin
        en_a[i] = $urandom % 4 != 0; en_b[i] = $urandom % 4 != 0; wr_a[i] = $urandom % 2; wr_b[i] = $urandom % 2;
        addr_a[i] = {11'($urandom % 4), 9'h0, 3'($urandom)}; addr_b[i] = {11'($urandom % 4), 9'h0, 3'($urandom)};
        din_a[i] = {$urandom, $urandom, $urandom}; din_b[i] = {$urandom, $urandom, $urandom};
        bwe_a[i] = $urandom % 4 == 0 ? $urandom : 9'h1ff; bwe_b[i] = $urandom % 4 == 0 ? $urandom : 9'h1ff;
        ce_a[i] = $urandom % 3 != 0; ce_b[i] = $urandom % 3 != 0;
        rst_a[i] = ($urandom % 100) < RST_PCT; rst_b[i] = ($urandom % 100) < RST_PCT;
      end
    end
    $display("%s DEPTH %0d OREG %s/%s EXT_CE %s/%s %s REG_CAS %s RST %0d%%: %0d of %0d cycles differ", bad ? "FAIL" : "PASS",
             DEPTH, OREG_A, OREG_B, EXT_A, EXT_B, BWE_MODE, REG_CAS, RST_PCT, bad, n);
    $finish;
  end
endmodule
