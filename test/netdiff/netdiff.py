#!/usr/bin/env python3
"""Differential test of this repository's primitive models against Vivado's unisims, on the
primitive instances of a netlist.

  netdiff.py <funcsim netlist.v> <work dir> [--prims A,B] [--per 4] [--cycles 4000]

For each primitive type, up to --per instances with distinct parameter sets are taken from the
netlist as they are: parameters and constant pin ties kept, every other input driven by random
stimulus, clocks by the test clock.  The same stimulus runs through
  * Vivado's unisims in xsim (the reference), and
  * the models of this repository in Verilator (--no-timing, as a netlist build uses them),
and every output is compared cycle by cycle.  Needs Vivado (xvlog/xelab/xsim) and Verilator on PATH.

Any write_verilog -mode funcsim netlist will do; example/example.tcl writes a small one:
  vivado -mode batch -source example/example.tcl -tclargs work/example_funcsim.v
"""
import argparse, os, random, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
UNISIMS = Path(os.environ['XILINX_VIVADO']) / 'data/verilog/src/unisims'


def ports(prim):
    """[(name, dir, width)] of the Vivado unisim's port list."""
    t = (UNISIMS / f'{prim}.v').read_text()
    out = []
    for d, w, names in re.findall(r'^\s*(input|output)\s+(?:wire\s+|reg\s+)?(\[[^\]]+\])?\s*([\w\s,]+?)\s*[;,]?\s*$', t, re.M):
        width = 1
        if w:
            hi, lo = [int(x) for x in w[1:-1].split(':')]
            width = abs(hi - lo) + 1
        for n in names.split(','):
            n = n.strip()
            if n and re.fullmatch(r'\w+', n):
                out.append((n, d, width))
    seen, res = set(), []
    for p in out:
        if p[0] not in seen:
            seen.add(p[0]); res.append(p)
    return res


def instances(netlist, prim):
    s = Path(netlist).read_text()
    for m in re.finditer(r'\n\s*' + prim + r'\s+(#\((.*?)\)\s*)?(\\\S+\s|\w+)\s*\((.*?)\);', s, re.S):
        params = m.group(2) or ''
        conns = dict(re.findall(r'\.(\w+)\(((?:[^()]|\([^()]*\))*)\)', m.group(4)))
        yield params.strip(), conns


