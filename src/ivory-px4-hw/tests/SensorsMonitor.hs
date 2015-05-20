{-# LANGUAGE DataKinds #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE OverloadedStrings #-}

import Data.List
import Ivory.Artifact
import qualified Ivory.Compile.C.CmdlineFrontend as C (compile)
import Ivory.Language

import SMACCMPilot.Hardware.SensorMonitor

puts :: Def('[IString]:-> Sint32)
puts = importProc "puts" "stdio.h"

main :: IO ()
main = C.compile modules artifacts'
  where
  (modules, artifacts) = decoder $ SensorHandlers
    { sh_baro   = const $ call_ puts "baro"
    , sh_mag    = const $ call_ puts "mag"
    , sh_gyro   = const $ call_ puts "gyro"
    , sh_accel  = const $ call_ puts "accel"
    , sh_gps    = const $ call_ puts "gps"
    , sh_moddef = incl puts
    }

  artifacts' = makefile : artifacts

  makefile = Root $ artifactString "Makefile" $ unlines [
      "CC = gcc",
      "CFLAGS = -Wall -O0 -g -I. -DIVORY_TEST",
      "LDLIBS = -lm",
      "OBJS = termios_helpers.o " ++ intercalate " " [ moduleName m ++ ".o" | m <- modules ], 
      "decoder: $(OBJS)",
      "clean:",
      "\t-rm -f $(OBJS)",
      ".PHONY: clean"
    ]
