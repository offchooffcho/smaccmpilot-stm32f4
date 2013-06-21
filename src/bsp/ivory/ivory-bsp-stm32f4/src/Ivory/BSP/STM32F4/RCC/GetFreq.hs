{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}

--
-- GetFreq.hs --- Run-time frequency information from RCC driver
--
-- Copyright (C) 2013, Galois, Inc.
-- All Rights Reserved.
--

module Ivory.BSP.STM32F4.RCC.GetFreq where

import Ivory.Language
import Ivory.Stdlib
import Ivory.BitData
import Ivory.HW

import Ivory.BSP.STM32F4.RCC.RegTypes
import Ivory.BSP.STM32F4.RCC.Regs

-- Not sure what class constraints needed to write eqBits

eqBits :: (BitData a) => a -> a -> IBool
eqBits l r = (toBits l) ==? (toBits r)

hsiFreq, hseFreq :: Uint32
hsiFreq = 16000000 -- from stm32f4xx.h
hseFreq = 24000000 -- Actually depends on preprocessor value!

getFreqSysClk :: (eff `AllocsIn` s) => Ivory eff Uint32
getFreqSysClk = do
  cfgr <- getReg regRCC_CFGR
  sysClkSource (cfgr #. rcc_cfgr_sws)
  where
  -- Catchall is hsiFreq, should be impossible.
  sysClkSource sws = foldl aux (return hsiFreq) tbl
    where aux k (v,d) = ifte (eqBits sws v) d k
          tbl = [(rcc_sysclk_hsi, return hsiFreq)
                ,(rcc_sysclk_hse, return hseFreq)
                ,(rcc_sysclk_pll, pllSysClk)
                ]

pllSysClk :: (eff `AllocsIn` s) => Ivory eff Uint32
pllSysClk = do
  pllcfgr <- getReg regRCC_PLLCFGR
  let pllm    = safeCast $ toRep $ pllcfgr #. rcc_pllcfgr_pllm
      plln    = safeCast $ toRep $ pllcfgr #. rcc_pllcfgr_plln
      srcFreq = (toRep (pllcfgr #. rcc_pllcfgr_pllsrc) >? 0) ? (hseFreq,hsiFreq)
      pllvco  = (srcFreq `iDiv` pllm) * plln
      pllp    = pllpToInt $ pllcfgr #. rcc_pllcfgr_pllp
  return (pllvco `iDiv` pllp)
  where
  pllpToInt p = foldl aux 1 tbl -- Catchall is 1, should be impossible.
    where
    aux k (v,d) = (eqBits p v) ? (d,k)
    tbl = [(rcc_pllp_div2,   2)
          ,(rcc_pllp_div4,   4)
          ,(rcc_pllp_div6,   6)
          ,(rcc_pllp_div8,   8)
          ]

getFreqHClk :: (eff `AllocsIn` s) => Ivory eff Uint32
getFreqHClk = do
  sysclk <- getFreqSysClk
  cfgr <- getReg regRCC_CFGR
  return $ divideHPRE (cfgr #. rcc_cfgr_hpre) sysclk

getFreqPClk1 :: (eff `AllocsIn` s) => Ivory eff Uint32
getFreqPClk1 = do
  sysclk <- getFreqSysClk
  cfgr <- getReg regRCC_CFGR
  return $ dividePPREx (cfgr #. rcc_cfgr_ppre1) sysclk

getFreqPClk2 :: (eff `AllocsIn` s) => Ivory eff Uint32
getFreqPClk2 = do
  sysclk <- getFreqSysClk
  cfgr <- getReg regRCC_CFGR
  return $ dividePPREx (cfgr #. rcc_cfgr_ppre2) sysclk

data PClk = PClk1 | PClk2

getFreqPClk :: (eff `AllocsIn` s) => PClk -> Ivory eff Uint32
getFreqPClk PClk1 = getFreqPClk1
getFreqPClk PClk2 = getFreqPClk2

divideHPRE :: RCC_HPRE -> Uint32 -> Uint32
divideHPRE hpre n = n `iDiv` divisor
  where
  divisor = foldl aux 1 tbl -- Catchall is 1: none has bits 0b0xxx
  aux k (hpreV, d) = (eqBits hpreV hpre) ? (d,k)
  tbl = [(rcc_hpre_none,   1)
        ,(rcc_hpre_div2,   2)
        ,(rcc_hpre_div4,   4)
        ,(rcc_hpre_div8,   8)
        ,(rcc_hpre_div16,  16)
        ,(rcc_hpre_div64,  64)
        ,(rcc_hpre_div128, 128)
        ,(rcc_hpre_div256, 256)
        ,(rcc_hpre_div512, 512)
        ]

dividePPREx :: RCC_PPREx -> Uint32 -> Uint32
dividePPREx pprex n = n `iDiv` divisor
  where
  divisor = foldl aux 1 tbl -- Catchall is 1: none has bits 0b0xx
  aux k (ppreV, d) = (eqBits ppreV pprex) ? (d,k)
  tbl = [(rcc_pprex_none,   1)
        ,(rcc_pprex_div2,   2)
        ,(rcc_pprex_div4,   4)
        ,(rcc_pprex_div8,   8)
        ,(rcc_pprex_div16,  16)
        ]
