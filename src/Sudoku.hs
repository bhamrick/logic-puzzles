{-# LANGUAGE TupleSections #-}

module Sudoku where

import Data.SBV hiding (constrain)
import Control.Monad.Writer
import Data.Map (Map, (!))
import Data.List (transpose)
import Data.Maybe (fromJust)

import Util

type SudokuInst = [[Maybe Integer]]

type Elem = SWord32
type Row = [Elem]
type Board = [Row]

type SudokuSoln = [[Integer]]

allPairs :: [a] -> [(a,a)]
allPairs [] = []
allPairs (x:xs) = map (x,) xs ++ allPairs xs

getSquares :: [[a]] -> [[a]]
getSquares xs =
    concat $ map (\i ->
        map (\j ->
            [
                (xs !! (3*i)) !! (3*j),
                (xs !! (3*i)) !! (3*j+1),
                (xs !! (3*i)) !! (3*j+2),
                (xs !! (3*i+1)) !! (3*j),
                (xs !! (3*i+1)) !! (3*j+1),
                (xs !! (3*i+1)) !! (3*j+2),
                (xs !! (3*i+2)) !! (3*j),
                (xs !! (3*i+2)) !! (3*j+1),
                (xs !! (3*i+2)) !! (3*j+2)
            ]
        ) [0..2]
    ) [0..2]

predicate :: SudokuInst -> Symbolic SBool
predicate inst = do
    board <-
        forM [0..8] $ \x ->
            forM [0..8] $ \y ->
                (symbolic (show x ++ "-" ++ show y) :: Symbolic SWord32)

    addConstraints $ do
        -- constraint to match input
        forM_ (zip inst board) $ \(instRow, boardRow) ->
            forM_ (zip instRow boardRow) $ \(instCell, var) ->
                do
                    case instCell of Nothing -> return ()
                                     Just x -> constrain $ var .== (literal (fromIntegral x))
                    constrain $ var .>= 0 &&& var .<= 8

        let constraint1Through9 vars = do
                -- for each `value`, at least one value in the {row,col,square} must be `value`
                forM_ [0..8] $ \value ->
                    constrain $
                        foldl (|||) (literal False) $ map (\var -> var .== literal value) vars
                -- none of the values are equal
                -- (technically redundant but I guess this will help the solver)
                forM_ (allPairs vars) $ \(v1, v2) -> constrain $ v1 ./= v2

        forM_ board $ \row ->
            constraint1Through9 row

        forM_ (transpose board) $ \col ->
            constraint1Through9 col

        forM_ (getSquares board) $ \sqr ->
            constraint1Through9 sqr

getSolution :: Map String CW -> SudokuSoln
getSolution m = map (\i ->
        map (\j ->
            fromIntegral $ (fromCW $ m ! (show i ++ "-" ++ show j) :: Word32)
        ) [0..8]
    ) [0..8]

solvePuzzle :: Symbolic SBool -> (Map String CW -> a) -> IO [a]
solvePuzzle prob fn = do
    res <- allSat prob
    return $ map fn (getModelDictionaries res)

sudoku :: SudokuInst -> IO ()
sudoku puzzle = do
    res <- solvePuzzle (predicate puzzle) getSolution
    putStrLn $ (show $ length res) ++ " solution(s)"
    forM_ res $ \soln ->
        putStrLn $ show $ map (concat . map (show . (+ 1))) soln