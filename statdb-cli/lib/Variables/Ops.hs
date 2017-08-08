module Variables.Ops where

import Control.Monad.Reader (reader, liftIO)
import Data.IORef
import Variables.Env
import VariablesAPI

getVar :: Coq_var -> TheProc (IORef Integer)
getVar VarCount = reader varCount
getVar VarSum = reader varSum

read :: Coq_var -> TheProc Integer
read v = do
  ref <- getVar v
  liftIO $ readIORef ref

write :: Coq_var -> Integer -> TheProc ()
write v x = do
  ref <- getVar v
  liftIO $ writeIORef ref x