def is_const(v):
    return bool(re.fullmatch(r"[\s{},]*(\d+'[bhd][0-9a-fA-FxXzZ_]+[\s{},]*)+", v)) and 'UNCONNECTED' not in v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('netlist'); ap.add_argument('work')
    ap.add_argument('--prims', default='CARRY8,MUXF7,MUXF8,SRL16E,SRLC32E,RAM32M,RAM32M16,RAM64M8,RAM32X1D,'
                    'RAMB18E2,RAMB36E2,DSP48E2,URAM288,FDRE,FDSE,LUT1,LUT2,LUT3,LUT4,LUT5,LUT6')
    ap.add_argument('--per', type=int, default=4); ap.add_argument('--cycles', type=int, default=4000)
    ap.add_argument('--pool', type=int, default=4, help='values per address input (0: any)')
    a = ap.parse_args()
    W = Path(a.work).resolve(); W.mkdir(parents=True, exist_ok=True)
    rng = random.Random(1)
    duts, ins, outs, clk_pins, word_lsb = [], [], [], ['C', 'CLK', 'WCLK', 'CLKARDCLK', 'CLKBWRCLK'], {}
    for prim in a.prims.split(','):
        pl = ports(prim); seen = set()
        for params, conns in instances(a.netlist, prim):
            key = re.sub(r'\.MATRIX_ID\([^)]*\)|\.INIT\w*\([^)]*\)', '', params) + str(sorted(k for k, v in conns.items() if is_const(v)))
            if key in seen:
                continue
            seen.add(key)
            i = len(duts); c = []
            for n, d, w in pl:
                v = conns.get(n)
                if d == 'output':
                    if v is not None and 'UNCONNECTED' not in v:
                        outs.append((f'o{i}_{n}', w)); c.append(f'.{n}(o{i}_{n})')
                elif n in clk_pins:
                    c.append(f'.{n}(clk)')
                elif v is not None and is_const(v):
                    c.append(f'.{n}({v})')
                elif v is not None:
                    ins.append((f'i{i}_{n}', w)); c.append(f'.{n}(i{i}_{n})')
            duts.append(f'  {prim} {"#(" + params + ")" if params else ""} u{i} (' + ', '.join(c) + ');')
            word_lsb[f'i{i}'] = {'RAMB36E2': 5, 'RAMB18E2': 4}.get(prim, 0)   # address bits below the word
            if len([d for d in duts if d.startswith(f'  {prim} ')]) >= a.per:
                break
        print(f'{prim}: {len(seen)} parameter sets tested ({min(len(seen), a.per)})' if seen else f'{prim}: not in netlist')
    nin = sum(w for _, w in ins); nout = sum(w for _, w in outs)
    tb = ['`timescale 1ps/1ps', 'module tb(input clk);']
    tb += [f'  reg [{w - 1}:0] {n} = 0;' for n, w in ins] + [f'  wire [{w - 1}:0] {n};' for n, w in outs]
    tb += duts
    tb += [f'  reg [{nin - 1}:0] stim [0:{a.cycles - 1}];', '  integer cyc = 0, fo;',
           '  initial begin $readmemh("stim.hex", stim); fo = $fopen("out.txt", "w"); end',
           '  always @(posedge clk) begin',
           '    $fdisplay(fo, "%0d %h", cyc, {' + ', '.join(n for n, _ in outs) + '});',
           '    {' + ', '.join(n for n, _ in ins) + '} <= stim[cyc];',
           f'    cyc <= cyc + 1; if (cyc == {a.cycles - 1}) begin $fclose(fo); $finish; end',
           '  end', 'endmodule']
    (W / 'tb.v').write_text('\n'.join(tb) + '\n')
    # Address inputs take one of --pool values per instance, so ports collide and read back what was written.
    pools = {n: [rng.getrandbits(w) for _ in range(a.pool)] for n, w in ins if 'ADDR' in n and a.pool}
    def vec():
        vals = {n: rng.choice(pools[n]) if n in pools else rng.getrandbits(w) for n, w in ins}
        # Both ports writing one address in the same cycle is a design error the unisims answer with X or
        # a port-order rule that depends on the byte enables; the stimulus leaves it out (port B reads instead).
        for n in vals:
            i = n.split('_')[0]
            a, b = vals.get(i + '_ADDRARDADDR', vals.get(i + '_ADDR_A')), vals.get(i + '_ADDRBWRADDR', vals.get(i + '_ADDR_B'))
            if n in (i + '_WEBWE', i + '_RDB_WR_B') and a is not None and b is not None and a >> word_lsb[i] == b >> word_lsb[i]:
                vals[n] = 0
        v = 0
        for n, w in ins:
            v = v << w | vals[n]
        return v
    (W / 'stim.hex').write_text(''.join('%x\n' % vec() for _ in range(a.cycles)))
    (W / 'top.v').write_text('`timescale 1ps/1ps\nmodule top; reg clk = 0; always #2500 clk = ~clk;\n'
                             '  initial #120000 forever #2500 clk = ~clk;\n  tb t(.clk(clk)); endmodule\n'.replace(
                             'always #2500 clk = ~clk;\n  initial #120000 forever', 'initial #120000 forever'))
    (W / 'main.cpp').write_text('#include "Vtb.h"\n#include "verilated.h"\nint main(int c, char** v) {\n'
                                '  Verilated::commandArgs(c, v); Vtb t; while (!Verilated::gotFinish()) {\n'
                                '  t.clk = 0; t.eval(); t.clk = 1; t.eval(); } t.final(); }\n')
    run = lambda cmd, d: subprocess.run(cmd, cwd=d, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    for d in ('xsim', 'vl'):
        (W / d).mkdir(exist_ok=True); (W / d / 'stim.hex').write_text((W / 'stim.hex').read_text())
    run(f'xvlog {W}/tb.v {W}/top.v $XILINX_VIVADO/data/verilog/src/glbl.v > xvlog.log && '
        'xelab -L unisims_ver -L secureip top glbl -s s > xelab.log && xsim s -R > xsim.log', W / 'xsim')
    run(f'verilator --cc --exe --build -j 8 --no-timing -Wno-fatal -Wno-lint -Wno-style -y {REPO} --top-module tb '
        f'{W}/tb.v {W}/main.cpp -o tb > build.log 2>&1 && ./obj_dir/tb > run.log', W / 'vl')
    ref = (W / 'xsim/out.txt').read_text().split('\n'); got = (W / 'vl/out.txt').read_text().split('\n')
    names = [n for n, _ in outs]; widths = [w for _, w in outs]
    bad = {}
    for r, g in zip(ref, got):
        if r == g or not r:
            continue
        cyc, rs = r.split(); gv = int(g.split()[1], 16)
        rv = int(re.sub('[xXzZ]', '0', rs), 16)
        known = int(''.join('0' if ch in 'xXzZ' else 'f' for ch in rs), 16)   # X/Z nibbles of the reference: any value
        sh = nout
        for n, w in zip(names, widths):
            sh -= w
            m = (known >> sh) & ((1 << w) - 1)
            if (rv >> sh) & m != (gv >> sh) & m:
                bad.setdefault(n, int(cyc))
    print(f'{len(ref) - 1} cycles, {len(outs)} outputs of {len(duts)} instances: '
          + ('PASS' if not bad else 'FAIL ' + ', '.join(f'{n} (first at cycle {c})' for n, c in sorted(bad.items(), key=lambda x: x[1]))))
    print('instances in', W / 'tb.v')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
