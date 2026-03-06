# SASS SM 8.9 (Ada) Encoding Analysis
Parsed 3107 instructions from 9 files.

## 1. Instruction Census

Mnemonic                             Count  Example Encoding (64-bit)          Control Word
-----------------------------------------------------------------------------------------------
NOP                                    496  0x000FC00000000000  0x0000000000007918
BRA                                    234  0x000FC0000383FFFF  0x0000000000007918
LOP3.LUT                               176  0x000FE200078E9600  0x000058000A067625
FFMA                                   168  0x004FC80000000006  0x0000000005097223
MOV                                    163  0x000FE40000000F00  0x0000000000087919
IADD3                                  115  0x002FC80007FFE800  0x0000000007077210
FMUL                                   108  0x000FC80000400000  0x0000000007077221
IMAD.IADD                              106  0x001FCA00078E0205  0x0D001F0006057F89
ISETP.GT.AND                           102  0x004FDA0003F04270  0x00001EC000000947
IMAD.SHL.U32                           102  0x000FCA00078E00FF  0x0000000205057212
IMAD.WIDE                              100  0x001FCC00078E0209  0x0000000402027981
LDG.E                                   94  0x000EA4000C1E1900  0x0000000200067301
FADD                                    92  0x000FD80000000000  0x0000000202078221
IMAD.MOV.U32                            87  0x000FE400078E00FF  0x0000000000087919
STG.E                                   64  0x000FE2000C101904  0x000000000000794D
BSSY                                    53  0x000FE20003800000  0x000000100000780C
BSYNC                                   53  0x000FEA0003800000  0x000000337F007947
S2R                                     52  0x000E220000002100  0x00000004FF097424
MUFU.RSQ                                49  0x0000620000001400  0xF300000000067810
EXIT                                    45  0x000FEA0003800000  0xFFFFFFF000007947
ULDC.64                                 44  0x000FC60000000A00  0x00005A0008027625
STS                                     39  0x0041E40000000800  0x0000000000007941
CALL.REL.NOINC                          35  0x000FEA0003C00000  0x0000000000007918
FMUL.FTZ                                35  0x003FE20000410000  0x3F00000003037820
ISETP.GT.U32.AND                        34  0x000FC80003F04070  0x0000000100037810
FSETP.GEU.AND                           32  0x000FDA0003F0E000  0x3F00000000008820
F2FP.F16.F32.PACK_AB                    21  0x080FE400000000FF  0x00000000FF05723E
FADD.FTZ                                20  0x000FE20000010000  0x000000A000000947
MUFU.RCP                                20  0x000E240000001000  0xBF80000002007423
IMAD                                    17  0x001FC800078E02FF  0x00005A0002027625
ISETP.GE.U32.AND                        17  0x000FCA0003F66070  0x00000001FF068424
LEA.HI.SX32                             16  0x000FE400078FFAFF  0x0000000000007941
FMUL.RZ                                 15  0x004FC8000040C000  0x0000000600007308
LEA                                     14  0x000FE200078010FF  0x0000000000007918
LEA.HI.X                                12  0x001FCA00000F1407  0x0000000502007986
PRMT                                    11  0x044FE400000000FF  0x0000771002067816
S2UR                                    11  0x000E620000005000  0x000090000000791A
LDS                                     10  0x000E280000000800  0x0000000502007986
HMMA.16816.F32                          10  0x044FF000000018FF  0x000000100C0C723C
DEPBAR.LE                                9  0x000FCE0000000000  0x00000000000579C3
UIADD3                                   9  0x000FE2000FFFE13F  0x0000000204047819
ISETP.GE.AND                             8  0x041FE20003F06270  0x00005A0000027625
FMNMX                                    8  0x004FC80003800000  0x0000000005007209
IMAD.MOV                                 8  0x000FE200078E02FF  0x000000050200720C
MUFU.EX2                                 8  0x000E240000000800  0x0000000404048220
MUFU.LG2                                 8  0x000E240000000C00  0xC1C0000005058421
MUFU.SIN                                 8  0x000FF00000000400  0x0000000600057308
MUFU.COS                                 8  0x000E240000000000  0x0000000500007221
STG.E.64                                 7  0x001FE2000C101B04  0x000000000000794D
BAR.SYNC.DEFER_BLOCKING                  7  0x000FE20000010000  0x0000000400037802
SHFL.BFLY                                6  0x004E2800000E0000  0x08201F0000027F89
SHF.R.S32.HI                             6  0x000FCA0000011400  0x0000000402027981
LDG.E.64                                 6  0x000EA8000C1E1B00  0x0000000402027981
SHF.R.U32.HI                             6  0x000FC80000011600  0x000000FF0900720C
SEL                                      5  0x000FE40004000000  0x000000050200720C
ISETP.NE.AND                             5  0x0C0FE20003F05270  0x000000FFFF061224
IMAD.U32                                 5  0x001FE2000F8E00FF  0x0000000600037C02
HADD2.F32                                4  0x000FE40000004100  0x0000000000077304
SHF.L.U32                                4  0x040FE200000006FF  0x000004B000007945
USHF.R.S32.HI                            4  0x000FE20008011404  0x0000580004047625
FLO.U32                                  3  0x000FF000000E0000  0x0000000200057309
POPC                                     3  0x000E700000000000  0x0000000600077300
SHF.L.W.U32.HI                           3  0x144FE40000010E02  0x0000000805077819
SHF.R.W.U32                              3  0x140FE40000001E02  0x0000000805097819
BRA.CONV                                 3  0x000FEA000B800000  0xFFFF0000FF037424
RET.REL.NODEC                            3  0x000FEA0003C3FFFF  0xFFFFFFF000007947
FSEL                                     3  0x000FE20005000000  0x0000000202090221
FSETP.GT.AND                             2  0x044FE20003F04000  0x3F80000002077421
SHFL.IDX                                 2  0x000E2800000E0000  0x0C401F0008097F89
UMOV                                     2  0x000FE20000000000  0xFFFFFFFF02057810
F2F.F64.F32                              2  0x008E700000201800  0x0000000A000A7310
DADD                                     2  0x002E4C0000000006  0x000000060408722B
VOTEU.ANY                                2  0x000FE400038E0100  0x00000004000472BD
ISETP.EQ.U32.AND                         2  0x002FCA000BF22070  0x00000000000673C4
FSETP.NEU.FTZ.AND                        2  0x000FDA0003F1D200  0x5F80000000040823
IMAD.WIDE.U32                            2  0x000FCA00078E0002  0x00005A0004067A11
BREV                                     1  0x004E300000000000  0x0000000200007300
FLO.U32.SH                               1  0x001E3000000E0400  0x0000000600047300
SHF.R.U32                                1  0x000FC40000001602  0x0000000609087212
SHF.L.U32.HI                             1  0x000FE20000010602  0x000058000A027625
BPT.TRAP                                 1  0x000FEA0000300000  0xFFFFFFF000007947
SHFL.DOWN                                1  0x000FE800000E0000  0x0C201F0000037F89
SHFL.UP                                  1  0x000FE800000E00FF  0x0C801F0007047F89
WARPSYNC                                 1  0x000FE80003800000  0x00000000FF037424
LEA.HI.X.SX32                            1  0x000FCA00000F0EFF  0x0000000402027981
LDG.E.U16                                1  0x000EA8000C1E1500  0x0000000406067981
LDG.E.U8                                 1  0x000EE2000C1E1100  0x00000004FF057424
F2F.F32.F64                              1  0x004E300000301000  0x0000000200067310
DFMA                                     1  0x0022240000000008  0x0000580000067625
F2F.F16.F32.RM                           1  0x004E220000204800  0x00000000FF03723E
F2FP.F16.F32.PACK_AB.RZ                  1  0x000FC600000180FF  0x20000003FF047230
F2F.F16.F32.RP                           1  0x000E620000208800  0x20000005FF057230
I2F.RM                                   1  0x004E220000205400  0x0000000200007245
I2FP.F32.S32                             1  0x080FE40000201400  0x0000000200057245
I2FP.F32.S32.RZ                          1  0x000FCA000020D400  0x0000000200067306
I2F.RP                                   1  0x000E620000209400  0x0000000500057221
I2FP.F32.U32                             1  0x000FC60000201000  0x0000000504057221
F2I.TRUNC.NTZ                            1  0x004FF0000020F100  0x0000000200057305
F2I.NTZ                                  1  0x000FF00000203100  0x0000000200047305
F2I.FLOOR.NTZ                            1  0x000E300000207100  0x0000000200067305
F2I.CEIL.NTZ                             1  0x000FF0000020B100  0x0000000200077305
F2I.U32.TRUNC.NTZ                        1  0x000E62000020F000  0x0000000504007210
F2I.U32.NTZ                              1  0x000E220000203000  0x0000000007077210
MEMBAR.SC.GPU                            1  0x000FEC0000002000  0x00000000000079AB
ERRBAR                                   1  0x000FC00000000000  0x0000000100077802
CCTL.IVALL                               1  0x000FCA0002000000  0x0000000702007986
MEMBAR.SC.CTA                            1  0x000FEC0000000000  0x0000000000007B1D
UFLO.U32                                 1  0x000FE200080E0000  0x0000000000027919
REDUX.MIN.S32                            1  0x000E260000010200  0x0000000402007C0C
REDUX.MAX.S32                            1  0x000E680000014200  0x000000FF00008388
ATOMS.POPC.INC.32                        1  0x000FE8000D00003F  0x00000402FFFF138C
ATOMS.MIN.S32                            1  0x0005E80000800200  0x00000803FFFF138C
ATOMS.MAX.S32                            1  0x0005E80001000200  0x0000000000007B1D
ATOMG.E.ADD.STRONG.GPU                   1  0x002EA200081EE1C4  0x000000FFFF0E7224
ATOMG.E.MIN.S32.STRONG.GPU               1  0x001EE800089EE3C4  0x0000080F020479A8
ATOMG.E.MAX.S32.STRONG.GPU               1  0x000EE800091EE3C4  0x00000C0E020673A9
ATOMG.E.CAS.STRONG.GPU                   1  0x000F2800001EE10F  0x0000100F020779A8
ATOMG.E.EXCH.STRONG.GPU                  1  0x000F28000C1EE1C4  0x0000140F020879A8
ATOMG.E.AND.STRONG.GPU                   1  0x000F68000A9EE1C4  0x0000180F020979A8
ATOMG.E.OR.STRONG.GPU                    1  0x000F68000B1EE1C4  0x00001C0F020A79A8
ATOMG.E.XOR.STRONG.GPU                   1  0x000F68000B9EE1C4  0x00000000000D7919
LEA.HI                                   1  0x000FC800078F50FF  0x3FFFFC0005057812
STG.E.128                                1  0x000FE2000C101D04  0x000000000000794D
LDG.E.128                                1  0x000EE2000C1E1D00  0x000000200A087810
LDG.E.CONSTANT                           1  0x000F22000C1E9900  0x0000000403007221
FSETP.GEU.FTZ.AND                        1  0x000FDA0003F1E000  0x7FFFFFFF00038802
FSETP.GTU.FTZ.AND                        1  0x000FDA0003F1C200  0x3F80000000030421
ISETP.NE.U32.AND                         1  0x000FDA0003F05070  0x000000A000000947
FFMA.RM                                  1  0x1C0FE20000004005  0x0000000405057223
FFMA.RP                                  1  0x000FC80000008005  0x007FFFFF06047812
PLOP3.LUT                                1  0x000FE40000703C20  0x007FFFFF02FF7812
CS2R.32                                  1  0x000FE40000005000  0x00000000000779C3
SGXT.U32                                 1  0x000FC80000000000  0x0000000805057C10

