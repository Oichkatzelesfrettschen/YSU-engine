"""
SASS RE: Binary Encoding Analyzer (v2 — parses cuobjdump .sass format)

Reads the .sass output from cuobjdump -sass (not nvdisasm -raw).
In this format, each instruction has:
  1. An assembly line:   /*0080*/  FADD R2, R2, R3 ;
  2. An encoding line:   /* 0x0000000905027221 */
  3. A control line:     /* 0x004fc80000000000 */

The encoding word is 64 bits; the control word is 64 bits.
Together they form the 128-bit instruction encoding.

Usage:
  python encoding_analysis.py <results_dir>
"""

import sys
import os
import re
from collections import defaultdict


def parse_sass_with_encoding(path):
    """Parse cuobjdump -sass output, extracting instruction + encoding pairs."""
    instructions = []
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        # Match assembly line: /*addr*/  MNEMONIC operands ;
        m = re.match(r'\s*/\*([0-9a-fA-F]+)\*/\s+(?:@\S+\s+)?(\S+)\s*(.*?)\s*;', line)
        if m:
            addr = int(m.group(1), 16)
            mnemonic = m.group(2)
            operands = m.group(3).strip()

            # Next non-empty line should be the encoding word
            enc_word = None
            ctrl_word = None
            j = i + 1
            while j < len(lines) and j <= i + 4:
                enc_m = re.search(r'/\*\s*(0x[0-9a-fA-F]+)\s*\*/', lines[j])
                if enc_m:
                    val = int(enc_m.group(1), 16)
                    if enc_word is None:
                        enc_word = val
                    elif ctrl_word is None:
                        ctrl_word = val
                        break
                j += 1

            if enc_word is not None and ctrl_word is not None:
                instructions.append({
                    'addr': addr,
                    'mnemonic': mnemonic,
                    'operands': operands,
                    'enc': enc_word,
                    'ctrl': ctrl_word,
                    'full_128': (ctrl_word << 64) | enc_word,
                    'file': os.path.basename(path),
                })
        i += 1
    return instructions


def extract_bits(val, lo, hi):
    """Extract bits [lo:hi] inclusive from val."""
    mask = (1 << (hi - lo + 1)) - 1
    return (val >> lo) & mask


def find_contiguous_fields(bits):
    """Group a sorted list of bit positions into contiguous ranges."""
    if not bits:
        return []
    fields = []
    start = prev = bits[0]
    for b in bits[1:]:
        if b == prev + 1:
            prev = b
        else:
            fields.append((start, prev))
            start = prev = b
    fields.append((start, prev))
    return fields


def analyze_opcode(instructions):
    """Identify the opcode field by finding bits constant across all instances
    of the same mnemonic, but varying across different mnemonics."""
    by_mn = defaultdict(list)
    for inst in instructions:
        by_mn[inst['mnemonic']].append(inst['enc'])

    # For each mnemonic with >=2 samples, find constant bits in the encoding word
    constant_masks = {}
    for mn, encs in by_mn.items():
        if len(encs) < 1:
            continue
        mask = 0xFFFFFFFFFFFFFFFF
        for e in encs[1:]:
            mask &= ~(encs[0] ^ e)
        constant_masks[mn] = (mask, encs[0] & mask)

    return constant_masks


