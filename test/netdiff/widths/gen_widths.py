#!/usr/bin/env python3
"""Writes widths.v: RAMB18E2 and RAMB36E2 instances at every modelled port width, in true dual port with
equal and mixed port widths, single-port ROM/RAM use (port B unused, as Vivado maps narrow ROMs), each
write mode and both output-register settings, with random INIT/INITP contents and random INIT_A/B/SRVAL.
widths.tcl synthesizes it (the primitives pass through unchanged) into the funcsim netlist netdiff.py takes."""
import random
from pathlib import Path

rng = random.Random(9)
h = lambda bits: f"{bits}'h{rng.getrandbits(bits):0{(bits + 3) // 4}x}"
cases = []
for prim, full in (('RAMB18E2', 18), ('RAMB36E2', 36)):
    ws = [1, 2, 4, 9, 18] + ([36] if full == 36 else [])
    for w in ws:                                   # equal widths, true dual port
        cases.append((prim, w, w, 'COMMON'))
    for a, b in ((9, full), (full, 9), (4, 9), (1, full), (2, 4), (9, 1)):   # mixed port widths
        cases.append((prim, a, b, 'COMMON'))
    for w in ws:                                   # port B unused (single-port ROM/RAM), as Vivado maps ROMs
        cases.append((prim, w, 0, 'INDEPENDENT'))
out = ['module widths(input clk, input [4095:0] i, output [4095:0] o);']
bit = 0
modes = ['WRITE_FIRST', 'READ_FIRST', 'NO_CHANGE']
for n, (prim, wa, wb, dom) in enumerate(cases):
    full = prim == 'RAMB36E2'
    dw, pw, aw, ni, nip = (32, 4, 15, 128, 16) if full else (16, 2, 14, 64, 8)
    W = dw + pw
    p = [f'.CLOCK_DOMAINS("{dom}")', f'.DOA_REG({n % 2})', f'.DOB_REG({(n // 2) % 2})',
         f'.READ_WIDTH_A({wa})', f'.WRITE_WIDTH_A({wa})', f'.READ_WIDTH_B({wb})', f'.WRITE_WIDTH_B({wb})',
         f'.WRITE_MODE_A("{modes[n % 3]}")', f'.WRITE_MODE_B("{modes[(n + 1) % 3]}")',
         f'.INIT_A({h(W)})', f'.INIT_B({h(W)})', f'.SRVAL_A({h(W)})', f'.SRVAL_B({h(W)})']
    p += [f'.INIT_{k:02X}({h(256)})' for k in range(ni)] + [f'.INITP_{k:02X}({h(256)})' for k in range(nip)]
    nb = pw
    def take(width):
        global bit
        s = f'i[{bit + width - 1}:{bit}]'; bit += width; return s
    c = ['.CLKARDCLK(clk)', '.CLKBWRCLK(clk)', f'.ADDRARDADDR({take(aw)})', f'.DINADIN({take(dw)})', f'.DINPADINP({take(pw)})',
         f'.ENARDEN({take(1)})', f'.REGCEAREGCE({take(1)})', f'.RSTRAMARSTRAM({take(1)})', f'.RSTREGARSTREG({take(1)})',
         f'.WEA({take(nb)})']
    if wb:
        c += [f'.ADDRBWRADDR({take(aw)})', f'.DINBDIN({take(dw)})', f'.DINPBDINP({take(pw)})', f'.ENBWREN({take(1)})',
              f'.REGCEB({take(1)})', f'.RSTRAMB({take(1)})', f'.RSTREGB({take(1)})', f'.WEBWE({{{2 * nb}{{1\'b0}}}} | {take(nb)})']
    else:
        c += [f".ADDRBWRADDR({aw}'h0)", f".DINBDIN({dw}'h0)", f".DINPBDINP({pw}'h0)", ".ENBWREN(1'b0)", ".REGCEB(1'b0)",
              ".RSTRAMB(1'b0)", ".RSTREGB(1'b0)", f".WEBWE({2 * nb}'h0)"]
    c += [f'.DOUTADOUT(o_{n}_a)', f'.DOUTPADOUTP(op_{n}_a)', f'.DOUTBDOUT(o_{n}_b)', f'.DOUTPBDOUTP(op_{n}_b)']
    out += [f'  wire [{dw - 1}:0] o_{n}_a, o_{n}_b; wire [{pw - 1}:0] op_{n}_a, op_{n}_b;',
            f'  (* DONT_TOUCH = "true" *) {prim} #(' + ', '.join(p) + f') u{n} (' + ', '.join(c) + ');']
assert bit <= 4096, bit
xs = ' ^ '.join(f'{{{{op_{n}_a, o_{n}_a, op_{n}_b, o_{n}_b}}}}' for n in range(len(cases)))
out += [f'  assign o = {{4096{{1\'b0}}}} | ({xs});', 'endmodule']
Path(__file__).with_name('widths.v').write_text('\n'.join(out) + '\n')
print(len(cases), 'instances')
