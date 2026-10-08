// Small design whose synthesized netlist uses LUTs, FDRE, FDSE, CARRY8, MUXF7/MUXF8, SRLC32E, RAM64M8,
// RAM64M, RAM64X1D, DSP48E2, RAMB18E2, RAMB36E2 and URAM288; example.tcl writes its funcsim netlist
// for netdiff.py.
module example (
  input             clk,
  input      [47:0] a, b,
  input      [26:0] x,
  input      [17:0] y,
  input      [63:0] w,
  input      [5:0]  sel,
  input             rst,
  input      [7:0]  d,
  input             we_a, we_b,
  input      [9:0]  addr_a, addr_b,
  input      [35:0] din_a, din_b,
  input             uen, uwe,
  input      [12:0] uaddr,
  input      [71:0] udin,
  input             lwe,
  input      [5:0]  laddr, lraddr,
  input      [6:0]  ldin,
  input             we_c, we_d,
  input      [9:0]  addr_c, addr_d,
  input      [17:0] din_c, din_d,
  input             mwe, nwe,
  input      [5:0]  maddr, mraddr, naddr, nraddr,
  input      [2:0]  mdin,
  input             ndin,
  output reg [47:0] sum,
  output reg [44:0] prod,
  output reg        bit_o,
  output     [7:0]  dly,
  output reg [35:0] dout_a, dout_b,
  output reg [71:0] udout,
  output reg [7:0]  cnt,
  output     [6:0]  ldout,
  output reg [17:0] dout_c, dout_d,
  output     [2:0]  mdout,
  output            ndout
);
  always @(posedge clk) sum <= a + b;

  reg [26:0] xr; reg [17:0] yr;
  always @(posedge clk) begin xr <= x; yr <= y; prod <= $signed(xr) * $signed(yr); end

  always @(posedge clk) bit_o <= w[sel];

  always @(posedge clk) if (rst) cnt <= 8'hff; else cnt <= cnt + 8'd1;

  reg [7:0] sr [0:19];
  integer i;
  always @(posedge clk) begin sr[0] <= d; for (i = 1; i < 20; i = i + 1) sr[i] <= sr[i - 1]; end
  assign dly = sr[19];

  (* ram_style = "block" *) reg [35:0] bram [0:1023];
  always @(posedge clk) begin dout_a <= bram[addr_a]; if (we_a) bram[addr_a] <= din_a; end
  always @(posedge clk) begin if (we_b) begin bram[addr_b] <= din_b; dout_b <= din_b; end else dout_b <= bram[addr_b]; end

  (* ram_style = "ultra" *) reg [71:0] uram [0:8191];
  reg [71:0] uq;
  always @(posedge clk) if (uen) begin if (uwe) uram[uaddr] <= udin; else uq <= uram[uaddr]; end
  always @(posedge clk) udout <= uq;

  (* ram_style = "distributed" *) reg [6:0] lram [0:63];
  always @(posedge clk) if (lwe) lram[laddr] <= ldin;
  assign ldout = lram[lraddr];

  (* ram_style = "block" *) reg [17:0] bram18 [0:1023];
  always @(posedge clk) begin dout_c <= bram18[addr_c]; if (we_c) bram18[addr_c] <= din_c; end
  always @(posedge clk) begin dout_d <= bram18[addr_d]; if (we_d) bram18[addr_d] <= din_d; end

  (* ram_style = "distributed" *) reg [2:0] mram [0:63];
  (* ram_style = "distributed" *) reg nram [0:63];
  integer k;
  initial for (k = 0; k < 64; k = k + 1) begin mram[k] = k * 5; nram[k] = k % 5 == 1; end
  always @(posedge clk) if (mwe) mram[maddr] <= mdin;
  assign mdout = mram[mraddr];
  always @(posedge clk) if (nwe) nram[naddr] <= ndin;
  assign ndout = nram[nraddr];
endmodule
