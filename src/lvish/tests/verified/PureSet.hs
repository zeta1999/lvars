{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds    #-}
{-# LANGUAGE Rank2Types   #-}

module Main where

import           Control.DeepSeq
import           Control.Monad.Trans
import qualified Data.ByteString.Lazy        as LBS
import           Data.Csv
import           Data.Int
import           Data.Word
import           GHC.Conc
import           System.Directory
import           System.Environment
import           System.IO.Unsafe
import qualified System.Random.PCG.Fast.Pure as PCG

import           Control.LVish
import           Control.LVish.Internal.Unsafe ()
import           Data.LVar.PureSet             (ISet)
import qualified Data.LVar.PureSet             as PS

import Data.VerifiedOrd.Instances

import           Utils (Measured (..))
import qualified Utils as U

type Det = 'Ef 'P 'G 'NF 'B 'NI

type Bench = IO [(Int, Measured)]

{-# NOINLINE fromSize #-}
fromSize :: Int64
fromSize = unsafePerformIO $ read <$> getEnv "FROMSIZE"

{-# NOINLINE toSize #-}
toSize :: Int64
toSize = unsafePerformIO $ read <$> getEnv "TOSIZE"

{-# NOINLINE seed #-}
seed :: Word64
seed = unsafePerformIO $ read <$> getEnv "SEED"

{-# NOINLINE range #-}
range :: Int64
range = unsafePerformIO $ read <$> getEnv "RANGE"

{-# NOINLINE iters #-}
iters :: Int64
iters = unsafePerformIO $ read <$> getEnv "ITERS"

{-# NOINLINE threads #-}
threads :: Int
threads = unsafePerformIO $ read <$> getEnv "THREADS"

{-# INLINE measure #-}
measure :: (MonadIO m, NFData a) => m a -> m Measured
measure f = do
  m <- U.measure iters f
  return (U.rescale m)

pureSetBench :: Bench
pureSetBench = do
  g <- PCG.restore (PCG.initFrozen seed)
  U.fori 1 threads $
    \t -> do
      setNumCapabilities t
      runParPolyIO $ do
        ps <- PS.newEmptySet :: Par Det s (ISet s Int64)
        U.for_ 0 fromSize $
          \_ -> do
            k <- liftIO (U.rand g range)
            PS.insert k ps
        measure $ U.for fromSize toSize $
          \_ -> do
            k <- liftIO (U.rand g range)
            PS.insert k ps

vPureSetBench :: Bench
vPureSetBench = do
  g <- PCG.restore (PCG.initFrozen seed)
  U.fori 1 threads $
    \t -> do
      setNumCapabilities t
      runParPolyIO $ do
        ps <- PS.newEmptySet :: Par Det s (ISet s Int64)
        U.for_ 0 fromSize $
          \_ -> do
            k <- liftIO (U.rand g range)
            PS.vinsert vordInt64 k ps
        measure $ U.for fromSize toSize $
          \_ -> do
            k <- liftIO (U.rand g range)
            PS.vinsert vordInt64 k ps

main :: IO ()
main = do
  !pureSetMeasures <- pureSetBench
  !vpureSetMeasures <- vPureSetBench
  createDirectoryIfMissing True "tests/verified/reports"
  LBS.writeFile "tests/verified/reports/pureset.csv" . encode $
    (\(t, m) -> (t, measTime m)) `fmap` pureSetMeasures
  LBS.writeFile "tests/verified/reports/vpureset.csv" . encode $
    (\(t, m) -> (t, measTime m)) `fmap` vpureSetMeasures