## 2. Opcode Field Analysis

For each mnemonic, bits constant across all instances are likely opcode bits.

Mnemonic                            #Insts         Constant Mask          Opcode Value  Low 16 bits
--------------------------------------------------------------------------------------------------------------
NOP                                    496  0xFFFFF3FFFFFFFFFF  0x000FC00000000000  0x0000
BRA                                    234  0xFFFFD5FFFFFC0000  0x000FC00003800000  0x0000
LOP3.LUT                               176  0xF3AFC1FFF7F10100  0x000FC00007800000  0x0000
FFMA                                   168  0xFFAFD1FFFFFFF600  0x000FC00000000000  0x0000
MOV                                    163  0xF48FD1FFF7FFFFFF  0x000FC00000000F00  0x0F00
IADD3                                  115  0xFC0FD1FFF7F1F600  0x000FC00007F1E000  0xE000
FMUL                                   108  0xFF0FD5FFFFFFFFFF  0x000FC00000400000  0x0000
IMAD.IADD                              106  0xFFEFD1FFFFFFF7F0  0x000FC000078E0200  0x0200
ISETP.GT.AND                           102  0xFFAFC1FFFFFDFFFF  0x000FC00003F04270  0x4270
IMAD.SHL.U32                           102  0xFFFFD7FFFFFFFFFF  0x000FC200078E00FF  0x00FF
IMAD.WIDE                              100  0xF30FD1FFFFFFFF00  0x000FC000078E0200  0x0200
LDG.E                                   94  0xFFC031FFFFFFFFFF  0x000020000C1E1900  0x1900
FADD                                    92  0xF80FC1FFFFFFFDFF  0x000FC00000000000  0x0000
IMAD.MOV.U32                            87  0xFC8FD1FFFFFFFF00  0x000FC000078E0000  0x0000
STG.E                                   64  0xFFA1F1FFFFFFFFFF  0x0001E0000C101904  0x1904
BSSY                                    53  0xFFFFF1FFFFFFFFFF  0x000FE00003800000  0x0000
BSYNC                                   53  0xFFFFFFFFFFFFFFFF  0x000FEA0003800000  0x0000
S2R                                     52  0xFFEE21FFFFFFC0FF  0x000E200000000000  0x0000
MUFU.RSQ                                49  0xFFE139FFFFFFFFFF  0x0000200000001400  0x1400
EXIT                                    45  0xFFFFFFFFFFFFFFFF  0x000FEA0003800000  0x0000
ULDC.64                                 44  0xFFFFD1FFFFFFFFFF  0x000FC00000000A00  0x0A00
STS                                     39  0xFC31F1FFFFFFBFFF  0x0001E00000000800  0x0800
CALL.REL.NOINC                          35  0xFFFFFFFFFFFFFFFF  0x000FEA0003C00000  0x0000
FMUL.FTZ                                35  0xFFCFDBFFFFFFFFFF  0x000FC20000410000  0x0000
ISETP.GT.U32.AND                        34  0xFFFFEDFFFFFFFFFF  0x000FC80003F04070  0x4070
FSETP.GEU.AND                           32  0xFFBFFFFFFFF9FDFF  0x000FDA0003F0E000  0xE000
F2FP.F16.F32.PACK_AB                    21  0xF7BFD1FFFFFFFFFF  0x000FC000000000FF  0x00FF
FADD.FTZ                                20  0xFFFFD5FFFFFFFEFF  0x000FC00000010000  0x0000
MUFU.RCP                                20  0xFFF02BFFFFFFFFFF  0x0000200000001000  0x1000
IMAD                                    17  0xFFAFD1FFFFFFFF06  0x000FC000078E0206  0x0206
ISETP.GE.U32.AND                        17  0xFFFFC1FFFFF9FFFF  0x000FC00003F06070  0x6070
LEA.HI.SX32                             16  0xFFFFFFFFFFFFFFFF  0x000FE400078FFAFF  0xFAFF
FMUL.RZ                                 15  0xFFBFD1FFFFFFFFFF  0x000FC0000040C000  0xC000
LEA                                     14  0xFB6FD1FFFFF1C7FF  0x000FC000078000FF  0x00FF
LEA.HI.X                                12  0xEBEFD1FFFE7FF7F8  0x000FC000000F1400  0x1400
PRMT                                    11  0xEB3FD3FFFFFFFF00  0x000FC00000000000  0x0000
S2UR                                    11  0xFFFEBFFFFFFF88FF  0x000E220000000000  0x0000
LDS                                     10  0xFFB031FFFFFF3FFF  0x0000200000000800  0x0800
HMMA.16816.F32                          10  0xFB3FF9FFFFFFFF10  0x000FF00000001810  0x1810
DEPBAR.LE                                9  0xFFFFFFFFFFFFFFFF  0x000FCE0000000000  0x0000
UIADD3                                   9  0xFFFFD1FFFFFFFEFF  0x000FC0000FFFE03F  0xE03F
ISETP.GE.AND                             8  0xF3AFC1FFFFF9FFFF  0x000FC00003F06270  0x6270
FMNMX                                    8  0xFFBFFDFFFBFFFFFF  0x000FC80003800000  0x0000
IMAD.MOV                                 8  0xFFFFD5FFFFFFF700  0x000FC000078E0200  0x0200
MUFU.EX2                                 8  0xFFFFFFFFFFFFFFFF  0x000E240000000800  0x0800
MUFU.LG2                                 8  0xFFF1BFFFFFFFFFFF  0x0000240000000C00  0x0C00
MUFU.SIN                                 8  0xFFFE2BFFFFFFFFFF  0x000E200000000400  0x0400
MUFU.COS                                 8  0xFFFFFFFFFFFFFFFF  0x000E240000000000  0x0000
STG.E.64                                 7  0xFFEFF5FFFFFFFFF7  0x000FE0000C101B04  0x1B04
BAR.SYNC.DEFER_BLOCKING                  7  0xFFFFF1FFFFFFFFFF  0x000FE00000010000  0x0000
SHFL.BFLY                                6  0xFFBE31FFFFFFFFFF  0x000E2000000E0000  0x0000
SHF.R.S32.HI                             6  0xFEFFD1FFFFFFFFF6  0x000FC00000011400  0x1400
LDG.E.64                                 6  0xFFFFB5FFFFFFFFFF  0x000EA0000C1E1B00  0x1B00
SHF.R.U32.HI                             6  0xFFEFD1FFFFFFFFF8  0x000FC00000011600  0x1600
SEL                                      5  0xFFFFF9FFFF7FFFFF  0x000FE00004000000  0x0000
ISETP.NE.AND                             5  0xF3EFC1FFFFFDFFFF  0x000FC00003F05270  0x5270
IMAD.U32                                 5  0xFFEFD9FFFFFFFFFF  0x000FC0000F8E00FF  0x00FF
HADD2.F32                                4  0xFFCFD1FFFFFFFFFF  0x000FC00000004100  0x4100
SHF.L.U32                                4  0xFBEFD9FFFFFFFFFF  0x000FC000000006FF  0x06FF
USHF.R.S32.HI                            4  0xFFFFFFFFFFFFFFFC  0x000FE20008011404  0x1404
FLO.U32                                  3  0xFFFE2DFFF7FFFFFF  0x000E2000000E0000  0x0000
POPC                                     3  0xFFFFADFFF7FFFFFF  0x000E200000000000  0x0000
SHF.L.W.U32.HI                           3  0xEBBFDFFFFFFFFFFF  0x000FC40000010E02  0x0E02
SHF.R.W.U32                              3  0xEFFFFFFFFFFFFFFF  0x040FE40000001E02  0x1E02
BRA.CONV                                 3  0xFFFFFFFFFFFFFFFF  0x000FEA000B800000  0x0000
RET.REL.NODEC                            3  0xFFFFFFFFFFFFFFFF  0x000FEA0003C3FFFF  0xFFFF
FSEL                                     3  0xFFFFD7FFFE7FFFFF  0x000FC20004000000  0x0000
FSETP.GT.AND                             2  0xFBBFC7FFFFFFFFFF  0x000FC20003F04000  0x4000
SHFL.IDX                                 2  0xFFBFF3FFFFFFFFFF  0x000E2000000E0000  0x0000
UMOV                                     2  0xFFFFFFFFFFFFFFFF  0x000FE20000000000  0x0000
F2F.F64.F32                              2  0xFF6FADFFFFFFFFFF  0x000E200000201800  0x1800
DADD                                     2  0xFFCFBDFFFFFFFFF3  0x000E0C0000000002  0x0002
VOTEU.ANY                                2  0xFFFFF9FFFFFFFFFF  0x000FE000038E0100  0x0100
ISETP.EQ.U32.AND                         2  0xFFCFD1FFF7FDFFFF  0x000FC00003F02070  0x2070
FSETP.NEU.FTZ.AND                        2  0xFFFFC1FFFFFFFDFF  0x000FC00003F1D000  0xD000
IMAD.WIDE.U32                            2  0xFFFFFFFFFFFFFFFF  0x000FCA00078E0002  0x0002
BREV                                     1  0xFFFFFFFFFFFFFFFF  0x004E300000000000  0x0000
FLO.U32.SH                               1  0xFFFFFFFFFFFFFFFF  0x001E3000000E0400  0x0400
SHF.R.U32                                1  0xFFFFFFFFFFFFFFFF  0x000FC40000001602  0x1602
SHF.L.U32.HI                             1  0xFFFFFFFFFFFFFFFF  0x000FE20000010602  0x0602
BPT.TRAP                                 1  0xFFFFFFFFFFFFFFFF  0x000FEA0000300000  0x0000
SHFL.DOWN                                1  0xFFFFFFFFFFFFFFFF  0x000FE800000E0000  0x0000
SHFL.UP                                  1  0xFFFFFFFFFFFFFFFF  0x000FE800000E00FF  0x00FF
WARPSYNC                                 1  0xFFFFFFFFFFFFFFFF  0x000FE80003800000  0x0000
LEA.HI.X.SX32                            1  0xFFFFFFFFFFFFFFFF  0x000FCA00000F0EFF  0x0EFF
LDG.E.U16                                1  0xFFFFFFFFFFFFFFFF  0x000EA8000C1E1500  0x1500
LDG.E.U8                                 1  0xFFFFFFFFFFFFFFFF  0x000EE2000C1E1100  0x1100
F2F.F32.F64                              1  0xFFFFFFFFFFFFFFFF  0x004E300000301000  0x1000
DFMA                                     1  0xFFFFFFFFFFFFFFFF  0x0022240000000008  0x0008
F2F.F16.F32.RM                           1  0xFFFFFFFFFFFFFFFF  0x004E220000204800  0x4800
F2FP.F16.F32.PACK_AB.RZ                  1  0xFFFFFFFFFFFFFFFF  0x000FC600000180FF  0x80FF
F2F.F16.F32.RP                           1  0xFFFFFFFFFFFFFFFF  0x000E620000208800  0x8800
I2F.RM                                   1  0xFFFFFFFFFFFFFFFF  0x004E220000205400  0x5400
I2FP.F32.S32                             1  0xFFFFFFFFFFFFFFFF  0x080FE40000201400  0x1400
I2FP.F32.S32.RZ                          1  0xFFFFFFFFFFFFFFFF  0x000FCA000020D400  0xD400
I2F.RP                                   1  0xFFFFFFFFFFFFFFFF  0x000E620000209400  0x9400
I2FP.F32.U32                             1  0xFFFFFFFFFFFFFFFF  0x000FC60000201000  0x1000
F2I.TRUNC.NTZ                            1  0xFFFFFFFFFFFFFFFF  0x004FF0000020F100  0xF100
F2I.NTZ                                  1  0xFFFFFFFFFFFFFFFF  0x000FF00000203100  0x3100
F2I.FLOOR.NTZ                            1  0xFFFFFFFFFFFFFFFF  0x000E300000207100  0x7100
F2I.CEIL.NTZ                             1  0xFFFFFFFFFFFFFFFF  0x000FF0000020B100  0xB100
F2I.U32.TRUNC.NTZ                        1  0xFFFFFFFFFFFFFFFF  0x000E62000020F000  0xF000
F2I.U32.NTZ                              1  0xFFFFFFFFFFFFFFFF  0x000E220000203000  0x3000
MEMBAR.SC.GPU                            1  0xFFFFFFFFFFFFFFFF  0x000FEC0000002000  0x2000
ERRBAR                                   1  0xFFFFFFFFFFFFFFFF  0x000FC00000000000  0x0000
CCTL.IVALL                               1  0xFFFFFFFFFFFFFFFF  0x000FCA0002000000  0x0000
MEMBAR.SC.CTA                            1  0xFFFFFFFFFFFFFFFF  0x000FEC0000000000  0x0000
UFLO.U32                                 1  0xFFFFFFFFFFFFFFFF  0x000FE200080E0000  0x0000
REDUX.MIN.S32                            1  0xFFFFFFFFFFFFFFFF  0x000E260000010200  0x0200
REDUX.MAX.S32                            1  0xFFFFFFFFFFFFFFFF  0x000E680000014200  0x4200
ATOMS.POPC.INC.32                        1  0xFFFFFFFFFFFFFFFF  0x000FE8000D00003F  0x003F
ATOMS.MIN.S32                            1  0xFFFFFFFFFFFFFFFF  0x0005E80000800200  0x0200
ATOMS.MAX.S32                            1  0xFFFFFFFFFFFFFFFF  0x0005E80001000200  0x0200
ATOMG.E.ADD.STRONG.GPU                   1  0xFFFFFFFFFFFFFFFF  0x002EA200081EE1C4  0xE1C4
ATOMG.E.MIN.S32.STRONG.GPU               1  0xFFFFFFFFFFFFFFFF  0x001EE800089EE3C4  0xE3C4
ATOMG.E.MAX.S32.STRONG.GPU               1  0xFFFFFFFFFFFFFFFF  0x000EE800091EE3C4  0xE3C4
ATOMG.E.CAS.STRONG.GPU                   1  0xFFFFFFFFFFFFFFFF  0x000F2800001EE10F  0xE10F
ATOMG.E.EXCH.STRONG.GPU                  1  0xFFFFFFFFFFFFFFFF  0x000F28000C1EE1C4  0xE1C4
ATOMG.E.AND.STRONG.GPU                   1  0xFFFFFFFFFFFFFFFF  0x000F68000A9EE1C4  0xE1C4
ATOMG.E.OR.STRONG.GPU                    1  0xFFFFFFFFFFFFFFFF  0x000F68000B1EE1C4  0xE1C4
ATOMG.E.XOR.STRONG.GPU                   1  0xFFFFFFFFFFFFFFFF  0x000F68000B9EE1C4  0xE1C4
LEA.HI                                   1  0xFFFFFFFFFFFFFFFF  0x000FC800078F50FF  0x50FF
STG.E.128                                1  0xFFFFFFFFFFFFFFFF  0x000FE2000C101D04  0x1D04
LDG.E.128                                1  0xFFFFFFFFFFFFFFFF  0x000EE2000C1E1D00  0x1D00
LDG.E.CONSTANT                           1  0xFFFFFFFFFFFFFFFF  0x000F22000C1E9900  0x9900
FSETP.GEU.FTZ.AND                        1  0xFFFFFFFFFFFFFFFF  0x000FDA0003F1E000  0xE000
FSETP.GTU.FTZ.AND                        1  0xFFFFFFFFFFFFFFFF  0x000FDA0003F1C200  0xC200
ISETP.NE.U32.AND                         1  0xFFFFFFFFFFFFFFFF  0x000FDA0003F05070  0x5070
FFMA.RM                                  1  0xFFFFFFFFFFFFFFFF  0x1C0FE20000004005  0x4005
FFMA.RP                                  1  0xFFFFFFFFFFFFFFFF  0x000FC80000008005  0x8005
PLOP3.LUT                                1  0xFFFFFFFFFFFFFFFF  0x000FE40000703C20  0x3C20
CS2R.32                                  1  0xFFFFFFFFFFFFFFFF  0x000FE40000005000  0x5000
SGXT.U32                                 1  0xFFFFFFFFFFFFFFFF  0x000FC80000000000  0x0000

## 3. Register Field Analysis (bit diffs)

Compare pairs of same-mnemonic instructions to find register encoding positions.

### NOP (496 instances)

  0x000FC00000000000  NOP 
  0x000FC00000000000  NOP 
  0x000FC00000000000  NOP 
  0x000FC00000000000  NOP 
  0x000FC00000000000  NOP 
  0x000FC00000000000  NOP 

  Varying bit fields: [(42, 43)]
    bits [42:43] (2b): unique values = {0x0, 0x3}

  Register correlation:
    [42:43]=0x0  ->    ()
    [42:43]=0x0  ->    ()
    [42:43]=0x0  ->    ()
    [42:43]=0x0  ->    ()

### BRA (234 instances)

  0x000FC0000383FFFF  BRA 0x120
  0x000FC0000383FFFF  BRA 0x110
  0x000FC0000383FFFF  BRA 0x120
  0x000FC0000383FFFF  BRA 0x170
  0x000FC0000383FFFF  BRA 0x110
  0x000FC0000383FFFF  BRA 0x100

  Varying bit fields: [(0, 17), (41, 41), (43, 43), (45, 45)]
    bits [0:17] (18b): unique values = {0x0, 0x3FFFF}
    bits [41:41] (1b): unique values = {0x0, 0x1}
    bits [43:43] (1b): unique values = {0x0, 0x1}
    bits [45:45] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [0:17]=0x3FFFF [41:41]=0x0 [43:43]=0x0 [45:45]=0x0  ->    (0x120)
    [0:17]=0x3FFFF [41:41]=0x0 [43:43]=0x0 [45:45]=0x0  ->    (0x110)
    [0:17]=0x3FFFF [41:41]=0x0 [43:43]=0x0 [45:45]=0x0  ->    (0x120)
    [0:17]=0x3FFFF [41:41]=0x0 [43:43]=0x0 [45:45]=0x0  ->    (0x170)

### LOP3.LUT (176 instances)

  0x000FE200078E9600  LOP3.LUT R9, R6, R7, R0, 0x96, !PT
  0x000FCA00078E3CFF  LOP3.LUT R9, R9, R8, RZ, 0x3c, !PT
  0x000FE200078E9607  LOP3.LUT R0, R6, R0, R7, 0x96, !PT
  0x000FCA00078E9608  LOP3.LUT R9, R9, R0, R8, 0x96, !PT
  0x000FE400078E9600  LOP3.LUT R6, R6, R7, R0, 0x96, !PT
  0x000FE400078E9608  LOP3.LUT R8, R9, R6, R8, 0x96, !PT

  Varying bit fields: [(0, 7), (9, 15), (17, 19), (27, 27), (41, 45), (52, 52), (54, 54), (58, 59)]
    bits [0:7] (8b): unique values = {0x0, 0x2, 0x4, 0x5, 0x6, 0x7, 0x8, 0xFF}
    bits [9:15] (7b): unique values = {0x1E, 0x4B, 0x53, 0x60, 0x74, 0x7C, 0x7E}
    bits [17:19] (3b): unique values = {0x0, 0x1, 0x2, 0x7}
    bits [27:27] (1b): unique values = {0x0, 0x1}
    bits [41:45] (5b): unique values = {0x2, 0x3, 0x4, 0x5, 0x6, 0xD, 0x11, 0x12}
    bits [52:52] (1b): unique values = {0x0, 0x1}
    bits [54:54] (1b): unique values = {0x0, 0x1}
    bits [58:59] (2b): unique values = {0x0, 0x1, 0x2}

  Register correlation:
    [0:7]=0x0 [9:15]=0x4B [17:19]=0x7 [27:27]=0x0 [41:45]=0x11 [52:52]=0x0 [54:54]=0x0 [58:59]=0x0  ->  R9, R6, R7, R0  (R9, R6, R7, R0, 0x96, !PT)
    [0:7]=0xFF [9:15]=0x1E [17:19]=0x7 [27:27]=0x0 [41:45]=0x5 [52:52]=0x0 [54:54]=0x0 [58:59]=0x0  ->  R9, R9, R8  (R9, R9, R8, RZ, 0x3c, !PT)
    [0:7]=0x7 [9:15]=0x4B [17:19]=0x7 [27:27]=0x0 [41:45]=0x11 [52:52]=0x0 [54:54]=0x0 [58:59]=0x0  ->  R0, R6, R0, R7  (R0, R6, R0, R7, 0x96, !PT)
    [0:7]=0x8 [9:15]=0x4B [17:19]=0x7 [27:27]=0x0 [41:45]=0x5 [52:52]=0x0 [54:54]=0x0 [58:59]=0x0  ->  R9, R9, R0, R8  (R9, R9, R0, R8, 0x96, !PT)

