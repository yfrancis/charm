module Architecture.ARM.Pretty where

import Prelude hiding (EQ, LT, GT)

import Architecture.ARM.Common
import Architecture.ARM.Instructions.UAL

import Text.Printf
import Text.PrettyPrint

import Data.List

-- All this string building is inefficient. Fix it sometime using a real prettyprinting library

showRegister R0  = "R0"
showRegister R1  = "R1"
showRegister R2  = "R2"
showRegister R3  = "R3"
showRegister R4  = "R4"
showRegister R5  = "R5"
showRegister R6  = "R6"
showRegister R7  = "R7"
showRegister R8  = "R8"
showRegister R9  = "R9"
showRegister R10 = "SL"
showRegister R11 = "FP"
showRegister R12 = "IP"
showRegister SP  = "SP"
showRegister LR  = "LR"
showRegister PC  = "PC"

showArmShift S_LSL = "LSL"
showArmShift S_LSR = "LSR"
showArmShift S_ASR = "ASR"
showArmShift S_ROR = "ROR"

showCondition EQ = "EQ"
showCondition NE = "NE"
showCondition CS = "CS"
showCondition CC = "CC"
showCondition MI = "MI"
showCondition PL = "PL"
showCondition VS = "VS"
showCondition VC = "VC"
showCondition HI = "HI"
showCondition LS = "LS"
showCondition GE = "GE"
showCondition LT = "LT"
showCondition GT = "GT"
showCondition LE = "LE"
showCondition AL = ""
showCondition UND = "<unk>"


showArmOpData :: ARMOpData -> String
showArmOpData (Imm i) = printf "#%d" i
showArmOpData (Reg reg) = showRegister reg
showArmOpData (RegShiftImm sh i reg) = printf "%s, %s #%d" (showRegister reg) (showArmShift sh) i
showArmOpData (RegShiftReg sh regs reg) = printf "%s, %s %s" (showRegister reg) (showArmShift sh) (showRegister regs)
showArmOpData (RegShiftRRX reg) = printf "%s, RRX" (showRegister reg)

showArmOpMemory :: ARMOpMemory -> String
showArmOpMemory (MemReg base (Imm 0) up) = printf "[%s]" (showRegister base) ++ if up then "!" else ""
showArmOpMemory (MemReg base d up) = printf "[%s, %s]" (showRegister base) (showArmOpData d) ++ if up then "!" else ""
showArmOpMemory (MemRegNeg base d up) = printf "[%s, -%s]" (showRegister base) (showArmOpData d) ++ if up then "!" else ""
showArmOpMemory (MemRegPost base d) = printf "[%s], %s" (showRegister base) (showArmOpData d)
showArmOpMemory (MemRegPostNeg base d) = printf "[%s], -%s" (showRegister base) (showArmOpData d)


showArmOpMultiple :: ARMOpMultiple -> String
showArmOpMultiple (Regs rs) = "{" ++ (intercalate ", " . map showRegister $ rs) ++ "}"
showArmOpMultiple (RegsCaret rs) = "{" ++ (intercalate ", " . map showRegister $ rs) ++ "}^"

