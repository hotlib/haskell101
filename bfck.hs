{-# LANGUAGE RecordWildCards, FlexibleContexts #-}

import Text.Parsec.Pos
import Text.Parsec
import Data.List 
import Safe
import System.Environment
import Control.Applicative

data Token = LeftBracket
           | RightBracket 
           | Plus
	   | Minus
           | LeftShift
	   | RightShift
           | Print
	   | Input
	   deriving (Show, Eq)

data Tree = Op Token Tree
          | Loop Tree Tree
	  | End
          deriving (Show, Eq) 

data Memory = Memory { memRight :: [Int], memLeft :: [Int], current :: Int }

newMem :: Memory
newMem = let memRight = [0,0 ..] 
	     memLeft = [0,0 ..] 
             current = 0
	  in Memory {..}

memValue :: Memory -> Int
memValue Memory{..} = current 

moveLeft :: Memory -> Memory
moveLeft Memory{..} = Memory (current : memRight) (tail memLeft) (head memLeft)   

moveRight :: Memory -> Memory
moveRight Memory{..} = Memory (tail memRight) (current : memLeft) (head memRight)   

modifyMem :: Int -> Memory -> Memory
modifyMem i Memory{..} = Memory memRight memLeft (current + i)

incMem :: Memory -> Memory
incMem = modifyMem 1 

decMem :: Memory -> Memory
decMem = modifyMem (-1) 

printMem :: Memory -> IO ()
printMem Memory{..} = print current

readMem :: Memory -> IO Memory
readMem m = do 
             print "pretend iam reading"
	     return m 

main :: IO ()
main = do
	bfckSource <- head <$> getArgs
        let (Right x) = parse (many1 tokenizer) "" bfckSource
        _ <- eval (buildTree x) newMem	
        return ()

buildTree :: [Token] -> Tree
buildTree [] = End
buildTree ts@(LeftBracket : _) = let (firstPart, restPart) = mySplit 
					 in Loop (buildTree $ tailSafe firstPart) (buildTree $ tailSafe restPart)   
    where
      mySplit = splitAt (snd bracketTuple) ts
      bracketTuple = head . filter (\x -> fst x == 0) $ bracketIndices ts      

buildTree (x : rest) = Op x $ buildTree rest  

matchIndices :: [Int] -> [Int] -> [(Int, Int)]
matchIndices ls = foldl match []  
    where
      match acc r = (leftBracketIndex acc r, r) : acc
      leftBracketIndex acc r = index r (map fst acc) 
      index r used = maximum $ filter (\x -> x < r && x `notElem` used) ls  
  	      

bracketIndices :: [Token] -> [(Int,Int)]
bracketIndices ts 
          | length leftIndices == length rightIndices = matchIndices leftIndices rightIndices
	  | otherwise = error "mismatch in brackets [ ]" 
   where 
      leftIndices =  elemIndices LeftBracket ts
      rightIndices = elemIndices RightBracket ts


recognise :: Char -> Maybe Token
recognise c 
       | c == '+' = Just Plus
       | c == '-' = Just Minus
       | c == '<' = Just LeftShift
       | c == '>' = Just RightShift
       | c == '.' = Just Print
       | c == ',' = Just Input
       | c == '[' = Just LeftBracket
       | c == ']' = Just RightBracket
       | otherwise = error "unsupported character"

satisfy2 :: (Stream s m Char) => (Char -> Maybe Token) -> ParsecT s u m Token
satisfy2 = tokenPrim 
               (\c -> show [c])
               (\pos c _cs -> updatePosChar pos c)
	      

tokenizer :: (Stream s m Char) => ParsecT s u m Token
tokenizer = satisfy2 recognise


eval :: Tree -> Memory -> IO Memory 
eval End m = return m 
eval (Op Plus x) m = eval x (incMem m) 
eval (Op Minus x) m = eval x (decMem m) 
eval (Op Print x) m = printMem m >> eval x m
eval (Op Input x) m = readMem m >> eval x m 
eval (Op LeftShift x) m = eval x (moveLeft m) 
eval (Op RightShift x) m = eval x (moveRight m) 
eval loop@(Loop l r) m = if memValue m == 0 then eval r m 
                         else                   eval l m >>= eval loop
eval _ _ = error "unsupported node in parsing tree"			 