### FFMA (168 instances)

  0x004FC80000000006  FFMA R0, R2, R5, R6
  0x000FC80000000006  FFMA R9, R5, R0, R6
  0x000FC80000000006  FFMA R9, R5, R9, R6
  0x000FC80000000006  FFMA R9, R5, R9, R6
  0x000FC80000000006  FFMA R9, R5, R9, R6
  0x000FC80000000006  FFMA R9, R5, R9, R6

  Varying bit fields: [(0, 8), (11, 11), (41, 43), (45, 45), (52, 52), (54, 54)]
    bits [0:8] (9b): unique values = {0x0, 0x2, 0x3, 0x4, 0x5, 0x6, 0x8, 0xB, 0xFF, 0x100, 0x103, 0x104, 0x105, 0x106}
    bits [11:11] (1b): unique values = {0x0, 0x1}
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x4, 0x5}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:52] (1b): unique values = {0x0, 0x1}
    bits [54:54] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [0:8]=0x6 [11:11]=0x0 [41:43]=0x4 [45:45]=0x0 [52:52]=0x0 [54:54]=0x1  ->  R0, R2, R5, R6  (R0, R2, R5, R6)
    [0:8]=0x6 [11:11]=0x0 [41:43]=0x4 [45:45]=0x0 [52:52]=0x0 [54:54]=0x0  ->  R9, R5, R0, R6  (R9, R5, R0, R6)
    [0:8]=0x6 [11:11]=0x0 [41:43]=0x4 [45:45]=0x0 [52:52]=0x0 [54:54]=0x0  ->  R9, R5, R9, R6  (R9, R5, R9, R6)
    [0:8]=0x6 [11:11]=0x0 [41:43]=0x4 [45:45]=0x0 [52:52]=0x0 [54:54]=0x0  ->  R9, R5, R9, R6  (R9, R5, R9, R6)

