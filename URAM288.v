`timescale 1 ps / 1 ps
//
// URAM288 (UltraScale+ UltraRAM, 4K x 72, two ports) for Verilator.
//
// A compact cycle model of the configurations that Vivado infers for xpm_memory and
// plain RTL memories: stand-alone or cascaded, no ECC, no input pipeline register,
// no sleep or auto-sleep, synchronous reset.  Other configurations stop at
// elaboration ($fatal) instead of simulating something else.
//
// Behaviour (checked cycle by cycle against Vivado 2024.2's unisims URAM288 in
// xsim, see test/uram288):
//   * Each port registers EN, RDB_WR (1 = write), ADDR[11:0], DIN and BWE on CLK.
//     The access then happens in that cycle: port A first, then port B, so B reads
//     what A wrote in the same cycle and A reads the old word when B writes it.
//   * BWE_MODE "PARITY_INDEPENDENT": BWE[i] writes DIN[8i+7:8i] (i < 8) and BWE[8]
//     the parity byte DIN[71:64]; "PARITY_INTERLEAVED": BWE[i] writes byte i and
//     parity bit 64+i.
//   * A write leaves DOUT unchanged.  DOUT is 0 until the port's first read, and on
//     a reset.  OREG "FALSE": the read word is on DOUT after the access cycle's
//     edge; OREG "TRUE": one cycle later, its register loaded every cycle that
//     OREG_CE is high (USE_EXT_CE "TRUE"), or when the port has a new access or had
//     a read in the cycle before (USE_EXT_CE "FALSE").
//   * RST (RST_MODE "SYNC") clears the output register, the read latch and DOUT
//     and cancels that cycle's read (a write still happens).
//   * ADDR[22:12] selects the URAM with SELF_ADDR/SELF_MASK as the unisim does.
//   * RDACCESS is high in the cycles DOUT shows a new read (OREG "TRUE": gated by
//     OREG_CE when USE_EXT_CE "TRUE").  ECC flags are 0.
//   * Cascade (CASCADE_ORDER FIRST, MIDDLE.., LAST): FIRST takes the port from its
//     pins, MIDDLE and LAST from CAS_IN_ADDR/BWE/DIN/EN/RDB_WR (REG_CAS "TRUE": one
//     cycle later, through a register held while CAS_IN_EN is low) and ignore their
//     pins; FIRST and MIDDLE pass the port on CAS_OUT_*.  Each URAM matches ADDR[22:12]
//     with its SELF_ADDR/SELF_MASK.  MIDDLE and LAST put on DOUT/RDACCESS their own
//     read or the cascade's (CAS_IN_DOUT/RDACCESS, registered with REG_CAS "TRUE"):
//     the one with RDACCESS high, their own if both, else the last choice (the
//     cascade's after a reset).  CAS_OUT_DOUT/RDACCESS = DOUT/RDACCESS.
//
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNUSEDPARAM */
module URAM288 #(
  parameter integer AUTO_SLEEP_LATENCY = 8,
  parameter integer AVG_CONS_INACTIVE_CYCLES = 10,
  parameter BWE_MODE_A = "PARITY_INTERLEAVED",
  parameter BWE_MODE_B = "PARITY_INTERLEAVED",
  parameter CASCADE_ORDER_A = "NONE",
  parameter CASCADE_ORDER_B = "NONE",
  parameter EN_AUTO_SLEEP_MODE = "FALSE",
  parameter EN_ECC_RD_A = "FALSE",
  parameter EN_ECC_RD_B = "FALSE",
  parameter EN_ECC_WR_A = "FALSE",
  parameter EN_ECC_WR_B = "FALSE",
  parameter IREG_PRE_A = "FALSE",
  parameter IREG_PRE_B = "FALSE",
  parameter [0:0] IS_CLK_INVERTED = 1'b0,
  parameter [0:0] IS_EN_A_INVERTED = 1'b0,
  parameter [0:0] IS_EN_B_INVERTED = 1'b0,
  parameter [0:0] IS_RDB_WR_A_INVERTED = 1'b0,
  parameter [0:0] IS_RDB_WR_B_INVERTED = 1'b0,
  parameter [0:0] IS_RST_A_INVERTED = 1'b0,
  parameter [0:0] IS_RST_B_INVERTED = 1'b0,
  parameter MATRIX_ID = "NONE",
  parameter integer NUM_UNIQUE_SELF_ADDR_A = 1,
  parameter integer NUM_UNIQUE_SELF_ADDR_B = 1,
  parameter integer NUM_URAM_IN_MATRIX = 1,
  parameter OREG_A = "TRUE",
  parameter OREG_B = "TRUE",
  parameter OREG_ECC_A = "FALSE",
  parameter OREG_ECC_B = "FALSE",
  parameter REG_CAS_A = "FALSE",
  parameter REG_CAS_B = "FALSE",
  parameter RST_MODE_A = "SYNC",
  parameter RST_MODE_B = "SYNC",
  parameter [10:0] SELF_ADDR_A = 11'h000,
  parameter [10:0] SELF_ADDR_B = 11'h000,
  parameter [10:0] SELF_MASK_A = 11'h7FF,
  parameter [10:0] SELF_MASK_B = 11'h7FF,
  parameter USE_EXT_CE_A = "FALSE",
  parameter USE_EXT_CE_B = "FALSE"
)(
  output [22:0] CAS_OUT_ADDR_A,
  output [22:0] CAS_OUT_ADDR_B,
  output [8:0] CAS_OUT_BWE_A,
  output [8:0] CAS_OUT_BWE_B,
  output CAS_OUT_DBITERR_A,
  output CAS_OUT_DBITERR_B,
  output [71:0] CAS_OUT_DIN_A,
  output [71:0] CAS_OUT_DIN_B,
  output [71:0] CAS_OUT_DOUT_A,
  output [71:0] CAS_OUT_DOUT_B,
  output CAS_OUT_EN_A,
  output CAS_OUT_EN_B,
  output CAS_OUT_RDACCESS_A,
  output CAS_OUT_RDACCESS_B,
  output CAS_OUT_RDB_WR_A,
  output CAS_OUT_RDB_WR_B,
  output CAS_OUT_SBITERR_A,
  output CAS_OUT_SBITERR_B,
  output DBITERR_A,
  output DBITERR_B,
  output [71:0] DOUT_A,
  output [71:0] DOUT_B,
  output RDACCESS_A,
  output RDACCESS_B,
  output SBITERR_A,
  output SBITERR_B,

  input [22:0] ADDR_A,
  input [22:0] ADDR_B,
  input [8:0] BWE_A,
  input [8:0] BWE_B,
  input [22:0] CAS_IN_ADDR_A,
  input [22:0] CAS_IN_ADDR_B,
  input [8:0] CAS_IN_BWE_A,
  input [8:0] CAS_IN_BWE_B,
  input CAS_IN_DBITERR_A,
  input CAS_IN_DBITERR_B,
  input [71:0] CAS_IN_DIN_A,
  input [71:0] CAS_IN_DIN_B,
  input [71:0] CAS_IN_DOUT_A,
  input [71:0] CAS_IN_DOUT_B,
  input CAS_IN_EN_A,
  input CAS_IN_EN_B,
  input CAS_IN_RDACCESS_A,
  input CAS_IN_RDACCESS_B,
  input CAS_IN_RDB_WR_A,
  input CAS_IN_RDB_WR_B,
  input CAS_IN_SBITERR_A,
  input CAS_IN_SBITERR_B,
  input CLK,
  input [71:0] DIN_A,
  input [71:0] DIN_B,
  input EN_A,
  input EN_B,
  input INJECT_DBITERR_A,
  input INJECT_DBITERR_B,
  input INJECT_SBITERR_A,
  input INJECT_SBITERR_B,
  input OREG_CE_A,
  input OREG_CE_B,
  input OREG_ECC_CE_A,
  input OREG_ECC_CE_B,
  input RDB_WR_A,
  input RDB_WR_B,
  input RST_A,
  input RST_B,
  input SLEEP
);

  initial begin
    if (EN_ECC_RD_A != "FALSE" || EN_ECC_RD_B != "FALSE" || EN_ECC_WR_A != "FALSE" || EN_ECC_WR_B != "FALSE" ||
        OREG_ECC_A != "FALSE" || OREG_ECC_B != "FALSE")
      $fatal(1, "URAM288 %m: ECC is not modelled");
    if (IREG_PRE_A != "FALSE" || IREG_PRE_B != "FALSE" || EN_AUTO_SLEEP_MODE != "FALSE")
      $fatal(1, "URAM288 %m: IREG_PRE and auto-sleep are not modelled");
    if (RST_MODE_A != "SYNC" || RST_MODE_B != "SYNC" || IS_CLK_INVERTED != 1'b0)
      $fatal(1, "URAM288 %m: only RST_MODE SYNC on a rising CLK is modelled");
  end

  localparam bit OREG_A_ON = OREG_A == "TRUE";
  localparam bit OREG_B_ON = OREG_B == "TRUE";
  localparam bit EXT_CE_A = USE_EXT_CE_A == "TRUE";
  localparam bit EXT_CE_B = USE_EXT_CE_B == "TRUE";
  // MIDDLE and LAST take the port from CAS_IN_* (REG_CAS "TRUE": registered), FIRST and MIDDLE drive CAS_OUT_*.
  localparam bit CIN_A = CASCADE_ORDER_A == "MIDDLE" || CASCADE_ORDER_A == "LAST";
  localparam bit CIN_B = CASCADE_ORDER_B == "MIDDLE" || CASCADE_ORDER_B == "LAST";
  localparam bit COUT_A = CASCADE_ORDER_A == "FIRST" || CASCADE_ORDER_A == "MIDDLE";
  localparam bit COUT_B = CASCADE_ORDER_B == "FIRST" || CASCADE_ORDER_B == "MIDDLE";
  localparam bit RCAS_A = CIN_A && REG_CAS_A == "TRUE";
  localparam bit RCAS_B = CIN_B && REG_CAS_B == "TRUE";

  reg [71:0] mem [0:4095];
  integer k;
  initial for (k = 0; k < 4096; k = k + 1) mem[k] = 72'h0;

  function automatic [71:0] bwe72(input [8:0] bwe, input independent);
    integer i;
    for (i = 0; i < 64; i = i + 1) bwe72[i] = bwe[i / 8];
    for (i = 0; i < 8; i = i + 1) bwe72[64 + i] = independent ? bwe[8] : bwe[i];
  endfunction

  // REG_CAS "TRUE": the cascade inputs registered (address, data, BWE and RDB_WR held while EN is low) and
  // the cascaded read data and RDACCESS.
  reg rc_en_a = 1'b0, rc_en_b = 1'b0, rc_wr_a = 1'b0, rc_wr_b = 1'b0, rc_racc_a = 1'b0, rc_racc_b = 1'b0;
  reg [22:0] rc_addr_a = 23'h0, rc_addr_b = 23'h0;
  reg [8:0] rc_bwe_a = 9'h0, rc_bwe_b = 9'h0;
  reg [71:0] rc_din_a = 72'h0, rc_din_b = 72'h0, rc_dout_a = 72'h0, rc_dout_b = 72'h0;

  // Port inputs: the pins after the inversion attributes, or the cascade.
  wire [22:0] p_addr_a = !CIN_A ? ADDR_A : RCAS_A ? rc_addr_a : CAS_IN_ADDR_A;
  wire [22:0] p_addr_b = !CIN_B ? ADDR_B : RCAS_B ? rc_addr_b : CAS_IN_ADDR_B;
  wire [71:0] p_din_a = !CIN_A ? DIN_A : RCAS_A ? rc_din_a : CAS_IN_DIN_A;
  wire [71:0] p_din_b = !CIN_B ? DIN_B : RCAS_B ? rc_din_b : CAS_IN_DIN_B;
  wire [8:0] p_bwe_a = !CIN_A ? BWE_A : RCAS_A ? rc_bwe_a : CAS_IN_BWE_A;
  wire [8:0] p_bwe_b = !CIN_B ? BWE_B : RCAS_B ? rc_bwe_b : CAS_IN_BWE_B;
  wire p_en_a = !CIN_A ? EN_A ^ IS_EN_A_INVERTED : RCAS_A ? rc_en_a : CAS_IN_EN_A;
  wire p_en_b = !CIN_B ? EN_B ^ IS_EN_B_INVERTED : RCAS_B ? rc_en_b : CAS_IN_EN_B;
  wire wr_a = !CIN_A ? RDB_WR_A ^ IS_RDB_WR_A_INVERTED : RCAS_A ? rc_wr_a : CAS_IN_RDB_WR_A;
  wire wr_b = !CIN_B ? RDB_WR_B ^ IS_RDB_WR_B_INVERTED : RCAS_B ? rc_wr_b : CAS_IN_RDB_WR_B;
  wire en_a = p_en_a & (&(~(p_addr_a[22:12] ^ SELF_ADDR_A) | SELF_MASK_A)) & ~SLEEP;
  wire en_b = p_en_b & (&(~(p_addr_b[22:12] ^ SELF_ADDR_B) | SELF_MASK_B)) & ~SLEEP;
  wire [11:0] ad_a = p_addr_a[11:0], ad_b = p_addr_b[11:0];
  wire [71:0] m_a = bwe72(p_bwe_a, BWE_MODE_A == "PARITY_INDEPENDENT");
  wire [71:0] m_b = bwe72(p_bwe_b, BWE_MODE_B == "PARITY_INDEPENDENT");
  wire rst_a = RST_A ^ IS_RST_A_INVERTED;
  wire rst_b = RST_B ^ IS_RST_B_INVERTED;

  // Registered access of each port (the unisim's ram_ce/ram_we/ram_addr/ram_data/ram_bwe).
  reg ce_a = 1'b0, we_a = 1'b0, ce_b = 1'b0, we_b = 1'b0;
  reg rst_a_r = 1'b0, rst_b_r = 1'b0;
  // Read latch, output register, first-read flag, read access (OREG "TRUE": its register and RDACCESS one
  // cycle later), last DOUT from this URAM rather than the cascade.
  reg [71:0] lat_a = 72'h0, lat_b = 72'h0, oreg_a = 72'h0, oreg_b = 72'h0;
  reg den_a = 1'b0, den_b = 1'b0, racc_a = 1'b0, racc_b = 1'b0, racc2_a = 1'b0, racc2_b = 1'b0;
  reg own_a_r = 1'b0, own_b_r = 1'b0;

  // This URAM's RDACCESS, the cascade's, and which one drives DOUT/RDACCESS (MIDDLE, LAST): the one with a
  // read, this URAM's if both, else the previous choice.
  wire racc_o_a = OREG_A_ON ? racc2_a : (ce_a && !we_a);
  wire racc_o_b = OREG_B_ON ? racc2_b : (ce_b && !we_b);
  wire racc_c_a = RCAS_A ? rc_racc_a : CAS_IN_RDACCESS_A;
  wire racc_c_b = RCAS_B ? rc_racc_b : CAS_IN_RDACCESS_B;
  wire own_a = !CIN_A || ((racc_c_a || racc_o_a) ? racc_o_a : own_a_r);
  wire own_b = !CIN_B || ((racc_c_b || racc_o_b) ? racc_o_b : own_b_r);

  always @(posedge CLK) begin
    // output registers load from the latch as it was before this edge
    if (rst_a || !OREG_A_ON) oreg_a <= 72'h0;
    else if (EXT_CE_A ? OREG_CE_A : (en_a || racc_a)) oreg_a <= lat_a;
    if (rst_b || !OREG_B_ON) oreg_b <= 72'h0;
    else if (EXT_CE_B ? OREG_CE_B : (en_b || racc_b)) oreg_b <= lat_b;

    den_a <= rst_a ? 1'b0 : (OREG_A_ON ? (ce_a && !we_a) : (en_a && !wr_a)) ? 1'b1 : den_a;
    den_b <= rst_b ? 1'b0 : (OREG_B_ON ? (ce_b && !we_b) : (en_b && !wr_b)) ? 1'b1 : den_b;
    racc_a <= rst_a ? 1'b0 : en_a && !wr_a;
    racc_b <= rst_b ? 1'b0 : en_b && !wr_b;
    racc2_a <= rst_a ? 1'b0 : racc_a && (!EXT_CE_A || OREG_CE_A);
    racc2_b <= rst_b ? 1'b0 : racc_b && (!EXT_CE_B || OREG_CE_B);
    own_a_r <= rst_a ? 1'b0 : own_a;
    own_b_r <= rst_b ? 1'b0 : own_b;

    // this edge's accesses, port A before port B
    if (en_a && wr_a) mem[ad_a] <= (p_din_a & m_a) | (mem[ad_a] & ~m_a);
    else if (rst_a) lat_a <= 72'h0;
    else if (en_a) lat_a <= mem[ad_a];
    if (en_b && wr_b) begin
      if (en_a && wr_a && ad_a == ad_b)
        mem[ad_b] <= (p_din_b & m_b) | (((p_din_a & m_a) | (mem[ad_a] & ~m_a)) & ~m_b);
      else
        mem[ad_b] <= (p_din_b & m_b) | (mem[ad_b] & ~m_b);
    end else if (rst_b) lat_b <= 72'h0;
    else if (en_b) begin
      if (en_a && wr_a && ad_a == ad_b) lat_b <= (p_din_a & m_a) | (mem[ad_a] & ~m_a);
      else lat_b <= mem[ad_b];
    end
    ce_a <= rst_a ? 1'b0 : en_a; we_a <= en_a && wr_a;
    ce_b <= rst_b ? 1'b0 : en_b; we_b <= en_b && wr_b;
    rst_a_r <= rst_a; rst_b_r <= rst_b;

    rc_en_a <= CAS_IN_EN_A;
    if (CAS_IN_EN_A) {rc_addr_a, rc_din_a, rc_bwe_a, rc_wr_a} <= {CAS_IN_ADDR_A, CAS_IN_DIN_A, CAS_IN_BWE_A, CAS_IN_RDB_WR_A};
    rc_en_b <= CAS_IN_EN_B;
    if (CAS_IN_EN_B) {rc_addr_b, rc_din_b, rc_bwe_b, rc_wr_b} <= {CAS_IN_ADDR_B, CAS_IN_DIN_B, CAS_IN_BWE_B, CAS_IN_RDB_WR_B};
    rc_racc_a <= rst_a ? 1'b0 : CAS_IN_RDACCESS_A;
    if (rst_a) rc_dout_a <= 72'h0; else if (CAS_IN_RDACCESS_A) rc_dout_a <= CAS_IN_DOUT_A;
    rc_racc_b <= rst_b ? 1'b0 : CAS_IN_RDACCESS_B;
    if (rst_b) rc_dout_b <= 72'h0; else if (CAS_IN_RDACCESS_B) rc_dout_b <= CAS_IN_DOUT_B;
  end

  assign DOUT_A = rst_a_r ? 72'h0 : !own_a ? (RCAS_A ? rc_dout_a : CAS_IN_DOUT_A) :
                  !den_a ? 72'h0 : OREG_A_ON ? oreg_a : lat_a;
  assign DOUT_B = rst_b_r ? 72'h0 : !own_b ? (RCAS_B ? rc_dout_b : CAS_IN_DOUT_B) :
                  !den_b ? 72'h0 : OREG_B_ON ? oreg_b : lat_b;
  assign RDACCESS_A = rst_a_r ? 1'b0 : own_a ? racc_o_a : racc_c_a;
  assign RDACCESS_B = rst_b_r ? 1'b0 : own_b ? racc_o_b : racc_c_b;
  assign DBITERR_A = 1'b0; assign DBITERR_B = 1'b0; assign SBITERR_A = 1'b0; assign SBITERR_B = 1'b0;
  assign CAS_OUT_ADDR_A = COUT_A ? p_addr_a : 23'h0; assign CAS_OUT_ADDR_B = COUT_B ? p_addr_b : 23'h0;
  assign CAS_OUT_BWE_A = COUT_A ? p_bwe_a : 9'h0; assign CAS_OUT_BWE_B = COUT_B ? p_bwe_b : 9'h0;
  assign CAS_OUT_DIN_A = COUT_A ? p_din_a : 72'h0; assign CAS_OUT_DIN_B = COUT_B ? p_din_b : 72'h0;
  assign CAS_OUT_EN_A = COUT_A & p_en_a; assign CAS_OUT_EN_B = COUT_B & p_en_b;
  assign CAS_OUT_RDB_WR_A = COUT_A & wr_a; assign CAS_OUT_RDB_WR_B = COUT_B & wr_b;
  assign CAS_OUT_DOUT_A = DOUT_A; assign CAS_OUT_DOUT_B = DOUT_B;
  assign CAS_OUT_RDACCESS_A = RDACCESS_A; assign CAS_OUT_RDACCESS_B = RDACCESS_B;
  assign CAS_OUT_DBITERR_A = 1'b0; assign CAS_OUT_DBITERR_B = 1'b0;
  assign CAS_OUT_SBITERR_A = 1'b0; assign CAS_OUT_SBITERR_B = 1'b0;
endmodule
/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */
