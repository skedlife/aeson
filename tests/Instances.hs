{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Instances () where

import Prelude.Compat

import Control.Applicative (empty)
import Control.Monad
import Data.Maybe (mapMaybe)
import Data.AesonAlt.Types
import Data.Function (on)
import Data.Time (ZonedTime(..), TimeZone(..))
import Data.Time.Clock (UTCTime(..))
import Functions
import Test.QuickCheck (Arbitrary(..), elements, oneof)
import Types
import qualified Data.DList as DList
import qualified Data.HashMap.Strict as HM
import qualified Network.URI as URI

import Data.Orphans ()
import Test.QuickCheck.Instances ()

-- "System" types.

instance Arbitrary DotNetTime where
    arbitrary = DotNetTime `fmap` arbitrary
    shrink = map DotNetTime . shrink . fromDotNetTime

-- | Compare timezone part only on 'timeZoneMinutes'
instance Eq ZonedTime where
  ZonedTime a (TimeZone a' _ _) == ZonedTime b (TimeZone b' _ _) =
    a == b && a' == b'

-- Compare equality to within a millisecond, allowing for rounding
-- error (ECMA 262 requires milliseconds to rounded to zero, not
-- rounded to nearest).
instance ApproxEq UTCTime where
    a =~ b = ((==) `on` utctDay) a b &&
             (approxEqWith 1 1 `on` ((* 1e3) . utctDayTime)) a b

instance ApproxEq DotNetTime where
    (=~) = (=~) `on` fromDotNetTime

instance ApproxEq Float where
    a =~ b
      | isNaN a && isNaN b = True
      | otherwise          = approxEq a b

instance ApproxEq Double where
    a =~ b
      | isNaN a && isNaN b = True
      | otherwise          = approxEq a b

instance (ApproxEq k, Eq v) => ApproxEq (HM.HashMap k v) where
    a =~ b = and $ zipWith eq (HM.toList a) (HM.toList b)
      where
        eq (x,y) (u,v) = x =~ u && y == v

-- Test-related types.

instance Arbitrary Foo where
    arbitrary = liftM4 Foo arbitrary arbitrary arbitrary arbitrary

instance Eq Foo where
    a == b = fooInt a == fooInt b &&
             fooDouble a `approxEq` fooDouble b &&
             fooTuple a == fooTuple b

instance ToJSON Foo where
    toJSON Foo{..} = object [ "fooInt" .= fooInt
                            , "fooDouble" .= fooDouble
                            , "fooTuple" .= fooTuple
                            , "fooMap" .= fooMap
                            ]

instance FromJSON Foo where
    parseJSON (Object v) = Foo <$>
                           v .: "fooInt" <*>
                           v .: "fooDouble" <*>
                           v .: "fooTuple" <*>
                           v .: "fooMap"
    parseJSON _ = empty

instance Arbitrary UFoo where
    arbitrary = UFoo <$> arbitrary <*> arbitrary
        where _ = uFooInt

instance Arbitrary OneConstructor where
    arbitrary = return OneConstructor

instance FromJSON OneConstructor
instance ToJSON OneConstructor

instance (Arbitrary a, Arbitrary b) => Arbitrary (Product2 a b) where
    arbitrary = liftM2 Product2 arbitrary arbitrary

instance (FromJSON a, FromJSON b) => FromJSON (Product2 a b)
instance (ToJSON a, ToJSON b) => ToJSON (Product2 a b)

instance (Arbitrary a, Arbitrary b, Arbitrary c, Arbitrary d, Arbitrary e,
          Arbitrary f) => Arbitrary (Product6 a b c d e f) where
    arbitrary = Product6 <$> arbitrary <*> arbitrary <*> arbitrary <*>
                             arbitrary <*> arbitrary <*> arbitrary

instance (FromJSON a, FromJSON b, FromJSON c, FromJSON d, FromJSON e,
          FromJSON f) => FromJSON (Product6 a b c d e f)
instance (ToJSON a, ToJSON b, ToJSON c, ToJSON d, ToJSON e,
          ToJSON f) => ToJSON (Product6 a b c d e f)

instance (Arbitrary a, Arbitrary b, Arbitrary c, Arbitrary d)
    => Arbitrary (Sum4 a b c d) where
    arbitrary = oneof [Alt1 <$> arbitrary, Alt2 <$> arbitrary,
                       Alt3 <$> arbitrary, Alt4 <$> arbitrary]

instance (FromJSON a, FromJSON b, FromJSON c, FromJSON d)
    => FromJSON (Sum4 a b c d)
instance (ToJSON a, ToJSON b, ToJSON c, ToJSON d) => ToJSON (Sum4 a b c d)

instance (Arbitrary a) => Arbitrary (Approx a) where
    arbitrary = Approx <$> arbitrary

instance (FromJSON a) => FromJSON (Approx a) where
    parseJSON a = Approx <$> parseJSON a

instance (ToJSON a) => ToJSON (Approx a) where
    toJSON = toJSON . fromApprox

instance Arbitrary Nullary where
    arbitrary = elements [C1, C2, C3]

instance Arbitrary a => Arbitrary (SomeType a) where
    arbitrary = oneof [ pure Nullary
                      , Unary   <$> arbitrary
                      , Product <$> arbitrary <*> arbitrary <*> arbitrary
                      , Record  <$> arbitrary <*> arbitrary <*> arbitrary
                      , List    <$> arbitrary
                      ]

instance Arbitrary EitherTextInt where
    arbitrary = oneof
        [ LeftBool <$> arbitrary
        , RightInt <$> arbitrary
        , BothTextInt <$> arbitrary <*> arbitrary
        , pure NoneNullary
        ]

instance Arbitrary (GADT String) where
    arbitrary = GADT <$> arbitrary

#if !MIN_VERSION_base(4,16,0)
instance Arbitrary OptionField where
    arbitrary = OptionField <$> arbitrary
#endif


instance ApproxEq Char where
    (=~) = (==)

instance (ApproxEq a) => ApproxEq [a] where
    a =~ b = length a == length b && all (uncurry (=~)) (zip a b)

instance Arbitrary a => Arbitrary (DList.DList a) where
    arbitrary = DList.fromList <$> arbitrary

instance Arbitrary URI.URI where
    arbitrary = elements $ mapMaybe URI.parseURI
        [ "https://haskell.org"
        , "foo://anonymous@www.haskell.org:42/ghc?query#frag"
        ]
