{-# LANGUAGE DeriveGeneric, OverloadedStrings #-}

{-|

The classical Iris dataset, due to R.A. Fisher.

UCI ML Repository link <https://archive.ics.uci.edu/ml/datasets/Iris>

-}

module Numeric.Dataset.Iris where

import Numeric.Dataset.UCI

import Data.Csv
import GHC.Generics

data IrisClass = Setosa | Versicolor | Virginica
  deriving (Show, Read, Eq, Generic)

instance FromField IrisClass where
  parseField "Iris-setosa" = pure Setosa
  parseField "Iris-versicolor" = pure Versicolor
  parseField "Iris-virginica" = pure Virginica
  parseField _ = fail "unknown iris class"

data Iris = Iris
  { sepalLength :: Double
  , sepalWidth :: Double
  , petalLength :: Double
  , petalWidth :: Double
  , irisClass :: IrisClass
  } deriving (Show, Read, Generic)

instance FromRecord Iris

iris :: Dataset Iris
iris = csvDataset "http://archive.ics.uci.edu/ml/machine-learning-databases/iris/iris.data"