### MOV (163 instances)

  0x000FE40000000F00  MOV R1, c[0x0][0x28]
  0x000FE20000000F00  MOV R9, 0x4
  0x000FE40000000F00  MOV R1, c[0x0][0x28]
  0x000FE20000000F00  MOV R5, 0x4
  0x000FE40000000F00  MOV R1, c[0x0][0x28]
  0x000FE40000000F00  MOV R1, c[0x0][0x28]

  Varying bit fields: [(27, 27), (41, 43), (45, 45), (52, 54), (56, 57), (59, 59)]
    bits [27:27] (1b): unique values = {0x0, 0x1}
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x3, 0x4, 0x5}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:54] (3b): unique values = {0x0, 0x1, 0x2, 0x3, 0x4}
    bits [56:57] (2b): unique values = {0x0, 0x1, 0x2}
    bits [59:59] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [27:27]=0x0 [41:43]=0x2 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0 [59:59]=0x0  ->  R1  (R1, c[0x0][0x28])
    [27:27]=0x0 [41:43]=0x1 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0 [59:59]=0x0  ->  R9  (R9, 0x4)
    [27:27]=0x0 [41:43]=0x2 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0 [59:59]=0x0  ->  R1  (R1, c[0x0][0x28])
    [27:27]=0x0 [41:43]=0x1 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0 [59:59]=0x0  ->  R5  (R5, 0x4)

### IADD3 (115 instances)

  0x002FC80007FFE800  IADD3 R0, R5, 0x1f, -R0
  0x001FC80007FFE006  IADD3 R7, R7, R0, R6
  0x004FE20007FFE804  IADD3 R7, R7, 0x1f, -R4
  0x000FCA0007FFE0FF  IADD3 R7, R7, 0x1, RZ
  0x001FE40007FFE0FF  IADD3 R7, R6, R5, RZ
  0x001FE40007FFE004  IADD3 R2, R2, R5, R4

  Varying bit fields: [(0, 8), (11, 11), (17, 19), (27, 27), (41, 43), (45, 45), (52, 57)]
    bits [0:8] (9b): unique values = {0x0, 0x3, 0x4, 0x6, 0x8, 0xFF, 0x1FF}
    bits [11:11] (1b): unique values = {0x0, 0x1}
    bits [17:19] (3b): unique values = {0x0, 0x7}
    bits [27:27] (1b): unique values = {0x0, 0x1}
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x3, 0x4, 0x5, 0x7}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:57] (6b): unique values = {0x0, 0x1, 0x2, 0x4, 0x8, 0xE, 0x10, 0x20}

  Register correlation:
    [0:8]=0x0 [11:11]=0x1 [17:19]=0x7 [27:27]=0x0 [41:43]=0x4 [45:45]=0x0 [52:57]=0x2  ->  R0, R5, R0  (R0, R5, 0x1f, -R0)
    [0:8]=0x6 [11:11]=0x0 [17:19]=0x7 [27:27]=0x0 [41:43]=0x4 [45:45]=0x0 [52:57]=0x1  ->  R7, R7, R0, R6  (R7, R7, R0, R6)
    [0:8]=0x4 [11:11]=0x1 [17:19]=0x7 [27:27]=0x0 [41:43]=0x1 [45:45]=0x1 [52:57]=0x4  ->  R7, R7, R4  (R7, R7, 0x1f, -R4)
    [0:8]=0xFF [11:11]=0x0 [17:19]=0x7 [27:27]=0x0 [41:43]=0x5 [45:45]=0x0 [52:57]=0x0  ->  R7, R7  (R7, R7, 0x1, RZ)

### FMUL (108 instances)

  0x000FC80000400000  FMUL R0, R2, R7
  0x000FCA0000400000  FMUL R9, R2, R7
  0x004FCA0000400000  FMUL R7, R2, R7
  0x000FCA0000400000  FMUL R9, R5, |R0|
  0x004FE20000400000  FMUL R0, R2, R5
  0x000FC80000400000  FMUL R0, R5, R0

  Varying bit fields: [(41, 41), (43, 43), (45, 45), (52, 55)]
    bits [41:41] (1b): unique values = {0x0, 0x1}
    bits [43:43] (1b): unique values = {0x0, 0x1}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:55] (4b): unique values = {0x0, 0x1, 0x4, 0x5, 0x6, 0x9}

  Register correlation:
    [41:41]=0x0 [43:43]=0x1 [45:45]=0x0 [52:55]=0x0  ->  R0, R2, R7  (R0, R2, R7)
    [41:41]=0x1 [43:43]=0x1 [45:45]=0x0 [52:55]=0x0  ->  R9, R2, R7  (R9, R2, R7)
    [41:41]=0x1 [43:43]=0x1 [45:45]=0x0 [52:55]=0x4  ->  R7, R2, R7  (R7, R2, R7)
    [41:41]=0x1 [43:43]=0x1 [45:45]=0x0 [52:55]=0x0  ->  R9, R5, R0  (R9, R5, |R0|)

### IMAD.IADD (106 instances)

  0x001FCA00078E0205  IMAD.IADD R6, R0, 0x1, R5
  0x001FC400078E0204  IMAD.IADD R8, R7, 0x1, R4
  0x000FCA00078E020A  IMAD.IADD R5, R9, 0x1, R10
  0x000FCA00078E0205  IMAD.IADD R2, R2, 0x1, R5
  0x000FCA00078E0205  IMAD.IADD R2, R2, 0x1, R5
  0x000FCA00078E0205  IMAD.IADD R2, R2, 0x1, R5

  Varying bit fields: [(0, 3), (11, 11), (41, 43), (45, 45), (52, 52)]
    bits [0:3] (4b): unique values = {0x4, 0x5, 0x9, 0xA}
    bits [11:11] (1b): unique values = {0x0, 0x1}
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x5}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:52] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [0:3]=0x5 [11:11]=0x0 [41:43]=0x5 [45:45]=0x0 [52:52]=0x1  ->  R6, R0, R5  (R6, R0, 0x1, R5)
    [0:3]=0x4 [11:11]=0x0 [41:43]=0x2 [45:45]=0x0 [52:52]=0x1  ->  R8, R7, R4  (R8, R7, 0x1, R4)
    [0:3]=0xA [11:11]=0x0 [41:43]=0x5 [45:45]=0x0 [52:52]=0x0  ->  R5, R9, R10  (R5, R9, 0x1, R10)
    [0:3]=0x5 [11:11]=0x0 [41:43]=0x5 [45:45]=0x0 [52:52]=0x0  ->  R2, R2, R5  (R2, R2, 0x1, R5)

