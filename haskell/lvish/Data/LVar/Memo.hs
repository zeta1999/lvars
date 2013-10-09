{-# LANGUAGE ScopedTypeVariables, DataKinds #-}
{-# LANGUAGE KindSignatures, EmptyDataDecls #-}
{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -O2 #-}

{-|

In contrast with "Data.LVar.MemoBasic", this module provides..............

 -}

module Data.LVar.Memo
--       (Memo, MemoFuture, getLazy, getMemo, force) 
       where

import Data.Set (Set)
import Control.Monad
import qualified Data.Set as S

import Control.LVish
import qualified Control.LVish.Internal as LV
import qualified Control.LVish.SchedIdempotent as LI

import Data.IORef
import Data.LVar.PureSet as IS
import Data.LVar.IVar as IV
import qualified Data.Concurrent.SkipListMap as SLM
import qualified Data.Set as S

import qualified Data.LVar.SLMap as IM
-- import qualified Data.LVar.PureSet as S

import System.IO.Unsafe (unsafePerformIO)
import Debug.Trace

import qualified Control.Par.StateT as St

--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------

-- | Could use a more scalable structure here... but we need union as well as
-- elementwise insertion.
type SetAcc a = IORef (S.Set a)


newtype Memo (d::Determinism) s a b =
  -- Here we keep both a Ivars of return values, and a set of keys whose computations
  -- have traversed through THIS key.  If we see a cycle there, we can catch it.
  Memo (IM.IMap s a (SetAcc a, IVar s b)) 
--  Memo (IM.IMap s a (SLM.SLMap a (), IVar s b))

  -- We need a State transformer on the computations running inside the memo table to
  -- keep track of where they have come from and ADD that information to new
  -- `getMemo` requests that they make.

newtype MemoFuture (d :: Determinism) s b = MemoFuture (Par d s b)

-- | A Par-monad transformer for computations running inside a memo table.
type MemoT key par det s a = par det s a
-- ParStateT par det s a  

-- | Lift @Par@ computations into a memoized function.
liftMemo :: p d s a -> MemoT key p d s a
liftMemo = undefined

--------------------------------------------------------------------------------

{-

-- | Reify a function in the `Par` monad as an explicit memoization table.
makeMemo :: (Ord a, Eq b) => (a -> Par d s b) -> Par d s (Memo d s a b)
makeMemo fn = do
  st <- newEmptySet
  mp <- IM.newEmptyMap
  IS.forEach st $ \ elm -> do
    res <- fn elm
    IM.insert elm res mp
  return $! Memo st mp
-- TODO: this version may want to have access to the memo-table within the handler as
-- well....

-- | Read from the memo-table.  If the value must be computed, do that right away and
-- block until its complete.
getMemo :: (Ord a, Eq b) => Memo d s a b -> a -> Par d s b 
getMemo tab key =
  do fut <- getLazy tab key
     force fut

-- | Begin to read from the memo-table.  Initiate the computation if the key is not
-- already present.  Don't block on the computation being complete, rather, return a
-- future.
getLazy :: (Ord a, Eq b) => Memo d s a b -> a -> Par d s (MemoFuture d s b)
getLazy (Memo st mp) key = do 
  IS.insert key st
  return $! MemoFuture (IM.getKey key mp)


-- | This will throw exceptions that were raised during the computation, INCLUDING
-- multiple put.
force :: MemoFuture d s b -> Par d s b 
force (MemoFuture pr) = pr
-- FIXME!!! Where do errors in the memoized function (e.g. multiple put) surface?
-- We must pick a determined, consistent place.
-- 
-- Multiple put errors may not be able to wait until this point to get
-- thrown.  Otherwise we'd have to be at least quasideterministic here.  If you have
-- a MemoFuture you never force, it and an outside computation may be racing to do a
-- put.  If the outside one wins the MemoFuture is the one that gets the exception
-- (and hides it), otherwise the exception is exposed.  Quasideterminism.

-- It may be fair to distinguish between internal problems with the MemoFuture
-- (deferred exceptions), and problematic interactions with the outside world (double
-- put) which would then not be deferred.  Such futures can't be canceled anyway, so
-- there's really no need to defer the exceptions.


-}

--------------------------------------------------------------------------------
-- Cycle-detecting memoized computations
--------------------------------------------------------------------------------

-- | A private type for keeping track of which keys we have gone through to get where
-- we are.
newtype RememberSet key = RememberSet (S.Set key)

--  A Par-monad transformer that adds the cycle-detection capability.
-- 
-- newtype MemoCycT (d::Determinism) s key par res = MemoCycT ()
--
-- UH OH, we need generic version of set, map, and maybe 's' param operations to be
-- able to make this a general transformer I think....

-- | The LVish Par monad extended with the capability to detect cycles in memoized
-- computations.
newtype MemoCycT (d::Determinism) s key res = MemoCycT ()


-- data Response par key ans =
--     Done ans
--   | Continue [key] ([ans] -> par (Response par key ans))

data RequestResponse par key ans =
    Response ans
  | Request [key] ([ans] -> par (Response par key ans))


-- -- | Chase recursive calls through an (new, implicit) Memo table until reaching a
-- -- cycle.  Return the final value resulting from the initial request/response as well
-- -- as a `Memo` containing all the intermediate results that were computed in the
-- -- process.
-- fixedPoint :: (Ord k, Eq v) => RequestResponse (Par d s) k v -> Par d s (v, Memo d s k v)
-- fixedPoint = undefined


-- | Make a Memo table with the added capability that any cycles in requests will be
-- detected.  A special cycle-handler determines what result is returned when a cycle
-- is detected starting at a given key.
--
-- The result of this function Memo-table returns 
makeFixedPointMemo :: (Ord k, Eq v) =>
                      RequestResponse (Par d s) k v
                      -> (k -> Par d s v)
                      -> Par d s (v, Memo d s k v)
makeFixedPointMemo = undefined


{-


-- | This version watches for, and catches, cyclic requests to the memotable that
-- would normally diverge.  Once caught, the user specifies what to do with these
-- cycles by providing a handler.  The handler is called on the key which formed the
-- cycle.  That is, computing the invocation spawned by that key results in a demand
-- for that key.  
makeMemoCyclic :: (MemoTable d s a b -> a -> Par d s b) -> (a -> Par d s b) -> Par d s (MemoTable d s a b)
makeMemoCyclic normalFn ifCycle  = undefined
-- FIXME: Are there races where more than one cycle can be hit?  Can we guarantee
-- that all are hit?  



-- | Cancel an outstanding speculative computation.  This recursively attempts to
-- cancel any downstream computations in this or other memo-tables that are children
-- of the given `MemoFuture`.
cancel :: MemoFuture Det s b -> Par Det s ()
-- FIXME: Det needs to be replaced here with "GetOnly".
cancel fut = undefined

-}
