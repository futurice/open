{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Dashdo.Files where

import Data.FileEmbed
import qualified Data.ByteString.Lazy as BLS
import qualified Data.Text as T

dashdoJS :: BLS.ByteString
dashdoJS = BLS.fromStrict $(embedFile "public/js/dashdo.js")

dashdoJSrunnerBase :: BLS.ByteString
dashdoJSrunnerBase = BLS.fromStrict $(embedFile "public/js/runners/base.js")

dashdoJSrunnerRdash :: BLS.ByteString
dashdoJSrunnerRdash = BLS.fromStrict $(embedFile "public/js/runners/rdashdo.js")

runnersEmbedded :: [(T.Text, BLS.ByteString)]
runnersEmbedded =
    [ ("base.js", dashdoJSrunnerBase)
    , ("rdashdo.js", dashdoJSrunnerRdash)
    ]