### ISETP.GT.AND (102 instances)

  0x004FDA0003F04270  ISETP.GT.AND P0, PT, R2, 0x3e8, PT
  0x000FDA0003F04270  ISETP.GT.AND P0, PT, R2, 0x3e8, PT
  0x000FDA0003F04270  ISETP.GT.AND P0, PT, R2, 0x3e8, PT
  0x000FDA0003F04270  ISETP.GT.AND P0, PT, R2, 0x3e8, PT
  0x000FDA0003F04270  ISETP.GT.AND P0, PT, R2, 0x3e8, PT
  0x000FDA0003F04270  ISETP.GT.AND P0, PT, R2, 0x3e8, PT

  Varying bit fields: [(17, 17), (41, 45), (52, 52), (54, 54)]
    bits [17:17] (1b): unique values = {0x0, 0x1}
    bits [41:45] (5b): unique values = {0x2, 0xD, 0x11}
    bits [52:52] (1b): unique values = {0x0, 0x1}
    bits [54:54] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [17:17]=0x0 [41:45]=0xD [52:52]=0x0 [54:54]=0x1  ->  R2  (P0, PT, R2, 0x3e8, PT)
    [17:17]=0x0 [41:45]=0xD [52:52]=0x0 [54:54]=0x0  ->  R2  (P0, PT, R2, 0x3e8, PT)
    [17:17]=0x0 [41:45]=0xD [52:52]=0x0 [54:54]=0x0  ->  R2  (P0, PT, R2, 0x3e8, PT)
    [17:17]=0x0 [41:45]=0xD [52:52]=0x0 [54:54]=0x0  ->  R2  (P0, PT, R2, 0x3e8, PT)

### IMAD.SHL.U32 (102 instances)

  0x000FCA00078E00FF  IMAD.SHL.U32 R5, R2, 0x2, RZ
  0x000FCA00078E00FF  IMAD.SHL.U32 R4, R5, 0x2, RZ
  0x000FCA00078E00FF  IMAD.SHL.U32 R4, R5, 0x2, RZ
  0x000FCA00078E00FF  IMAD.SHL.U32 R4, R5, 0x2, RZ
  0x000FCA00078E00FF  IMAD.SHL.U32 R4, R5, 0x2, RZ
  0x000FCA00078E00FF  IMAD.SHL.U32 R4, R5, 0x2, RZ

  Varying bit fields: [(43, 43), (45, 45)]
    bits [43:43] (1b): unique values = {0x0, 0x1}
    bits [45:45] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [43:43]=0x1 [45:45]=0x0  ->  R5, R2  (R5, R2, 0x2, RZ)
    [43:43]=0x1 [45:45]=0x0  ->  R4, R5  (R4, R5, 0x2, RZ)
    [43:43]=0x1 [45:45]=0x0  ->  R4, R5  (R4, R5, 0x2, RZ)
    [43:43]=0x1 [45:45]=0x0  ->  R4, R5  (R4, R5, 0x2, RZ)

### IMAD.WIDE (100 instances)

  0x001FCC00078E0209  IMAD.WIDE R2, R8, R9, c[0x0][0x168]
  0x000FC600078E0209  IMAD.WIDE R4, R8, R9, c[0x0][0x160]
  0x001FC800078E020B  IMAD.WIDE R2, R10, R11, c[0x0][0x168]
  0x000FE400078E020B  IMAD.WIDE R4, R10, R11, c[0x0][0x170]
  0x000FC600078E020B  IMAD.WIDE R6, R10, R11, c[0x0][0x160]
  0x001FC800078E020B  IMAD.WIDE R2, R10, R11, c[0x0][0x168]

  Varying bit fields: [(0, 7), (41, 43), (45, 45), (52, 55), (58, 59)]
    bits [0:7] (8b): unique values = {0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0x11, 0xFF}
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x3, 0x4, 0x5, 0x6}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:55] (4b): unique values = {0x0, 0x1, 0x2, 0x4, 0x8}
    bits [58:59] (2b): unique values = {0x0, 0x1, 0x2, 0x3}

  Register correlation:
    [0:7]=0x9 [41:43]=0x6 [45:45]=0x0 [52:55]=0x1 [58:59]=0x0  ->  R2, R8, R9  (R2, R8, R9, c[0x0][0x168])
    [0:7]=0x9 [41:43]=0x3 [45:45]=0x0 [52:55]=0x0 [58:59]=0x0  ->  R4, R8, R9  (R4, R8, R9, c[0x0][0x160])
    [0:7]=0xB [41:43]=0x4 [45:45]=0x0 [52:55]=0x1 [58:59]=0x0  ->  R2, R10, R11  (R2, R10, R11, c[0x0][0x168])
    [0:7]=0xB [41:43]=0x2 [45:45]=0x1 [52:55]=0x0 [58:59]=0x0  ->  R4, R10, R11  (R4, R10, R11, c[0x0][0x170])

### LDG.E (94 instances)

  0x000EA4000C1E1900  LDG.E R2, [R2.64]
  0x000EA8000C1E1900  LDG.E R2, [R2.64]
  0x000EE2000C1E1900  LDG.E R5, [R4.64]
  0x000EA8000C1E1900  LDG.E R2, [R2.64]
  0x000EA4000C1E1900  LDG.E R5, [R4.64]
  0x000EA8000C1E1900  LDG.E R2, [R2.64]

  Varying bit fields: [(41, 43), (46, 53)]
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x4}
    bits [46:53] (8b): unique values = {0x2, 0x3, 0x5, 0x3A, 0x3B, 0x3C, 0x3D, 0x7B, 0xBB}

  Register correlation:
    [41:43]=0x2 [46:53]=0x3A  ->  R2, R2  (R2, [R2.64])
    [41:43]=0x4 [46:53]=0x3A  ->  R2, R2  (R2, [R2.64])
    [41:43]=0x1 [46:53]=0x3B  ->  R5, R4  (R5, [R4.64])
    [41:43]=0x4 [46:53]=0x3A  ->  R2, R2  (R2, [R2.64])

