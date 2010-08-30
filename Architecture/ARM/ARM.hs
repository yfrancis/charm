{-# LANGUAGE TypeFamilies #-}
module Architecture.ARM.ARM where

import Prelude hiding (and)

import Architecture.ARM.Common
import Architecture.ARM.Instructions

import Data.Maybe
import Data.List hiding (and)
import Data.Int
import Data.Word
import Data.Bits hiding (bit)

import Text.Printf

import Control.Monad
import Control.Applicative


data ARMOpcode32 = ARMOpcode32 { opcode32_arch :: [ARMArch]
                               , opcode32_value :: Word32
                               , opcode32_mask :: Word32
                               , opcode32_decoder :: ARMDecoder ARMInstruction
                               }

class Decoder a where
  type NativeWord a :: *
  type Structure a :: *
  decoder :: [ARMArch] -> NativeWord a -> NativeWord a -> (NativeWord a -> a) -> Structure a

instance Decoder Conditional where
  type NativeWord Conditional = Word32
  type Structure Conditional = ARMOpcode32
  
  {-# SPECIALIZE decoder :: [ARMArch] -> Word32 -> Word32 -> (Word32 -> Conditional) -> ARMOpcode32 #-}
  decoder archs value mask d = decoder archs value mask (Conditional <$> arm_c <*> d)

instance Decoder Unconditional where
  type NativeWord Unconditional = Word32
  type Structure Unconditional = ARMOpcode32

  {-# SPECIALIZE decoder :: [ARMArch] -> Word32 -> Word32 -> (Word32 -> Unconditional) -> ARMOpcode32 #-}
  decoder archs value mask d = decoder archs value mask (Unconditional <$> d)

instance Decoder ARMInstruction where
  type NativeWord ARMInstruction = Word32
  type Structure ARMInstruction = ARMOpcode32
  
  {-# SPECIALIZE decoder :: [ARMArch] -> Word32 -> Word32 -> (Word32 -> ARMInstruction) -> ARMOpcode32 #-}
  decoder = ARMOpcode32

bitRange :: (Integral a, Bits a) => Int -> Int -> a -> a
bitRange start end i = ((i `shiftR` start) .&. ((2 `shiftL` (end - start)) - 1))

type ARMDecoder a = Word32 -> a

armDecodeAddress :: ARMDecoder ARMOpMemory
armDecodeAddress a | (a .&. 0xf0000) == 0xf0000 && (a .&. 0x2000000) == 0 = 
                         let offset = a .&. 0xfff in
                           case a .&. 0x1000000 /= 0 of
                             True -> MemReg PC (Imm (if (a .&. 0x800000) == 0 then -(fromIntegral offset) else fromIntegral offset)) ((a .&. 0x200000) /= 0)
                             _    -> MemRegPost PC $ Imm (fromIntegral offset)
                   | otherwise = 
                         let baseReg = (toEnum (((fromIntegral a) `shiftR` 16 ) .&. 0xf)) in case a .&. 0x1000000 /= 0 of
                           False -> if (a .&. 0x2000000) == 0 then
                                      let offset = a .&. 0xfff in
                                        if offset /= 0 then
                                          MemRegPost baseReg $ Imm (if (a .&. 0x800000) == 0 then -(fromIntegral offset) else fromIntegral offset)
                                          else MemRegPost baseReg $ Imm 0
                                      else (if (a .&. 0x800000) == 0 then MemRegPostNeg else MemRegPost) baseReg (armDecodeShift a False)
                           _     -> if (a .&. 0x2000000) == 0 then
                                      let offset = a .&. 0xfff in
                                        MemReg baseReg (Imm (if (a .&. 0x800000) == 0 then -(fromIntegral offset) else fromIntegral offset)) ((a .&. 0x200000) /= 0)
                                      else (if (a .&. 0x800000) == 0 then MemRegNeg else MemReg) baseReg (armDecodeShift a False) ((a .&. 0x200000) /= 0)

armDecodeShift :: Word32 -> Bool -> ARMOpData
armDecodeShift i p =  if i .&. 0xff0 /= 0 then
                        if i .&. 0x10 == 0 then
                          let amount = (i .&. 0xf80) `shiftR` 7
                              shift = ((fromIntegral i) .&. 0x60) `shiftR` 5 in
                            if amount == 0 && shift == 3 then  RegShiftRRX (toEnum ((fromIntegral i) .&. 0xf)) 
                              else  RegShiftImm (toEnum shift) (fromIntegral amount) (toEnum ((fromIntegral i) .&. 0xf)) 
                          else  RegShiftImm (toEnum (((fromIntegral i) .&. 0x60) `shiftR` 5)) (toEnum (((fromIntegral i) .&. 0xf00 `shiftR` 8))) (toEnum ((fromIntegral i) .&. 0xf)) 
                        else Reg (toEnum ((fromIntegral i) .&. 0xf))

arm_const :: String -> ARMDecoder String
arm_const x i = x

arm_constint :: Int -> ARMDecoder String
arm_constint x i = show x

arm_a :: ARMDecoder ARMOpMemory
arm_a = armDecodeAddress 

-- FIXME: wow, this is pretty ugly...
arm_s :: ARMDecoder ARMOpMemory
arm_s i | i .&. 0x4f0000 == 0x4f0000 = MemReg PC (Imm (fromIntegral $ (if i .&. 0x800000 == 0 then -1 else 1) * ((i .&. 0xf00) `shiftR` 4) .|. (i .&. 0xf))) False
        | i .&. 0x1000000 /= 0 = case i .&. 0x400000 of
            0x400000 -> MemReg (toEnum (((fromIntegral i) `shiftR` 16) .&. 0xf)) 
                            (Imm $ let offset = ((i .&. 0xf00) `shiftR` 4) .|. (i .&. 0xf) in 
                              if (i .&. 0x800000) == 0 then -(fromIntegral offset) else fromIntegral offset) 
                               ((i .&. 0x200000) /= 0)
            _        -> (if (i .&. 0x800000) == 0 then MemRegNeg else MemReg) (toEnum (((fromIntegral i) `shiftR` 16) .&. 0xf))
                            (Reg $ toEnum ((fromIntegral i) .&. 0xf)) ((i .&. 0x200000) /= 0)
        | otherwise = case i .&. 0x400000 of
            0x400000 -> MemReg (toEnum (((fromIntegral i) `shiftR` 16) .&. 0xf)) 
                            (Imm $ let offset = ((i .&. 0xf00) `shiftR` 4) .|. (i .&. 0xf) in 
                              (if (i .&. 0x800000) == 0 then  -(fromIntegral offset) else fromIntegral offset))
                               False
            _        -> (if (i .&. 0x800000) == 0 then MemRegPostNeg else MemRegPost) (toEnum (((fromIntegral i) `shiftR` 16) .&. 0xf)) (Reg $ toEnum ((fromIntegral i) .&. 0xf))

arm_b :: ARMDecoder Int32
arm_b i = ((((fromIntegral i :: Int32) .&. 0xffffff) `xor` 0x800000) - 0x800000) * 4 + {-(fromIntegral $ pc s) + -} 8

arm_c :: ARMDecoder Condition
arm_c i = toEnum $ fromIntegral ((i `shiftR` 28) .&. 0xf)

arm_m :: ARMDecoder [ARMRegister]
arm_m i = catMaybes $ map (\x -> if i .&. (1 `shiftL` x) /= 0 then Just $ toEnum x else Nothing) [0..15]

arm_o :: ARMDecoder ARMOpData
arm_o i | i .&. 0x2000000 /= 0 = Imm . fromIntegral $ (i .&. 0xff) `rotateR` (((fromIntegral i) .&. 0xf00) `shiftR` 7)
        | otherwise = armDecodeShift i True

arm_p :: ARMDecoder Bool
arm_p i = i .&. 0xf000 == 0xf000

arm_t :: ARMDecoder Bool
arm_t i = i .&. 0x1200000 == 0x200000

arm_q :: ARMDecoder ARMOpData
arm_q i = armDecodeShift i False

arm_e :: ARMDecoder Word32
arm_e i = (i .&. 0xf) .|. ((i .&. 0xfff00) `shiftR` 4)

arm_B :: ARMDecoder Int32
arm_B i = let offset = ((if i .&. 0x800000 /= 0 then 0xff else 0) + (i .&. 0xffffff)) `shiftL` 2 
              address = offset + {-(pc s) + -} 8 + (if i .&. 0x1000000 /= 0 then 2 else 0) in
                fromIntegral address
              
-- FIXME: this is ugly
arm_C :: ARMDecoder String
arm_C i = '_' : (if i .&. 0x80000 /= 0 then "f" else "" ++ 
                 if i .&. 0x40000 /= 0 then "s" else "" ++
                 if i .&. 0x20000 /= 0 then "x" else "" ++
                 if i .&. 0x10000 /= 0 then "c" else "")

arm_U :: ARMDecoder ARMHint
arm_U i = case i .&. 0xf of
            0xf -> SY
            0x7 -> UN
            0xe -> ST
            0x6 -> UNST
            x   -> UK x

arm_P :: ARMDecoder ARMOpMemory
arm_P i = armDecodeAddress $ i .|. (1 `shiftL` 24)

reg :: Int -> ARMDecoder ARMRegister
reg start i = toEnum (bitRange start (start + 3) $ fromIntegral i)

integral :: (Integral a, Bits a) => Int -> Int -> ARMDecoder a
integral start end i = bitRange start end $ fromIntegral i

integral' :: (Integral a, Bits a) => Int -> Int -> ARMDecoder a
integral' start end i = (+1) . bitRange start end $ fromIntegral i

arm_X :: Int -> Int -> ARMDecoder Word32
arm_X start end i = (.&. 0xf) . bitRange start end $ i


arm_E :: ARMDecoder (Maybe (Word32, Word32))
arm_E i = let msb = (i .&. 0x1f0000) `shiftR` 16
              lsb = (i .&. 0xf80) `shiftR` 7
              width = msb - lsb + 1 in
            if width > 0 then
              Just (lsb, width) --"#" ++ (show lsb) ++ ", #" ++ (show width)
              else Nothing --"(invalid " ++ (show lsb) ++ ":" ++ (show msb) ++ ")"            

arm_V :: ARMDecoder Word32
arm_V i = (i .&. 0xf0000) `shiftR` 4 .|. (i .&. 0xfff)

{-
arm_square :: ARMDecoder -> ARMDecoder
arm_square d = ((("[" ++) . (++ "]")) .) . d

arm_curly :: ARMDecoder -> ARMDecoder
arm_curly d = ((("{" ++) . (++ "}")) .) . d

-}

bit b i = bitRange b b i

bool b s = bit b s == 1

enum :: (Integral i, Enum a) => i -> a
enum = enum

{-}
arm_uncond = liftM  Unconditional
arm_cond   = liftM2 Conditional arm_c
-}

arm_bw bit i = if bitRange bit bit i == 1 then Byte else Word
arm_bh bit i = if bitRange bit bit i == 1 then Byte else HalfWord

reg12_reg0_reg16 f = f <$> reg 12 <*> reg 0 <*> reg 16

reg12_reg16_reg0 f = f <$> reg 12 <*> reg 16 <*> reg 0
reg12_reg16_reg0_reg8 f = reg12_reg16_reg0 f <*> reg 8
reg16_reg0_reg8 f = f <$> reg 16 <*> reg 0 <*> reg 8
reg16_reg0_reg8_reg12 f = reg16_reg0_reg8 f <*> reg 12

direction :: Int -> ARMDecoder ARMDirection
direction n = choose n Increment Decrement

order :: Int -> ARMDecoder ARMOrder
order n = choose n Before After

choose :: Int -> a -> a -> Word32 -> a
choose n t f x = if not (bool n x) then t else f

bool20_reg12_reg16_o f = f <$> bool 20 <*> reg 12 <*> reg 16 <*> arm_o



armOpcodes = 
  [ decoder [ARM_EXT_V4T, ARM_EXT_V5] 0x012FFF10 0x0ffffff0 (BX <$> reg 0)
  , decoder [ARM_EXT_V2]    0x00000090 0x0fe000f0 (mul <$> bool 20 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V2]    0x00200090 0x0fe000f0 (mla <$> bool 20 <*> reg 16 <*> reg 0 <*> reg 8 <*> reg 12)
  , decoder [ARM_EXT_V2S]   0x01000090 0x0fb00ff0 (swp <$> bool 22 <*> reg 12 <*> reg 0 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False))
  , decoder [ARM_EXT_V3M]   0x00800090 0x0fa000f0 (choose 22 smull umull <*> bool 20 <*> reg 12 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V3M]   0x00800090 0x0fa000f0 (choose 22 smlal umlal <*> bool 20 <*> reg 12 <*> reg 16 <*> reg 0 <*> reg 8)

  , decoder [ARM_EXT_V7]    0xf450f000 0xfd70f000 (PLI <$> arm_P)
  , decoder [ARM_EXT_V7]    0x0320f0f0 0x0ffffff0 (DBG <$> integral 0 3)
  , decoder [ARM_EXT_V7]    0xf57ff050 0x0ffffff0 (DMB <$> arm_U)
  , decoder [ARM_EXT_V7]    0xf57ff040 0x0ffffff0 (DSB <$> arm_U)
  , decoder [ARM_EXT_V7]    0xf57ff060 0x0ffffff0 (ISB <$> arm_U)

  , decoder [ARM_EXT_V6T2]  0x07c0001f 0x0fe0007f (BFC <$> reg 12 <*> arm_E)
  , decoder [ARM_EXT_V6T2]  0x07c00010 0x0fe00070 (BFI <$> reg 12 <*> reg 0 <*> arm_E)
  , decoder [ARM_EXT_V6T2]  0x00600090 0x0ff000f0 (MLS <$> reg 0 <*> reg 8 <*> reg 12)
  , decoder [ARM_EXT_V6T2]  0x006000b0 0x0f7000f0 (STRHT <$> reg 12 <*> arm_s) -- TODO: check me


  , decoder [ARM_EXT_V6T2]  0x00300090 0x0f3000f0 (pure Undefined)
  , decoder [ARM_EXT_V6T2]  0x00300090 0x0f300090 (ldr <$> arm_bh 5 <*> const False <*> bool 6 <*> reg 12 <*> arm_s)

  , decoder [ARM_EXT_V6T2]  0x03000000 0x0ff00000 (MOVW <$> reg 12 <*> arm_V)
  , decoder [ARM_EXT_V6T2]  0x03400000 0x0ff00000 (MOVT <$> reg 12 <*> arm_V)
  , decoder [ARM_EXT_V6T2]  0x06ff0f30 0x0fff0ff0 (RBIT <$> reg 12 <*> reg 0)
  , decoder [ARM_EXT_V6T2]  0x07a00050 0x0fa00070 (choose 22 UBFX SBFX <*> reg 12 <*> reg 0 <*> integral 7 11 <*> integral' 16 20)

  , decoder [ARM_EXT_V6Z]   0x01600070 0x0ff000f0 (SMC <$> arm_e)

  , decoder [ARM_EXT_V6K]   0xf57ff01f 0xffffffff (pure CLREX) 
  , decoder [ARM_EXT_V6K]   0x01d00f9f 0x0ff00fff (LDREXB <$> reg 12 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False))
  , decoder [ARM_EXT_V6K]   0x01b00f9f 0x0ff00fff (do rt <- reg 12; rn <- reg 16; return (LDREXD rt (succ rt) (MemReg rn (Imm 0) False))) -- Doesn't really need to be this compliated. We could just have the second argument be implicit (but that makes things a little uglier to work with later)
  , decoder [ARM_EXT_V6K]   0x01f00f9f 0x0ff00fff (LDREXH <$> reg 12 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False))
  , decoder [ARM_EXT_V6K]   0x01c00f90 0x0ff00ff0 (STREXB <$> reg 12 <*> reg 0 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False))
  , decoder [ARM_EXT_V6K]   0x01a00f90 0x0ff00ff0 (do rd <- reg 12; rn <- reg 16; rt <- reg 0; return (STREXD rd rt (succ rt) (MemReg rn (Imm 0) False))) -- As above
  , decoder [ARM_EXT_V6K]   0x01e00f90 0x0ff00ff0 (STREXH <$> reg 12 <*> reg 0 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False))

  , decoder [ARM_EXT_V6K]   0x0320f001 0x0fffffff (pure YIELD)
  , decoder [ARM_EXT_V6K]   0x0320f002 0x0fffffff (pure WFE)
  , decoder [ARM_EXT_V6K]   0x0320f003 0x0fffffff (pure WFI)
  , decoder [ARM_EXT_V6K]   0x0320f004 0x0fffffff (pure SEV)
  , decoder [ARM_EXT_V6K]   0x0320f000 0x0fffff00 (pure NOP)
  
  , decoder [ARM_EXT_V6]    0xf1080000 0xfffffe3f (CPSIE <$> bool 8 <*> bool 7 <*> bool 6 <*> pure Nothing)
  , decoder [ARM_EXT_V6]    0xf10a0000 0xfffffe20 (CPSIE <$> bool 8 <*> bool 7 <*> bool 6 <*> (Just <$> integral 0 4))
  , decoder [ARM_EXT_V6]    0xf10C0000 0xfffffe3f (CPSID <$> bool 8 <*> bool 7 <*> bool 6 <*> pure Nothing)
  , decoder [ARM_EXT_V6]    0xf10e0000 0xfffffe20 (CPSID <$> bool 8 <*> bool 7 <*> bool 6 <*> (Just <$> integral 0 4))
  , decoder [ARM_EXT_V6]    0xf1000000 0xfff1fe20 (CPS <$> integral 0 4)

  , decoder [ARM_EXT_V6]    0x06800010 0x0ff00ff0 (PKHBT <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800010 0x0ff00070 (PKHBT <$> reg 12 <*> reg 16 <*> (RegShiftImm S_LSL <$> integral 7 11 <*> reg 0))
  , decoder [ARM_EXT_V6]    0x06800050 0x0ff00ff0 (PKHTB <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ASR 32 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800050 0x0ff00070 (PKHTB <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ASR <$> integral 7 11 <*> reg 0))
  , decoder [ARM_EXT_V6]    0x01900f9f 0x0ff00fff (LDREX  <$> reg 12 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False) )
  , decoder [ARM_EXT_V6]    0x06200f10 0x0ff00ff0 (reg12_reg16_reg0 $ QADD16)
  , decoder [ARM_EXT_V6]    0x06200f90 0x0ff00ff0 (reg12_reg16_reg0 $ QADD8)
  , decoder [ARM_EXT_V6]    0x06200f30 0x0ff00ff0 (reg12_reg16_reg0 $ QASX)
  , decoder [ARM_EXT_V6]    0x06200f70 0x0ff00ff0 (reg12_reg16_reg0 $ QSUB16)
  , decoder [ARM_EXT_V6]    0x06200ff0 0x0ff00ff0 (reg12_reg16_reg0 $ QSUB8)
  , decoder [ARM_EXT_V6]    0x06200f50 0x0ff00ff0 (reg12_reg16_reg0 $ QSAX)
  , decoder [ARM_EXT_V6]    0x06100f10 0x0ff00ff0 (reg12_reg16_reg0 $ SADD16)
  , decoder [ARM_EXT_V6]    0x06100f90 0x0ff00ff0 (reg12_reg16_reg0 $ SADD8)
  , decoder [ARM_EXT_V6]    0x06100f30 0x0ff00ff0 (reg12_reg16_reg0 $ SASX)
  , decoder [ARM_EXT_V6]    0x06300f10 0x0ff00ff0 (reg12_reg16_reg0 $ SHADD16)
  , decoder [ARM_EXT_V6]    0x06300f90 0x0ff00ff0 (reg12_reg16_reg0 $ SHADD8)
  , decoder [ARM_EXT_V6]    0x06300f30 0x0ff00ff0 (reg12_reg16_reg0 $ SHASX)
  , decoder [ARM_EXT_V6]    0x06300f70 0x0ff00ff0 (reg12_reg16_reg0 $ SHSUB16)
  , decoder [ARM_EXT_V6]    0x06300ff0 0x0ff00ff0 (reg12_reg16_reg0 $ SHSUB8)
  , decoder [ARM_EXT_V6]    0x06300f50 0x0ff00ff0 (reg12_reg16_reg0 $ SHSAX)
  , decoder [ARM_EXT_V6]    0x06100f70 0x0ff00ff0 (reg12_reg16_reg0 $ SSUB16)
  , decoder [ARM_EXT_V6]    0x06100ff0 0x0ff00ff0 (reg12_reg16_reg0 $ SSUB8)
  , decoder [ARM_EXT_V6]    0x06100f50 0x0ff00ff0 (reg12_reg16_reg0 $ SSAX)
  , decoder [ARM_EXT_V6]    0x06500f10 0x0ff00ff0 (reg12_reg16_reg0 $ UADD16)
  , decoder [ARM_EXT_V6]    0x06500f90 0x0ff00ff0 (reg12_reg16_reg0 $ UADD8)
  , decoder [ARM_EXT_V6]    0x06500f30 0x0ff00ff0 (reg12_reg16_reg0 $ UASX)
  , decoder [ARM_EXT_V6]    0x06700f10 0x0ff00ff0 (reg12_reg16_reg0 $ UHADD16)
  , decoder [ARM_EXT_V6]    0x06700f90 0x0ff00ff0 (reg12_reg16_reg0 $ UHADD8)
  , decoder [ARM_EXT_V6]    0x06700f30 0x0ff00ff0 (reg12_reg16_reg0 $ UHASX)
  , decoder [ARM_EXT_V6]    0x06700f70 0x0ff00ff0 (reg12_reg16_reg0 $ UHSUB16)
  , decoder [ARM_EXT_V6]    0x06700ff0 0x0ff00ff0 (reg12_reg16_reg0 $ UHSUB8)
  , decoder [ARM_EXT_V6]    0x06700f50 0x0ff00ff0 (reg12_reg16_reg0 $ UHSAX)
  , decoder [ARM_EXT_V6]    0x06600f10 0x0ff00ff0 (reg12_reg16_reg0 $ UQADD16)
  , decoder [ARM_EXT_V6]    0x06600f90 0x0ff00ff0 (reg12_reg16_reg0 $ UQADD8)
  , decoder [ARM_EXT_V6]    0x06600f30 0x0ff00ff0 (reg12_reg16_reg0 $ UQASX)
  , decoder [ARM_EXT_V6]    0x06600f70 0x0ff00ff0 (reg12_reg16_reg0 $ UQSUB16)
  , decoder [ARM_EXT_V6]    0x06600ff0 0x0ff00ff0 (reg12_reg16_reg0 $ UQSUB8)
  , decoder [ARM_EXT_V6]    0x06600f50 0x0ff00ff0 (reg12_reg16_reg0 $ UQSAX)
  , decoder [ARM_EXT_V6]    0x06500f70 0x0ff00ff0 (reg12_reg16_reg0 $ USUB16)
  , decoder [ARM_EXT_V6]    0x06500ff0 0x0ff00ff0 (reg12_reg16_reg0 $ USUB8)
  , decoder [ARM_EXT_V6]    0x06500f50 0x0ff00ff0 (reg12_reg16_reg0 $ USAX) 
  , decoder [ARM_EXT_V6]    0x06bf0f30 0x0fff0ff0 (REV     <$> reg 12 <*> reg 0)
  , decoder [ARM_EXT_V6]    0x06bf0fb0 0x0fff0ff0 (REV16   <$> reg 12 <*> reg 0)
  , decoder [ARM_EXT_V6]    0x06ff0fb0 0x0fff0ff0 (REVSH   <$> reg 12 <*> reg 0)
  , decoder [ARM_EXT_V6]    0xf8100a00 0xfe50ffff (rfe <$> direction 23 <*> order 24 <*> bool 21 <*> reg 16)
  , decoder [ARM_EXT_V6]    0x06bf0070 0x0fff0ff0 (SXTH    <$> reg 12 <*>            (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06bf0470 0x0fff0ff0 (SXTH    <$> reg 12 <*>            (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06bf0870 0x0fff0ff0 (SXTH    <$> reg 12 <*>            (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06bf0c70 0x0fff0ff0 (SXTH    <$> reg 12 <*>            (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x068f0070 0x0fff0ff0 (SXTB16  <$> reg 12 <*>            (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x068f0470 0x0fff0ff0 (SXTB16  <$> reg 12 <*>            (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x068f0870 0x0fff0ff0 (SXTB16  <$> reg 12 <*>            (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x068f0c70 0x0fff0ff0 (SXTB16  <$> reg 12 <*>            (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06af0070 0x0fff0ff0 (SXTB    <$> reg 12 <*>            (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06af0470 0x0fff0ff0 (SXTB    <$> reg 12 <*>            (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06af0870 0x0fff0ff0 (SXTB    <$> reg 12 <*>            (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06af0c70 0x0fff0ff0 (SXTB    <$> reg 12 <*>            (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ff0070 0x0fff0ff0 (UXTH    <$> reg 12 <*>            (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ff0470 0x0fff0ff0 (UXTH    <$> reg 12 <*>            (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ff0870 0x0fff0ff0 (UXTH    <$> reg 12 <*>            (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ff0c70 0x0fff0ff0 (UXTH    <$> reg 12 <*>            (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06cf0070 0x0fff0ff0 (UXTB16  <$> reg 12 <*>            (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06cf0470 0x0fff0ff0 (UXTB16  <$> reg 12 <*>            (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06cf0870 0x0fff0ff0 (UXTB16  <$> reg 12 <*>            (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06cf0c70 0x0fff0ff0 (UXTB16  <$> reg 12 <*>            (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ef0070 0x0fff0ff0 (UXTB    <$> reg 12 <*>            (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ef0470 0x0fff0ff0 (UXTB    <$> reg 12 <*>            (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ef0870 0x0fff0ff0 (UXTB    <$> reg 12 <*>            (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06ef0c70 0x0fff0ff0 (UXTB    <$> reg 12 <*>            (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06b00070 0x0ff00ff0 (SXTAH   <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06b00470 0x0ff00ff0 (SXTAH   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06b00870 0x0ff00ff0 (SXTAH   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06b00c70 0x0ff00ff0 (SXTAH   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800070 0x0ff00ff0 (SXTAB16 <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800470 0x0ff00ff0 (SXTAB16 <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800870 0x0ff00ff0 (SXTAB16 <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800c70 0x0ff00ff0 (SXTAB16 <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00070 0x0ff00ff0 (SXTAB   <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00470 0x0ff00ff0 (SXTAB   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00870 0x0ff00ff0 (SXTAB   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00c70 0x0ff00ff0 (SXTAB   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06f00070 0x0ff00ff0 (UXTAH   <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06f00470 0x0ff00ff0 (UXTAH   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06f00870 0x0ff00ff0 (UXTAH   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06f00c70 0x0ff00ff0 (UXTAH   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06c00070 0x0ff00ff0 (UXTAB16 <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06c00470 0x0ff00ff0 (UXTAB16 <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06c00870 0x0ff00ff0 (UXTAB16 <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06c00c70 0x0ff00ff0 (UXTAB16 <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00070 0x0ff00ff0 (UXTAB   <$> reg 12 <*> reg 16 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00470 0x0ff00ff0 (UXTAB   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 8 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00870 0x0ff00ff0 (UXTAB   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 16 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00c70 0x0ff00ff0 (UXTAB   <$> reg 12 <*> reg 16 <*> (RegShiftImm S_ROR 24 <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06800fb0 0x0ff00ff0 (reg12_reg16_reg0 $ SEL)
  , decoder [ARM_EXT_V6]    0xf1010000 0xfffffc00 (SETEND <$> (enum . bit 9))
  , decoder [ARM_EXT_V6]    0x0700f010 0x0ff0f0d0 (smuad  <$> enum . bit 5 <*> reg 16 <*> reg 0 <*> reg 8) -- TODO: double check enum direction is correct for first arg
  , decoder [ARM_EXT_V6]    0x0700f050 0x0ff0f0d0 (smusd  <$> enum . bit 5 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V6]    0x07000010 0x0ff000d0 (smlad  <$> enum . bit 5 <*> reg 16 <*> reg 0 <*> reg 8 <*> reg 12)
  , decoder [ARM_EXT_V6]    0x07400010 0x0ff000d0 (smlald <$> enum . bit 5 <*> reg 12 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V6]    0x07000050 0x0ff000d0 (smlsd  <$> enum . bit 5 <*> reg 16 <*> reg 0 <*> reg 8 <*> reg 12) 
  , decoder [ARM_EXT_V6]    0x07400050 0x0ff000d0 (smlsld <$> enum . bit 5 <*> reg 12 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V6]    0x0750f010 0x0ff0f0d0 (smmul  <$> bool 5 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V6]    0x07500010 0x0ff000d0 (smmla  <$> bool 5 <*> reg 16 <*> reg 0 <*> reg 8 <*> reg 12)
  , decoder [ARM_EXT_V6]    0x075000d0 0x0ff000d0 (smmls  <$> bool 5 <*> reg 16 <*> reg 0 <*> reg 8 <*> reg 12)
  , decoder [ARM_EXT_V6]    0xf84d0500 0xfe5fffe0 (srs  <$> direction 23 <*> order 24 <*> bool 21 <*> reg 16 <*> integral 0 4)
  , decoder [ARM_EXT_V6]    0x06a00010 0x0fe00ff0 (SSAT   <$> reg 12 <*> integral' 16 20 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00010 0x0fe00070 (SSAT   <$> reg 12 <*> integral' 16 20 <*> (RegShiftImm S_LSL <$> integral 7 11 <*> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00050 0x0fe00070 (SSAT   <$> reg 12 <*> integral' 16 20 <*> (RegShiftImm S_ASR <$> integral 7 11 <*> reg 0))
  , decoder [ARM_EXT_V6]    0x06a00f30 0x0ff00ff0 (SSAT16 <$> reg 12 <*> integral' 16 19 <*> reg 0)
  , decoder [ARM_EXT_V6]    0x01800f90 0x0ff00ff0 (STREX  <$> reg 12 <*> reg 0 <*> (MemReg <$> reg 16 <*> pure (Imm 0) <*> pure False) )
  , decoder [ARM_EXT_V6]    0x00400090 0x0ff000f0 (UMAAL  <$> reg 12 <*> reg 16 <*> reg 0 <*> reg 8)
  , decoder [ARM_EXT_V6]    0x0780f010 0x0ff0f0f0 (reg16_reg0_reg8 $ USAD8 )
  , decoder [ARM_EXT_V6]    0x07800010 0x0ff000f0 (reg16_reg0_reg8_reg12 $ USADA8)
  , decoder [ARM_EXT_V6]    0x06e00010 0x0fe00ff0 (USAT   <$> reg 12 <*> integral' 16 20 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00010 0x0fe00070 (USAT   <$> reg 12 <*> integral' 16 20 <*> (RegShiftImm S_LSL <$> integral 7 11 <*> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00050 0x0fe00070 (USAT   <$> reg 12 <*> integral' 16 20 <*> (RegShiftImm S_ASR <$> integral 7 11 <*> reg 0))
  , decoder [ARM_EXT_V6]    0x06e00f30 0x0ff00ff0 (USAT16 <$> reg 12 <*> integral' 16 19 <*> reg 0)
 
  , decoder [ARM_EXT_V5J]   0x012fff20 0x0ffffff0 (BXJ <$> reg 0)
 
  , decoder [ARM_EXT_V5]    0xe1200070 0xfff000f0 (BKPT <$> ((\x y -> x `shiftL` 4 .|. y) <$> integral 8 19 <*> integral 0 3)) 
  , decoder [ARM_EXT_V5]    0xfa000000 0xfe000000 (BLXUC <$> arm_B)
  , decoder [ARM_EXT_V5]    0x012fff30 0x0ffffff0 (BLX <$> reg 0)
  , decoder [ARM_EXT_V5]    0x016f0f10 0x0fff0ff0 (CLZ <$> reg 12 <*> reg 0)
  
  , decoder [ARM_EXT_V5E]   0x000000d0 0x0e1000f0 (LDRD <$> reg 12 <*> arm_s)
  , decoder [ARM_EXT_V5E]   0x000000f0 0x0e1000f0 (STRD <$> reg 12 <*> arm_s)
  , decoder [ARM_EXT_V5E]   0xf450f000 0xfc70f000 (PLD <$> arm_a)
  , decoder [ARM_EXT_V5ExP] 0x01000080 0x0ff000f0 (reg16_reg0_reg8_reg12 $ SMLABB)
  , decoder [ARM_EXT_V5ExP] 0x010000a0 0x0ff000f0 (reg16_reg0_reg8_reg12 $ SMLATB)
  , decoder [ARM_EXT_V5ExP] 0x010000c0 0x0ff000f0 (reg16_reg0_reg8_reg12 $ SMLABT)
  , decoder [ARM_EXT_V5ExP] 0x010000e0 0x0ff000f0 (reg16_reg0_reg8_reg12 $ SMLATT)
  
  , decoder [ARM_EXT_V5ExP] 0x01400080 0x0ff000f0 (reg12_reg16_reg0_reg8 $ SMLAWB)
  , decoder [ARM_EXT_V5ExP] 0x014000a0 0x0ff000f0 (reg12_reg16_reg0_reg8 $ SMLAWT)
  
  , decoder [ARM_EXT_V5ExP] 0x01400080 0x0ff000f0 (reg12_reg16_reg0_reg8 $ SMLALBB)
  , decoder [ARM_EXT_V5ExP] 0x014000a0 0x0ff000f0 (reg12_reg16_reg0_reg8 $ SMLALTB)
  , decoder [ARM_EXT_V5ExP] 0x014000c0 0x0ff000f0 (reg12_reg16_reg0_reg8 $ SMLALBT)
  , decoder [ARM_EXT_V5ExP] 0x014000e0 0x0ff000f0 (reg12_reg16_reg0_reg8 $ SMLALTT)
  
  , decoder [ARM_EXT_V5ExP] 0x01600080 0x0ff0f0f0 (reg16_reg0_reg8 $ SMULBB)
  , decoder [ARM_EXT_V5ExP] 0x016000a0 0x0ff0f0f0 (reg16_reg0_reg8 $ SMULTB)
  , decoder [ARM_EXT_V5ExP] 0x016000c0 0x0ff0f0f0 (reg16_reg0_reg8 $ SMULBT)
  , decoder [ARM_EXT_V5ExP] 0x016000e0 0x0ff0f0f0 (reg16_reg0_reg8 $ SMULTT)
  
  , decoder [ARM_EXT_V5ExP] 0x012000a0 0x0ff0f0f0 (reg16_reg0_reg8 $ SMULWB)
  , decoder [ARM_EXT_V5ExP] 0x012000e0 0x0ff0f0f0 (reg16_reg0_reg8 $ SMULWT)
  
  , decoder [ARM_EXT_V5ExP] 0x01000050 0x0ff00ff0 (reg12_reg0_reg16 $ QADD)
  , decoder [ARM_EXT_V5ExP] 0x01400050 0x0ff00ff0 (reg12_reg0_reg16 $ QDADD)
  , decoder [ARM_EXT_V5ExP] 0x01200050 0x0ff00ff0 (reg12_reg0_reg16 $ QSUB)
  , decoder [ARM_EXT_V5ExP] 0x01600050 0x0ff00ff0 (reg12_reg0_reg16 $ QDSUB)
  
  --{ARM_EXT_V1, 0x052d0004, 0x0fff0fff, "push%c\t{%12-15r}\t\t; (str%c %12-15r, %a)"},

  {-  
    , decoder [ARM_EXT_V1]    0x052d0004 0x0fff0fff (STRH <$> reg 12 <*> arm_a)
    , decoder [ARM_EXT_V1]    0x04000000 0x0e100000 (str <$> arm_bw 22 <*> arm_t <*> reg 12 <*> arm_a)
    , decoder [ARM_EXT_V1]    0x06000000 0x0e100ff0 (str <$> arm_bw 22 <*> arm_t <*> reg 12 <*> arm_a)
    , decoder [ARM_EXT_V1]    0x04000000 0x0c100010 (str <$> arm_bw 22 <*> arm_t <*> reg 12 <*> arm_a)
  -}
  
  , decoder [ARM_EXT_V1]    0x00000090 0x0e100090 (str <$> arm_bh 5 <*> bool 6 <*> reg 12 <*> arm_s)
  , decoder [ARM_EXT_V1]    0x00100090 0x0e100090 (ldr <$> arm_bh 5 <*> pure False <*> bool 6 <*> reg 12 <*> arm_s)

  , decoder [ARM_EXT_V1]    0x00000000 0x0de00000 (bool20_reg12_reg16_o $ and)
  --{ARM_EXT_V1, 0x02000000, 0x0fe00000, "and%20's%c\t%12-15r, %16-19r, %o"},
  --{ARM_EXT_V1, 0x00000000, 0x0fe00010, "and%20's%c\t%12-15r, %16-19r, %o"},
  --{ARM_EXT_V1, 0x00000010, 0x0fe00090, "and%20's%c\t%12-15R, %16-19R, %o"}, 

  , decoder [ARM_EXT_V1]    0x00200000 0x0de00000 (bool20_reg12_reg16_o $ eor)
  -- {ARM_EXT_V1, 0x02200000, 0x0fe00000, "eor%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00200000, 0x0fe00010, "eor%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00200010, 0x0fe00090, "eor%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x00400000 0x0de00000 (bool20_reg12_reg16_o $ sub)
  -- {ARM_EXT_V1, 0x02400000, 0x0fe00000, "sub%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00400000, 0x0fe00010, "sub%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00400010, 0x0fe00090, "sub%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x00600000 0x0de00000 (bool20_reg12_reg16_o $ rsb)
  -- {ARM_EXT_V1, 0x02600000, 0x0fe00000, "rsb%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00600000, 0x0fe00010, "rsb%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00600010, 0x0fe00090, "rsb%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x00800000 0x0de00000 (bool20_reg12_reg16_o $ add)
  -- {ARM_EXT_V1, 0x02800000, 0x0fe00000, "add%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00800000, 0x0fe00010, "add%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00800010, 0x0fe00090, "add%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x00a00000 0x0de00000 (bool20_reg12_reg16_o $ adc)
  -- {ARM_EXT_V1, 0x02a00000, 0x0fe00000, "adc%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00a00000, 0x0fe00010, "adc%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00a00010, 0x0fe00090, "adc%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x00c00000 0x0de00000 (bool20_reg12_reg16_o $ sbc)
  -- {ARM_EXT_V1, 0x02c00000, 0x0fe00000, "sbc%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00c00000, 0x0fe00010, "sbc%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00c00010, 0x0fe00090, "sbc%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x00e00000 0x0de00000 (bool20_reg12_reg16_o $ rsc)
  -- {ARM_EXT_V1, 0x02e00000, 0x0fe00000, "rsc%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00e00000, 0x0fe00010, "rsc%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x00e00010, 0x0fe00090, "rsc%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V3]    0x0120f000 0x0db0f000 (MSR <$> bool 18 <*> bool 19 <*> arm_o)
  , decoder [ARM_EXT_V3]    0x010f0000 0x0fbf0fff (MRS <$> reg 12 <*> choose 22 SPSR CPSR)
  
  , decoder [ARM_EXT_V1]    0x01000000 0x0de00000 (TST <$> reg 16 <*> arm_o)
  -- {ARM_EXT_V1, 0x03000000, 0x0fe00000, "tst%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01000000, 0x0fe00010, "tst%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01000010, 0x0fe00090, "tst%p%c\t%16-19R, %o"},
  
  , decoder [ARM_EXT_V1]    0x01200000 0x0de00000 (TEQ <$> reg 16 <*> arm_o)
  -- {ARM_EXT_V1, 0x03200000, 0x0fe00000, "teq%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01200000, 0x0fe00010, "teq%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01200010, 0x0fe00090, "teq%p%c\t%16-19R, %o"},
  
  , decoder [ARM_EXT_V1]    0x01400000 0x0de00000 (CMP <$> reg 16 <*> arm_o) 
  -- {ARM_EXT_V1, 0x03400000, 0x0fe00000, "cmp%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V3, 0x01400000, 0x0ff00010, "mrs%c\t%12-15R, %22?SCPSR"},
  -- {ARM_EXT_V1, 0x01400000, 0x0fe00010, "cmp%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01400010, 0x0fe00090, "cmp%p%c\t%16-19R, %o"},
  
  , decoder [ARM_EXT_V1]    0x01600000 0x0de00000 (CMN <$> reg 16 <*> arm_o)
  -- {ARM_EXT_V1, 0x03600000, 0x0fe00000, "cmn%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01600000, 0x0fe00010, "cmn%p%c\t%16-19r, %o"},
  -- {ARM_EXT_V1, 0x01600010, 0x0fe00090, "cmn%p%c\t%16-19R, %o"},
  
  , decoder [ARM_EXT_V1]    0x01800000 0x0de00000 (orr <$> bool 20 <*> reg 12 <*> reg 16 <*> arm_o)
  -- {ARM_EXT_V1, 0x03800000, 0x0fe00000, "orr%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x01800000, 0x0fe00010, "orr%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x01800010, 0x0fe00090, "orr%20's%c\t%12-15R, %16-19R, %o"},

  , decoder [ARM_EXT_V1]    0x03a00000 0x0fef0000 (mov <$> bool 20 <*> reg 12 <*> arm_o)
  , decoder [ARM_EXT_V1]    0x01a00000 0x0def0ff0 (mov <$> bool 20 <*> reg 12 <*> (Reg <$> reg 0))
  , decoder [ARM_EXT_V1]    0x01a00000 0x0def0060 (lsl <$> bool 20 <*> reg 12 <*> arm_q)
  , decoder [ARM_EXT_V1]    0x01a00020 0x0def0060 (lsr <$> bool 20 <*> reg 12 <*> arm_q)
  , decoder [ARM_EXT_V1]    0x01a00040 0x0def0060 (asr <$> bool 20 <*> reg 12 <*> arm_q)
  , decoder [ARM_EXT_V1]    0x01a00060 0x0def0ff0 (rrx <$> bool 20 <*> reg 12 <*> reg 0)
  , decoder [ARM_EXT_V1]    0x01a00060 0x0def0060 (ror <$> bool 20 <*> reg 12 <*> arm_q)
                                
  , decoder [ARM_EXT_V1]    0x01c00000 0x0de00000 (bic <$> bool 20 <*> reg 12 <*> reg 16 <*> arm_o)
  -- {ARM_EXT_V1, 0x03c00000, 0x0fe00000, "bic%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x01c00000, 0x0fe00010, "bic%20's%c\t%12-15r, %16-19r, %o"},
  -- {ARM_EXT_V1, 0x01c00010, 0x0fe00090, "bic%20's%c\t%12-15R, %16-19R, %o"},
  
  , decoder [ARM_EXT_V1]    0x01e00000 0x0de00000 (mvn <$> bool 20 <*> reg 12 <*> arm_o)
  -- {ARM_EXT_V1, 0x03e00000, 0x0fe00000, "mvn%20's%c\t%12-15r, %o"},
  -- {ARM_EXT_V1, 0x01e00000, 0x0fe00010, "mvn%20's%c\t%12-15r, %o"},
  -- {ARM_EXT_V1, 0x01e00010, 0x0fe00090, "mvn%20's%c\t%12-15R, %o"},
  

  , decoder [ARM_EXT_V1]    0x06000010 0x0e000010 (pure Undefined)
  
  -- {ARM_EXT_V1, 0x049d0004, 0x0fff0fff, "pop%c\t{%12-15r}\t\t; (ldr%c %12-15r, %a)"},
  -- 
  -- {ARM_EXT_V1, 0x04500000, 0x0c500000, "ldrb%t%c\t%12-15R, %a"},
  -- 
  -- {ARM_EXT_V1, 0x04300000, 0x0d700000, "ldrt%c\t%12-15R, %a"},
  -- {ARM_EXT_V1, 0x04100000, 0x0c500000, "ldr%c\t%12-15r, %a"},
  
  
  , decoder [ARM_EXT_V1]    0x049d0004 0x0fff0fff (LDRH <$> reg 12 <*> arm_a)
  , decoder [ARM_EXT_V1]    0x04100000 0x0c100000 (ldr <$> arm_bw 22 <*> arm_t <*> pure False <*> reg 12 <*> arm_a)

  , decoder [ARM_EXT_V1]    0x092d0000 0x0fff0000 (PUSH <$> (Regs <$> arm_m))
  , decoder [ARM_EXT_V1]    0x08800000 0x0ff00000 (STM <$> bool 21 <*> reg 16 <*> (RegsCaret <$> arm_m))
  , decoder [ARM_EXT_V1]    0x08000000 0x0e100000 (ldm <$> direction 23 <*> order 24 <*> bool 21 <*> reg 16 <*> (choose 22 Regs RegsCaret <*> arm_m))
  , decoder [ARM_EXT_V1]    0x08bd0000 0x0fff0000 (POP <$> (Regs <$> arm_m))
  , decoder [ARM_EXT_V1]    0x08900000 0x0f900000 (LDM <$> bool 21 <*> reg 16 <*> (RegsCaret <$> arm_m))
  , decoder [ARM_EXT_V1]    0x08100000 0x0e100000 (ldm <$> direction 23 <*> order 24 <*> bool 21 <*> reg 16 <*> (choose 22 Regs RegsCaret <*> arm_m))
  , decoder [ARM_EXT_V1]    0x0a000000 0x0e000000 (B <$> bool 24 <*> arm_b)
  , decoder [ARM_EXT_V1]    0x0f000000 0x0f000000 (SVC <$> integral 0 23)

  , decoder [ARM_EXT_V1]    0x00000000 0x00000000 (pure Undefined)
  ]

armOpcodeMatches :: Word32 -> ARMOpcode32 -> Bool
armOpcodeMatches x (ARMOpcode32 _ v m _) = x .&. m == v 

armDecodeOp :: Word32 -> ARMOpcode32 -> ARMInstruction
armDecodeOp x (ARMOpcode32 _ _ _ d) = d x

armDecode :: Word32 -> Maybe ARMInstruction
armDecode i = fmap (armDecodeOp i) . find (armOpcodeMatches i) $ armOpcodes