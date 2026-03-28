
// LOP3 with systematically chosen LUT values targeting edge cases
extern "C" __global__ void __launch_bounds__(32)
lop3_edge_luts(unsigned *out, const unsigned *a, const unsigned *b, const unsigned *c) {
    int i=threadIdx.x;
    unsigned va=a[i],vb=b[i],vc=c[i];
    unsigned r;
    // LUT 0x00: always zero
    asm volatile("lop3.b32 %0,%1,%2,%3,0x00;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16]=r;
    // LUT 0xFF: always ones
    asm volatile("lop3.b32 %0,%1,%2,%3,0xFF;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+1]=r;
    // LUT 0xAA: pass-through a
    asm volatile("lop3.b32 %0,%1,%2,%3,0xAA;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+2]=r;
    // LUT 0xCC: pass-through b
    asm volatile("lop3.b32 %0,%1,%2,%3,0xCC;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+3]=r;
    // LUT 0xF0: pass-through c
    asm volatile("lop3.b32 %0,%1,%2,%3,0xF0;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+4]=r;
    // LUT 0x80: a AND b AND c
    asm volatile("lop3.b32 %0,%1,%2,%3,0x80;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+5]=r;
    // LUT 0x96: a XOR b XOR c (parity)
    asm volatile("lop3.b32 %0,%1,%2,%3,0x96;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+6]=r;
    // LUT 0xCA: MUX: c ? a : b
    asm volatile("lop3.b32 %0,%1,%2,%3,0xCA;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+7]=r;
    // LUT 0xE8: majority vote
    asm volatile("lop3.b32 %0,%1,%2,%3,0xE8;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+8]=r;
    // LUT 0x01: NOR of all three: ~(a|b|c)
    asm volatile("lop3.b32 %0,%1,%2,%3,0x01;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+9]=r;
    // LUT 0x17: a ? ~(b|c) : ~c  (unusual)
    asm volatile("lop3.b32 %0,%1,%2,%3,0x17;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+10]=r;
    // LUT 0x69: XNOR of all three
    asm volatile("lop3.b32 %0,%1,%2,%3,0x69;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+11]=r;
    // LUT 0xD2: (a AND b) OR (NOT c)
    asm volatile("lop3.b32 %0,%1,%2,%3,0xD2;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+12]=r;
    // LUT 0x2D: carry generate for full adder
    asm volatile("lop3.b32 %0,%1,%2,%3,0x2D;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+13]=r;
    // LUT 0x55: NOT a
    asm volatile("lop3.b32 %0,%1,%2,%3,0x55;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+14]=r;
    // LUT 0x33: NOT b
    asm volatile("lop3.b32 %0,%1,%2,%3,0x33;":"=r"(r):"r"(va),"r"(vb),"r"(vc)); out[i*16+15]=r;
}
