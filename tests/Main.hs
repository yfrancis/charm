module Main where

import Data.Word

import Architecture.ARM.Instructions.UAL
import Architecture.ARM.Decoder.ARM
import Architecture.ARM.Pretty

import Test.Framework (defaultMain, testGroup)
import Test.Framework.Providers.HUnit

import Test.HUnit

import Objdump
import System.Random

import Data.Char
import Data.List
import Data.Maybe

import Text.Printf

ualMatches :: Word32 -> UALInstruction -> String -> Assertion
ualMatches off i@(Conditional _ _) s | "invalid" `isInfixOf` s || "undefined" `isInfixOf` s || null s = assertFailure (printf "invalid instruction '%s' decoded to '%s'" s (showInstruction i))
ualMatches off i@(Unconditional _) s | "invalid" `isInfixOf` s || "undefined" `isInfixOf` s || null s = assertFailure (printf "invalid instruction '%s' decoded to '%s'" s (showInstruction i))
ualMatches off Undefined s = assertBool "" True
ualMatches off x ('s':'t':'m':'i':'a':r) = ualMatches off x $ 's':'t':'m':r
ualMatches off x ('l':'d':'m':'i':'a':r) = ualMatches off x $ 'l':'d':'m':r
ualMatches off (Conditional cond (B op)) s = map toLower (showInstruction (Conditional cond (B $ op + (fromIntegral off)))) @?= s
ualMatches off (Conditional cond (BL op)) s = map toLower (showInstruction (Conditional cond (BL $ op + (fromIntegral off)))) @?= s
ualMatches off (Unconditional (BLXUC op)) s = map toLower (showInstruction (Unconditional (BLXUC $ op + (fromIntegral off)))) @?= s
ualMatches off x s = map toLower (showInstruction x) @?= s

main = 
  do rs <- fmap (take 1000 . randoms) getStdGen
     let ws = map fromIntegral (rs :: [Int]) :: [Word32]
     insns <- disassemble "/Users/pumpkin/summon-arm-toolchain/sources/src/binutils/objdump" ["-b", "binary", "-m", "arm"] ws
     let ours = map armDecode ws
     let tests = zipWith4 (\off w o u -> testCase (printf "0x%08x: 0x%08x %s" off w u) (ualMatches off o u)) [0,4..] ws ours insns
     defaultMain [testGroup "Instructions from objdump" tests]

{-
  0x000002f8: 0x4141fb0a mrsmi pc, SPSR: [Failed]
Failed: expected: "mrsmi pc, SPSR"
 but got: "mrsmi pc, cpsr"
 
 0x000001f8: 0x346f8e23 strbtcc r8, [pc], #-3619: [Failed]
Failed: expected: "strbtcc r8, [pc], #-3619"
 but got: "strbtcc r8, [pc], #3619

  0x000003b4: 0x542fdb6f strtpl sp, [pc], #-2927: [Failed]
Failed: expected: "strtpl sp, [pc], #-2927"
 but got: "strtpl sp, [pc], #2927"


  0x000002cc: 0x7366f7f2 msrvc SPSR_sx, #63438848: [Failed]
Failed: expected: "msrvc SPSR_sx, #63438848"
 but got: "msrvc"


  0x00009664: 0xe1b0fb1a lsls pc, sl, fp: [Failed]
Failed: expected: "lsls pc, sl, fp"
 but got: "lsls pc, sl, lsl fp"

  0x00009578: 0xa1ff98b6 ldrhge r9, [pc, #134]: [Failed]
Failed: expected: "ldrhge r9, [pc, #134]"
 but got: "ldrhge r9, [pc, #134]!"
 
-- Do I care about this?
   0x00000c24: 0x017c80f0 ldrsheq r8, [ip, #0]!: [Failed]
 Failed: expected: "ldrsheq r8, [ip, #0]!"
  but got: "ldrsheq r8, [ip]!"
-}