showConditional :: Conditional -> String
showConditional (B off)  = printf "B%%s 0x%x" off
showConditional (BL off) = printf "BL%%s 0x%x" off
showConditional (BLX rd) = printf "BLX%%s %s" (showRegister rd)
showConditional (BX  rd) = printf "BX%%s %s"  (showRegister rd)
showConditional (BXJ rd) = printf "BXJ%%s %s" (showRegister rd)
showConditional (AND  rd rn k) = printf "AND%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (ANDS rd rn k) = printf "ANDS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (EOR  rd rn k) = printf "EOR%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (EORS rd rn k) = printf "EORS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (SUB  rd rn k) = printf "SUB%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (SUBS rd rn k) = printf "SUBS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (RSB  rd rn k) = printf "RSB%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (RSBS rd rn k) = printf "RSBS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (ADD  rd rn k) = printf "ADD%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (ADDS rd rn k) = printf "ADDS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (ADC  rd rn k) = printf "ADC%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (ADCS rd rn k) = printf "ADCS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (SBC  rd rn k) = printf "SBC%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (SBCS rd rn k) = printf "SBCS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (RSC  rd rn k) = printf "RSC%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (RSCS rd rn k) = printf "RSCS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (TST rn d)     = printf "TST%%s %s, %s" (showRegister rn) (showArmOpData d)
showConditional (TEQ rn d)     = printf "TEQ%%s %s, %s" (showRegister rn) (showArmOpData d)
showConditional (CMP rn d)     = printf "CMP%%s %s, %s" (showRegister rn) (showArmOpData d)
showConditional (CMN rn d)     = printf "CMN%%s %s, %s" (showRegister rn) (showArmOpData d)
showConditional (ORR  rd rn k) = printf "ORR%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (ORRS rd rn k) = printf "ORRS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData k)
showConditional (MOV  rd d)    = printf "MOV%%s %s, %s"  (showRegister rd) (showArmOpData d)
showConditional (MOVS rd d)    = printf "MOVS%%s %s, %s" (showRegister rd) (showArmOpData d)
showConditional (LSL  rd d)    = printf "LSL%%s %s, %s"  (showRegister rd) (showArmOpData d)
showConditional (LSLS rd d)    = printf "LSLS%%s %s, %s" (showRegister rd) (showArmOpData d)
showConditional (LSR  rd d)    = printf "LSR%%s %s, %s"  (showRegister rd) (showArmOpData d)
showConditional (LSRS rd d)    = printf "LSRS%%s %s, %s" (showRegister rd) (showArmOpData d)
showConditional (ASR  rd d)    = printf "ASR%%s %s, %s"  (showRegister rd) (showArmOpData d)
showConditional (ASRS rd d)    = printf "ASRS%%s %s, %s" (showRegister rd) (showArmOpData d)
showConditional (RRX  rd rm)   = printf "RRX%%s %s, %s"  (showRegister rd) (showRegister rm)
showConditional (RRXS rd rm)   = printf "RRXS%%s %s, %s" (showRegister rd) (showRegister rm)
showConditional (ROR  rd d)    = printf "ROR%%s %s, %s"  (showRegister rd) (showArmOpData d)
showConditional (RORS rd d)    = printf "RORS%%s %s, %s" (showRegister rd) (showArmOpData d)
showConditional (BIC  rd rn d) = printf "BIC%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (BICS rd rn d) = printf "BICS%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (MVN  rd d)    = printf "MVN%%s %s, %s"  (showRegister rd) (showArmOpData d)
showConditional (MVNS rd d)    = printf "MVNS%%s %s, %s" (showRegister rd) (showArmOpData d)
showConditional (MLA  rd rn rm ra)    = printf "MLA%%s %s, %s, %s, %s"     (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (MLAS rd rn rm ra)    = printf "MLAS%%s %s, %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (MUL  rd rn rm)       = printf "MUL%%s %s, %s, %s"     (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (MULS rd rn rm)       = printf "MULS%%s %s, %s, %s"     (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMLABB  rd rn rm ra) = printf "SMLABB%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLABT  rd rn rm ra) = printf "SMLABT%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLATB  rd rn rm ra) = printf "SMLATB%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLATT  rd rn rm ra) = printf "SMLATT%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLAWB  rd rn rm ra) = printf "SMLAWB%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLAWT  rd rn rm ra) = printf "SMLAWT%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLAD   rd rn rm ra) = printf "SMLAD%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLADX  rd rn rm ra) = printf "SMLADX%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLAL   rd rn rm ra) = printf "SMLAL%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALS  rd rn rm ra) = printf "SMLALS%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALBB rd rn rm ra) = printf "SMLALBB%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALBT rd rn rm ra) = printf "SMLALBT%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALTB rd rn rm ra) = printf "SMLALTB%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALTT rd rn rm ra) = printf "SMLALTT%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALD  rd rn rm ra) = printf "SMLALD%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLALDX rd rn rm ra) = printf "SMLALDX%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLSD   rd rn rm ra) = printf "SMLSD%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLSDX  rd rn rm ra) = printf "SMLSDX%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLSLD  rd rn rm ra) = printf "SMLSLD%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMLSLDX rd rn rm ra) = printf "SMLSLDX%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMMLA   rd rn rm ra) = printf "SMMLA%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMMLAR  rd rn rm ra) = printf "SMMLAR%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMMUL   rd rn rm)    = printf "SMMUL%%s %s, %s, %s"       (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMMULR  rd rn rm)    = printf "SMMULR%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMMLS   rd rn rm ra) = printf "SMMLS%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMMLSR  rd rn rm ra) = printf "SMMLSR%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMUAD   rd rn rm)    = printf "SMUAD%%s %s, %s, %s"       (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMUADX  rd rn rm)    = printf "SMUADX%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMULBB  rd rn rm)    = printf "SMULBB%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMULBT  rd rn rm)    = printf "SMULBT%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMULTB  rd rn rm)    = printf "SMULTB%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMULTT  rd rn rm)    = printf "SMULTT%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMULL   rd rn rm ra) = printf "SMULL%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMULLS  rd rn rm ra) = printf "SMULLS%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (SMULWB  rd rn rm)    = printf "SMULWB%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMULWT  rd rn rm)    = printf "SMULWT%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMUSD   rd rn rm)    = printf "SMUSD%%s %s, %s, %s"       (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SMUSDX  rd rn rm)    = printf "SMUSDX%%s %s, %s, %s"      (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (UMAAL   rd rn rm ra) = printf "UMAAL%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (UMLAL   rd rn rm ra) = printf "UMLAL%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (UMLALS  rd rn rm ra) = printf "UMLALS%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (UMULL   rd rn rm ra) = printf "UMULL%%s %s, %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (UMULLS  rd rn rm ra) = printf "UMULLS%%s %s, %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (QADD    rd rm rn) = printf "QADD%%s %s, %s, %s"    (showRegister rd) (showRegister rm) (showRegister rn) -- NB: inverted operands
showConditional (QADD16  rd rn rm) = printf "QADD16%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QADD8   rd rn rm) = printf "QADD8%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QASX    rd rn rm) = printf "QASX%%s %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QDADD   rd rn rm) = printf "QDADD%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QDSUB   rd rn rm) = printf "QDSUB%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QSUB    rd rm rn) = printf "QSUB%%s %s, %s, %s"    (showRegister rd) (showRegister rm) (showRegister rn) -- NB: inverted operands
showConditional (QSUB16  rd rn rm) = printf "QSUB16%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QSUB8   rd rn rm) = printf "QSUB8%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (QSAX    rd rn rm) = printf "QSAX%%s %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SADD16  rd rn rm) = printf "SADD16%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SADD8   rd rn rm) = printf "SADD8%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SASX    rd rn rm) = printf "SASX%%s %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SSUB16  rd rn rm) = printf "SSUB16%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SSUB8   rd rn rm) = printf "SSUB8%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SSAX    rd rn rm) = printf "SSAX%%s %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SHADD16 rd rn rm) = printf "SHADD16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SHADD8  rd rn rm) = printf "SHADD8%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SHASX   rd rn rm) = printf "SHASX%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SHSUB16 rd rn rm) = printf "SHSUB16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SHSUB8  rd rn rm) = printf "SHSUB8%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SHSAX   rd rn rm) = printf "SHSAX%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UADD16  rd rn rm) = printf "UADD16%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UADD8   rd rn rm) = printf "UADD8%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UASX    rd rn rm) = printf "UASX%%s %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (USUB16  rd rn rm) = printf "USUB16%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (USUB8   rd rn rm) = printf "USUB8%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (USAX    rd rn rm) = printf "USAX%%s %s, %s, %s"    (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UHADD16 rd rn rm) = printf "UHADD16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UHADD8  rd rn rm) = printf "UHADD8%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UHASX   rd rn rm) = printf "UHASX%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UHSUB16 rd rn rm) = printf "UHSUB16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UHSUB8  rd rn rm) = printf "UHSUB8%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UHSAX   rd rn rm) = printf "UHSAX%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UQADD16 rd rn rm) = printf "UQADD16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UQADD8  rd rn rm) = printf "UQADD8%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UQASX   rd rn rm) = printf "UQASX%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UQSUB16 rd rn rm) = printf "UQSUB16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UQSUB8  rd rn rm) = printf "UQSUB8%%s %s, %s, %s"  (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (UQSAX   rd rn rm) = printf "UQSAX%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showRegister rm) 
showConditional (SXTAB16 rd rn d)  = printf "SXTAB16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData d) 
showConditional (SXTAB   rd rn d)  = printf "SXTAB%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showArmOpData d) 
showConditional (SXTAH   rd rn d)  = printf "SXTAH%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showArmOpData d) 
showConditional (SXTB16  rd d)     = printf "SXTB16%%s %s, %s"      (showRegister rd) (showArmOpData d)
showConditional (SXTB    rd d)     = printf "SXTB%%s %s, %s"        (showRegister rd) (showArmOpData d)
showConditional (SXTH    rd d)     = printf "SXTH%%s %s, %s"        (showRegister rd) (showArmOpData d)
showConditional (UXTAB16 rd rn d)  = printf "UXTAB16%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (UXTAB   rd rn d)  = printf "UXTAB%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (UXTAH   rd rn d)  = printf "UXTAH%%s %s, %s, %s"   (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (UXTB16  rd d)     = printf "UXTB16%%s %s, %s"      (showRegister rd) (showArmOpData d)
showConditional (UXTB    rd d)     = printf "UXTB%%s %s, %s"        (showRegister rd) (showArmOpData d)
showConditional (UXTH    rd d)     = printf "UXTH%%s %s, %s"        (showRegister rd) (showArmOpData d)
showConditional (UBFX    rd rn lsb w) = printf "UBFX%%s %s, %s, #%i, #%i" (showRegister rd) (showRegister rn) lsb w
showConditional (SBFX    rd rn lsb w) = printf "SBFX%%s %s, %s, #%i, #%i" (showRegister rd) (showRegister rn) lsb w
showConditional (CLZ rd rm) = printf "CLZ%%s %s, %s" (showRegister rd) (showRegister rm)
showConditional (USAD8  rd rn rm) = printf "USAD8%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (USADA8 rd rn rm ra) = printf "USADA8%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (PKHBT rd rn d) = printf "PKHBT%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (PKHTB rd rn d) = printf "PKHTB%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showArmOpData d)
showConditional (REV   rd rm) = printf "REV%%s %s, %s" (showRegister rd) (showRegister rm)
showConditional (REV16 rd rm) = printf "REV16%%s %s, %s" (showRegister rd) (showRegister rm)
showConditional (REVSH rd rm) = printf "REVSH%%s %s, %s" (showRegister rd) (showRegister rm)
showConditional (SEL rd rn rm) = printf "SEL%%s %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm)
showConditional (SSAT   rd imm d)  = printf "SSAT%%s %s, #%i, %s"   (showRegister rd) imm (showArmOpData d)
showConditional (SSAT16 rd imm rn) = printf "SSAT16%%s %s, #%i, %s" (showRegister rd) imm (showRegister rn)
showConditional (USAT   rd imm d)  = printf "USAT%%s %s, #%i, %s"   (showRegister rd) imm (showArmOpData d)
showConditional (USAT16 rd imm rn) = printf "USAT16%%s %s, #%i, %s" (showRegister rd) imm (showRegister rn)
showConditional (MRS rd spec) = printf "MRS%%s %s, %s" (showRegister rd) (show spec) -- check
showConditional (MSR x y d) = printf "MSR%%s" -- undefined -- FIX
showConditional (LDR    rt mem) = printf "LDR%%s %s, %s"    (showRegister rt) (showArmOpMemory mem)
showConditional (LDRB   rt mem) = printf "LDRB%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (LDRH   rt mem) = printf "LDRH%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (LDRD   rt mem) = printf "LDRD%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (LDRBT  rt mem) = printf "LDRBT%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (LDRHT  rt mem) = printf "LDRHT%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (LDRT   rt mem) = printf "LDRT%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (LDRSB  rt mem) = printf "LDRSB%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (LDRSBT rt mem) = printf "LDRSBT%%s %s, %s" (showRegister rt) (showArmOpMemory mem)
showConditional (LDRSH  rt mem) = printf "LDRSH%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (LDRSHT rt mem) = printf "LDRSHT%%s %s, %s" (showRegister rt) (showArmOpMemory mem)
showConditional (STR    rt mem) = printf "STR%%s %s, %s"    (showRegister rt) (showArmOpMemory mem)
showConditional (STRB   rt mem) = printf "STRB%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (STRH   rt mem) = printf "STRH%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (STRD   rt mem) = printf "STRD%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (STRBT  rt mem) = printf "STRBT%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (STRHT  rt mem) = printf "STRHT%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (STRT   rt mem) = printf "STRT%%s %s, %s"   (showRegister rt) (showArmOpMemory mem)
showConditional (LDREX  rt mem) = printf "LDREX%%s %s, %s"  (showRegister rt) (showArmOpMemory mem)
showConditional (LDREXB rt mem) = printf "LDREXB%%s %s, %s" (showRegister rt) (showArmOpMemory mem)
showConditional (LDREXH rt mem) = printf "LDREXH%%s %s, %s" (showRegister rt) (showArmOpMemory mem)
showConditional (LDREXD rt rt2 mem)    = printf "LDREXD%%s %s, %s, %s" (showRegister rt) (showRegister rt2) (showArmOpMemory mem)
showConditional (STREX  rd rt mem)     = printf "STREX%%s %s, %s, %s"  (showRegister rd) (showRegister rt) (showArmOpMemory mem)
showConditional (STREXB rd rt mem)     = printf "STREXB%%s %s, %s, %s" (showRegister rd) (showRegister rt) (showArmOpMemory mem)
showConditional (STREXH rd rt mem)     = printf "STREXH%%s %s, %s, %s" (showRegister rd) (showRegister rt) (showArmOpMemory mem)
showConditional (STREXD rd rt rt2 mem) = printf "STREXD%%s %s, %s, %s" (showRegister rd) (showRegister rt) (showRegister rt2) (showArmOpMemory mem)
showConditional (LDM   bang rd regs)   = printf "LDM%%s %s%s, %s"   (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (LDMDA bang rd regs)   = printf "LDMDA%%s %s%s, %s" (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (LDMDB bang rd regs)   = printf "LDMDB%%s %s%s, %s" (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (LDMIB bang rd regs)   = printf "LDMIB%%s %s%s, %s" (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (STM   bang rd regs)   = printf "STM%%s %s%s, %s"   (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (STMDA bang rd regs)   = printf "STMDA%%s %s%s, %s" (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (STMDB bang rd regs)   = printf "STMDB%%s %s%s, %s" (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (STMIB bang rd regs)   = printf "STMIB%%s %s%s, %s" (showRegister rd) (cond "" "!" bang) (showArmOpMultiple regs)
showConditional (PUSH regs) = printf "PUSH%%s %s" (showArmOpMultiple regs)
showConditional (POP  regs) = printf "POP%%s %s"  (showArmOpMultiple regs)
showConditional (SWP  rt rt2 rn) = printf "SWP%%s %s, %s, %s"  (showRegister rt) (showRegister rt2) (showArmOpMemory rn)
showConditional (SWPB rt rt2 rn) = printf "SWPB%%s %s, %s, %s" (showRegister rt) (showRegister rt2) (showArmOpMemory rn)
showConditional (SMC imm) = printf "SMC%%s 0x%x" imm
showConditional (SVC imm) = printf "SVC%%s 0x%08x" imm
showConditional (DBG imm) = printf "DBG%%s 0x%x" imm
showConditional (DMB opt) = printf "DMB%%s %s" (show opt) -- FIX
showConditional (DSB opt) = printf "DSB%%s %s" (show opt) -- FIX
showConditional (ISB opt) = printf "ISB%%s %s" (show opt) -- FIX
showConditional (PLI mem) = printf "PLI%%s %s" (showArmOpMemory mem)
showConditional YIELD = printf "YIELD"
showConditional WFE = printf "WFE"
showConditional WFI = printf "WFI"
showConditional SEV = printf "SEV"
showConditional (BFC rd x) = printf "BFC%%s %s" (showRegister rd) "DUNNO YET" -- FIX
showConditional (BFI rd rn x) = printf "BFI%%s" (showRegister rd) (showRegister rn) "DUNNO YET" -- FIX
showConditional (MLS rd rn rm ra) = printf "MLS%%s %s, %s, %s, %s" (showRegister rd) (showRegister rn) (showRegister rm) (showRegister ra)
showConditional (MOVW rd imm) = printf "MOVW%%s %s, #%i" (showRegister rd) imm
showConditional (MOVT rd imm) = printf "MOVT%%s %s, #%i" (showRegister rd) imm
showConditional (RBIT rd rm) = "rbit%s" -- undefined -- FIX
showConditional i = error $ "Unrecognized conditional instruction " ++ show i

showUnconditional (CPS imm32) = printf "CPS 0x%x" imm32
showUnconditional (CPSIE a i f mode) = printf "CPSIE" -- FIX
showUnconditional (CPSID a i f mode) = printf "CPSIE" -- FIX
showUnconditional (SETEND end) = printf "SETEND %s" (show end) -- FIX
showUnconditional (RFE   b r) = printf "RFE"   -- FIX
showUnconditional (RFEDA b r) = printf "RFEDA" -- FIX
showUnconditional (RFEDB b r) = printf "RFEDB" -- FIX
showUnconditional (RFEIB b r) = printf "RFEIB" -- FIX
showUnconditional (BKPT imm8) = printf "BKPT 0x%x" imm8
showUnconditional (PLD mem) = "PLD" -- FIX
showUnconditional (SRS   b r imm32) = "SRS" -- FIX
showUnconditional (SRSDA b r imm32) = "SRSDA" -- FIX
showUnconditional (SRSDB b r imm32) = "SRSDB" -- FIX
showUnconditional (SRSIB b r imm32) = "SRSIB" -- FIX
showUnconditional CLREX = "CLREX"
showUnconditional (BLXUC imm32) = printf "BLX 0x%x" imm32

showInstruction :: UALInstruction -> String
showInstruction Undefined = "UNDEFINED INSTRUCTION"
showInstruction (Unconditional x) = showUnconditional x
showInstruction (Conditional cond x) = printf (showConditional x) (showCondition cond)