def main():
    if len(sys.argv) < 2:
        print("Usage: python encoding_analysis.py <results_dir>")
        sys.exit(1)

    results_dir = sys.argv[1]
    if not os.path.isdir(results_dir):
        print(f"Error: {results_dir} is not a directory")
        sys.exit(1)

    # Find all .sass files
    sass_files = sorted([
        os.path.join(results_dir, f)
        for f in os.listdir(results_dir)
        if f.endswith('.sass')
    ])

    if not sass_files:
        print(f"No .sass files found in {results_dir}")
        sys.exit(1)

    print(f"Parsing {len(sass_files)} .sass files ...")
    all_instr = []
    for sf in sass_files:
        parsed = parse_sass_with_encoding(sf)
        print(f"  {os.path.basename(sf)}: {len(parsed)} instructions")
        all_instr.extend(parsed)

    print(f"\nTotal instructions parsed: {len(all_instr)}")

    # ── Group by mnemonic ──
    by_mn = defaultdict(list)
    for inst in all_instr:
        by_mn[inst['mnemonic']].append(inst)

    # ── Report ──
    report = []
    report.append("# SASS SM 8.9 (Ada) Encoding Analysis")
    report.append(f"Parsed {len(all_instr)} instructions from {len(sass_files)} files.\n")

    # Section 1: census
    report.append("## 1. Instruction Census\n")
    report.append(f"{'Mnemonic':<35} {'Count':>6}  {'Example Encoding (64-bit)':>20}  {'Control Word':>20}")
    report.append("-" * 95)
    for mn in sorted(by_mn, key=lambda m: -len(by_mn[m])):
        insts = by_mn[mn]
        ex = insts[0]
        report.append(f"{mn:<35} {len(insts):>6}  0x{ex['enc']:016X}  0x{ex['ctrl']:016X}")
    report.append("")

    # Section 2: opcode field extraction
    report.append("## 2. Opcode Field Analysis\n")
    report.append("For each mnemonic, bits constant across all instances are likely opcode bits.\n")

    constant_masks = analyze_opcode(all_instr)
    report.append(f"{'Mnemonic':<35} {'#Insts':>6}  {'Constant Mask':>20}  {'Opcode Value':>20}  Low 16 bits")
    report.append("-" * 110)
    for mn in sorted(constant_masks, key=lambda m: -len(by_mn[m])):
        mask, val = constant_masks[mn]
        n = len(by_mn[mn])
        low16 = val & 0xFFFF
        report.append(f"{mn:<35} {n:>6}  0x{mask:016X}  0x{val:016X}  0x{low16:04X}")
    report.append("")

    # Section 3: register field diff analysis (top 10 mnemonics with >2 instances)
    report.append("## 3. Register Field Analysis (bit diffs)\n")
    report.append("Compare pairs of same-mnemonic instructions to find register encoding positions.\n")

    analyzed = 0
    for mn in sorted(by_mn, key=lambda m: -len(by_mn[m])):
        insts = by_mn[mn]
        if len(insts) < 3:
            continue
        if analyzed >= 15:
            break
        analyzed += 1

        report.append(f"### {mn} ({len(insts)} instances)\n")
        # Show first few encodings
        for inst in insts[:6]:
            report.append(f"  0x{inst['enc']:016X}  {inst['mnemonic']} {inst['operands']}")

        # XOR all pairs to find varying bits
        all_diff = 0
        for a in insts:
            for b in insts:
                all_diff |= a['enc'] ^ b['enc']

        diff_bits = [b for b in range(64) if (all_diff >> b) & 1]
        fields = find_contiguous_fields(diff_bits)

        if fields:
            report.append(f"\n  Varying bit fields: {fields}")
            for lo, hi in fields:
                width = hi - lo + 1
                vals = set()
                for inst in insts:
                    vals.add(extract_bits(inst['enc'], lo, hi))
                vals_str = ', '.join(f'0x{v:X}' for v in sorted(vals))
                report.append(f"    bits [{lo}:{hi}] ({width}b): unique values = {{{vals_str}}}")

            # Try to correlate with register names
            report.append("\n  Register correlation:")
            for inst in insts[:4]:
                regs = re.findall(r'R(\d+)', inst['operands'])
                reg_str = ', '.join(f'R{r}' for r in regs)
                field_vals = []
                for lo, hi in fields:
                    v = extract_bits(inst['enc'], lo, hi)
                    field_vals.append(f"[{lo}:{hi}]=0x{v:X}")
                report.append(f"    {' '.join(field_vals)}  ->  {reg_str}  ({inst['operands']})")

        report.append("")

    # Section 4: Control word analysis
    report.append("## 4. Control Word Patterns\n")
    report.append("The control word (second 64-bit QWORD) encodes scheduling hints,")
    report.append("stall counts, barrier dependencies, etc.\n")

    ctrl_counts = defaultdict(int)
    for inst in all_instr:
        ctrl_counts[inst['ctrl']] += 1

    report.append(f"{'Control Word':>20}  {'Count':>6}  Stall bits [3:0]  Yield [4]  Barrier [8:5]")
    report.append("-" * 80)
    for ctrl, cnt in sorted(ctrl_counts.items(), key=lambda x: -x[1])[:30]:
        stall = ctrl & 0xF
        yield_bit = (ctrl >> 4) & 1
        barrier = (ctrl >> 5) & 0xF
        report.append(f"0x{ctrl:016X}  {cnt:>6}  stall={stall}  yield={yield_bit}  bar=0x{barrier:X}")
    report.append("")

    # Write report
    out_path = os.path.join(results_dir, "ENCODING_ANALYSIS.md")
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))
    print(f"\nReport written to: {out_path}")
    print(f"  {len(report)} lines")


if __name__ == '__main__':
    main()
