{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Ivory.BSP.STM32F4.Init where

import Ivory.Language
import Ivory.Tower
import Ivory.Stdlib
import Ivory.BitData
import Ivory.HW
import Ivory.HW.Module (hw_moduledef)

import Ivory.BSP.ARMv7M.Exception
import Ivory.BSP.STM32F4.VectorTable
import Ivory.BSP.STM32F4.RCC
import Ivory.BSP.STM32F4.PWR
import Ivory.BSP.STM32F4.Flash

stm32f4InitModule :: (BoardHSE p) => Proxy p -> Module
stm32f4InitModule platform = package "stm32f4_ivory_init" $ do
  inclHeader "stm32f4_init.h"
  sourceDep  "stm32f4_init.h"
  sourceDep  "stm32f4_init.c"
  incl (reset_handler platform)
  hw_moduledef
  private $ do
    incl (init_clocks platform)
    incl init_relocate
    incl init_libc
    incl main_proc

stm32f4InitTower :: forall p . (BoardHSE p) => Tower p ()
stm32f4InitTower = do
  towerArtifact vectorArtifact
  towerModule (stm32f4InitModule (Proxy :: Proxy p))
  where
  vectorArtifact = Artifact
    { artifact_filepath = "stm32f4_vectors.s"
    , artifact_contents = vector_table
    , artifact_tag      = "SOURCES"
    }

init_relocate :: Def('[]:->())
init_relocate = externProc "init_relocate"

init_libc :: Def('[]:->())
init_libc = externProc "init_libc"

main_proc :: Def('[]:->())
main_proc = externProc "main"

reset_handler :: (BoardHSE p) => Proxy p => Def('[]:->())
reset_handler platform = proc (exceptionHandlerName Reset) $ body $ do
  call_ init_relocate
  call_ (init_clocks platform)
  call_ init_libc
  call_ main_proc

init_clocks :: (BoardHSE p) => Proxy p -> Def('[]:->())
init_clocks platform = proc "init_clocks" $ body $ do
  -- RCC clock config to default reset state
  --   RCC->CR |= 0x01
  --   RCC->CFGR = 0
  modifyReg regRCC_CR $ setBit rcc_cr_hsi_on
  modifyReg regRCC_CFGR $ do
    setField rcc_cfgr_mco2     rcc_mcox_sysclk
    setField rcc_cfgr_mco2_pre rcc_mcoxpre_none
    setField rcc_cfgr_mco1_pre rcc_mcoxpre_none
    clearBit rcc_cfgr_i2ssrc
    setField rcc_cfgr_mco1     rcc_mcox_sysclk
    setField rcc_cfgr_rtcpre   (fromRep 0)
    setField rcc_cfgr_ppre2    rcc_pprex_none
    setField rcc_cfgr_ppre1    rcc_pprex_none
    setField rcc_cfgr_hpre     rcc_hpre_none
    setField rcc_cfgr_sws      rcc_sysclk_hsi

  -- Reset HSEOn, CSSOn, PLLOn bits
  --   RCC->CR &= etc
  modifyReg regRCC_CR $ do
    clearBit rcc_cr_hse_on
    clearBit rcc_cr_css_on
    clearBit rcc_cr_pll_on

  -- Reset PLLCFGR register
  --   RCC->PLLCFGR = 0x24003010
  modifyReg regRCC_PLLCFGR $ do
    setField rcc_pllcfgr_pllq   (fromRep 2)
    setBit   rcc_pllcfgr_pllsrc
    setField rcc_pllcfgr_pllp   rcc_pllp_div2
    setField rcc_pllcfgr_plln   (fromRep 192)
    setField rcc_pllcfgr_pllm   (fromRep 16)

  -- Reset HSEBYP bit
  --   RCC->CR &= etc
  modifyReg regRCC_CR $ clearBit rcc_cr_hse_byp

  -- Disable all interrupts
  --   RCC->CIR = 0x0
  modifyReg regRCC_CIR $ do
    clearBit rcc_cir_plli2s_rdyie
    clearBit rcc_cir_pll_rdyie
    clearBit rcc_cir_hse_rdyie
    clearBit rcc_cir_hsi_rdyie
    clearBit rcc_cir_lse_rdyie
    clearBit rcc_cir_lsi_rdyie

  -- Enable HSE
  --   RCC->CR |= RCC_CR_HSEON
  modifyReg regRCC_CR $ setBit rcc_cr_hse_on

  -- Spin for a little bit waiting for RCC->CR HSERDY bit to be high
  hserdy <- local (ival false)
  arrayMap $ \(_ :: Ix 1024) -> do
    cr <- getReg regRCC_CR
    when (bitToBool (cr #. rcc_cr_hse_rdy)) $ do
      store hserdy true
      breakOut

  -- Handle exception case when HSERDY fails.
  success <- deref hserdy
  unless success $ do
    comment "waiting for HSERDY failed: check your hardware for a fault"
    comment "XXX handle this exception case with a breakpoint or something"
    forever $ return ()

  -- Select regulator voltage output scale 1 mode, sys freq 168mhz
  --   RCC->APB1ENR |= RCC_APB1ENR_PWREN
  modifyReg regRCC_APB1ENR $ setBit rcc_apb1en_pwr
  --   PWR->CR |= PWR_CR_VOS
  modifyReg regPWR_CR $ setBit pwr_cr_vos
  -- HCLK = SYSCLK div 1
  -- PCLK2 = HCLK div 2
  -- PCLK1 = HCLK div 4
  modifyReg regRCC_CFGR $ do
    setField rcc_cfgr_hpre  rcc_hpre_none
    setField rcc_cfgr_ppre2 rcc_pprex_div2
    setField rcc_cfgr_ppre1 rcc_pprex_div4

  -- Configure main PLL:
  --   RCC->PLLCFGR = PLL_M | PLL_N << 6 | ((PLL_P >> 1) -1) << 16 | PLLSRC_HSE
  --                | PLL_Q << 24
  --                where
  --                PLL_M = HSE_FREQ / 1000000
  --                PLL_N = 336
  --                PLL_P = 2
  --                PLL_Q = 7
  modifyReg regRCC_PLLCFGR $ do
    let m = fromIntegral ((hseFreqHz platform) `div` 1000000)
        n = 336
        p = 2
        q = 7
    setField rcc_pllcfgr_pllm (fromRep m)
    setField rcc_pllcfgr_plln (fromRep n)
    setField rcc_pllcfgr_pllp (fromRep p)
    setField rcc_pllcfgr_pllq (fromRep q)

  -- Enable main PLL:
  --   RCC->CR |= PLLON
  modifyReg regRCC_CR $ setBit rcc_cr_pll_on
  -- Spin until RCC->CR PLLRDY bit is high
  forever $ do
    cr <- getReg regRCC_CR
    when (bitToBool (cr #. rcc_cr_pll_rdy)) $ breakOut

  -- Configure flash prefetch, instruction cache, data cache, wait state 5
  modifyReg regFLASH_ACR $ do
    setBit flash_acr_ic_en
    setBit flash_acr_dc_en
    setField flash_acr_latency (fromRep 5)

  -- Select main PLL as system clock source
  modifyReg regRCC_CFGR $ do
    setField rcc_cfgr_sw rcc_sysclk_pll

  -- Spin until main PLL is ready:
  --   while (RCC->CFGR SWS field != SW_PLL);
  forever $ do
    cfgr <- getReg regRCC_CFGR
    when ((cfgr #. rcc_cfgr_sws) ==? rcc_sysclk_pll) $ breakOut

  -- Set vector table location
  --   SCB->VTOR = (intptr_t)(&g_vectors[0])
  -- XXX is this actually needed? bootloader should have taken care of it. we
  -- didn't relocate it.