### FADD (92 instances)

  0x000FD80000000000  FADD R7, R2, 1
  0x000FC80000000000  FADD R7, R2, R2
  0x040FE20000000000  FADD R0, R2.reuse, R7
  0x000FCA0000000000  FADD R7, R7, R0
  0x004FCA0000000000  FADD R9, R2, R2
  0x000FE20000000000  FADD R4, R4, R4

  Varying bit fields: [(9, 9), (41, 45), (52, 58)]
    bits [9:9] (1b): unique values = {0x0, 0x1}
    bits [41:45] (5b): unique values = {0x2, 0x3, 0x4, 0x5, 0xC, 0x11}
    bits [52:58] (7b): unique values = {0x0, 0x1, 0x2, 0x4, 0x6, 0x8, 0x10, 0x20, 0x40}

  Register correlation:
    [9:9]=0x0 [41:45]=0xC [52:58]=0x0  ->  R7, R2  (R7, R2, 1)
    [9:9]=0x0 [41:45]=0x4 [52:58]=0x0  ->  R7, R2, R2  (R7, R2, R2)
    [9:9]=0x0 [41:45]=0x11 [52:58]=0x40  ->  R0, R2, R7  (R0, R2.reuse, R7)
    [9:9]=0x0 [41:45]=0x5 [52:58]=0x0  ->  R7, R7, R0  (R7, R7, R0)

### IMAD.MOV.U32 (87 instances)

  0x000FE400078E00FF  IMAD.MOV.U32 R1, RZ, RZ, c[0x0][0x28]
  0x000FE200078E00FF  IMAD.MOV.U32 R9, RZ, RZ, 0x4
  0x000FE400078E00FF  IMAD.MOV.U32 R1, RZ, RZ, c[0x0][0x28]
  0x000FE200078E00FF  IMAD.MOV.U32 R11, RZ, RZ, 0x4
  0x000FE400078E00FF  IMAD.MOV.U32 R1, RZ, RZ, c[0x0][0x28]
  0x000FE200078E00FF  IMAD.MOV.U32 R11, RZ, RZ, 0x4

  Varying bit fields: [(0, 7), (41, 43), (45, 45), (52, 54), (56, 57)]
    bits [0:7] (8b): unique values = {0x2, 0x3, 0x4, 0x8, 0xA, 0xFF}
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x3, 0x4, 0x5}
    bits [45:45] (1b): unique values = {0x0, 0x1}
    bits [52:54] (3b): unique values = {0x0, 0x1, 0x3, 0x6}
    bits [56:57] (2b): unique values = {0x0, 0x1, 0x2}

  Register correlation:
    [0:7]=0xFF [41:43]=0x2 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0  ->  R1  (R1, RZ, RZ, c[0x0][0x28])
    [0:7]=0xFF [41:43]=0x1 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0  ->  R9  (R9, RZ, RZ, 0x4)
    [0:7]=0xFF [41:43]=0x2 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0  ->  R1  (R1, RZ, RZ, c[0x0][0x28])
    [0:7]=0xFF [41:43]=0x1 [45:45]=0x1 [52:54]=0x0 [56:57]=0x0  ->  R11  (R11, RZ, RZ, 0x4)

### STG.E (64 instances)

  0x000FE2000C101904  STG.E [R4.64], R7
  0x000FE2000C101904  STG.E [R6.64], R9
  0x000FE2000C101904  STG.E [R6.64], R9
  0x000FE2000C101904  STG.E [R2.64], R7
  0x000FE2000C101904  STG.E [R8.64], R11
  0x000FE2000C101904  STG.E [R4.64], R7

  Varying bit fields: [(41, 43), (49, 52), (54, 54)]
    bits [41:43] (3b): unique values = {0x1, 0x2, 0x3, 0x4}
    bits [49:52] (4b): unique values = {0x0, 0x1, 0x2, 0x7, 0xF}
    bits [54:54] (1b): unique values = {0x0, 0x1}

  Register correlation:
    [41:43]=0x1 [49:52]=0x7 [54:54]=0x0  ->  R4, R7  ([R4.64], R7)
    [41:43]=0x1 [49:52]=0x7 [54:54]=0x0  ->  R6, R9  ([R6.64], R9)
    [41:43]=0x1 [49:52]=0x7 [54:54]=0x0  ->  R6, R9  ([R6.64], R9)
    [41:43]=0x1 [49:52]=0x7 [54:54]=0x0  ->  R2, R7  ([R2.64], R7)

## 4. Control Word Patterns

The control word (second 64-bit QWORD) encodes scheduling hints,
stall counts, barrier dependencies, etc.

        Control Word   Count  Stall bits [3:0]  Yield [4]  Barrier [8:5]
--------------------------------------------------------------------------------
0x0000000000007918     541  stall=8  yield=1  bar=0x8
0x000003E80200780C      99  stall=12  yield=0  bar=0x0
0x0000000102027824      98  stall=4  yield=0  bar=0x1
0x0000000205047824      97  stall=4  yield=0  bar=0x1
0x0000000504057212      97  stall=2  yield=1  bar=0x0
0xFFFFFFF000007947      45  stall=7  yield=0  bar=0xA
0x000000000000794D      44  stall=13  yield=0  bar=0xA
0x0000460000047AB9      43  stall=9  yield=1  bar=0x5
0x0000000000007941      37  stall=1  yield=0  bar=0xA
0x0000004000007947      32  stall=7  yield=0  bar=0xA
0x0000000402027981      24  stall=1  yield=0  bar=0xC
0x0000000300047308      17  stall=8  yield=0  bar=0x8
0x000000D000007945      16  stall=5  yield=0  bar=0xA
0x0180000002007810      16  stall=0  yield=1  bar=0x0
0x7F80000000007812      16  stall=2  yield=1  bar=0x0
0x01FFFFFF0000780C      16  stall=12  yield=0  bar=0x0
0x0000000200057308      16  stall=8  yield=0  bar=0x8
0x800000FF00007221      16  stall=1  yield=0  bar=0x1
0x0000000000017941      16  stall=1  yield=0  bar=0xA
0x0000004000008947      15  stall=7  yield=0  bar=0xA
0x0000000300007202      15  stall=2  yield=0  bar=0x0
0x0000015000007945      15  stall=5  yield=0  bar=0xA
0x3F00000005077423      15  stall=3  yield=0  bar=0x1
0x008000000900780B      15  stall=11  yield=0  bar=0x0
0xFF80000009027810      15  stall=0  yield=1  bar=0x0
0x7F0000000200780C      15  stall=12  yield=0  bar=0x0
0x000000E000000947      15  stall=7  yield=0  bar=0xA
0x0000000200047308      15  stall=8  yield=0  bar=0x8
0x0000003000000947      15  stall=7  yield=0  bar=0xA
0x0000000005027223      15  stall=3  yield=0  bar=0x1
