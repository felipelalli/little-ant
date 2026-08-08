module LittleAnt.Forecast (
  CorrelationKey (..),
  DrawCandidate (..),
  DrawRecord (..),
  ForecastCandidate (..),
  ForecastFactors (..),
  ForecastProfile (..),
  ForecastSignal (..),
  WeightedCandidate (..),
  factoryForecastProfile,
  fixedOne,
  forecastWeight,
  importanceFactor,
  positivePressure,
  sampleRecorded,
  sampleWithInteger,
)
where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.Bits (shiftL, shiftR)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import LittleAnt.Foundation
import LittleAnt.Model

fixedOne :: Fixed
fixedOne = Fixed 1_000_000

data CorrelationKey
  = AvailabilitySignal
  | AgeSignal
  | DateSignal
  | AvoidanceSignal
  | UncertaintySignal
  | PhaseSignal
  | ImpactSignal
  | PlaceSignal
  | WipSignal
  | ScheduleSignal
  | ReviewConsequenceSignal
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ForecastSignal = ForecastSignal
  { signalKey :: CorrelationKey
  , signalStrength :: Fixed
  , signalExplanation :: Text
  }
  deriving stock (Eq, Show)

data ForecastProfile = ForecastProfile
  { profileHash :: Text
  , importanceBottom :: Fixed
  , importanceNeutral :: Fixed
  , importanceExponent :: Int
  , pressureAdditionalFraction :: Fixed
  , pressureGain :: Fixed
  , domainGain :: Fixed
  , familyGain :: Fixed
  , fatigueMaximumReduction :: Fixed
  }
  deriving stock (Eq, Show)

factoryForecastProfile :: ForecastProfile
factoryForecastProfile =
  ForecastProfile
    { profileHash = "little-ant-forecast-v1-factory"
    , importanceBottom = Fixed 50_000
    , importanceNeutral = Fixed 350_000
    , importanceExponent = 2
    , pressureAdditionalFraction = Fixed 350_000
    , pressureGain = Fixed 2_000_000
    , domainGain = Fixed 750_000
    , familyGain = Fixed 500_000
    , fatigueMaximumReduction = Fixed 750_000
    }

data ForecastFactors = ForecastFactors
  { factorSiblingPosition :: Maybe (Int, Int)
  , factorImportanceConfidence :: Fixed
  , factorPositiveSignals :: [ForecastSignal]
  , factorDomainAffinity :: Fixed
  , factorFamilyAffinity :: Fixed
  , factorNegativeSignals :: [ForecastSignal]
  }
  deriving stock (Eq, Show)

data ForecastCandidate subject = ForecastCandidate
  { forecastIdentity :: Text
  , forecastSubject :: subject
  , forecastFactors :: ForecastFactors
  }
  deriving stock (Eq, Show)

data WeightedCandidate subject = WeightedCandidate
  { weightedIdentity :: Text
  , weightedSubject :: subject
  , weightedInteger :: Integer
  , weightedImportance :: Fixed
  , weightedPressure :: Fixed
  , weightedDomain :: Fixed
  , weightedFamily :: Fixed
  , weightedNegative :: Fixed
  , weightedStrongestSignal :: Maybe ForecastSignal
  , weightedAdditionalSignals :: [ForecastSignal]
  }
  deriving stock (Eq, Show)

data DrawCandidate subject = DrawCandidate
  { drawCandidateIdentity :: Text
  , drawCandidateSubject :: subject
  , drawCandidateWeight :: Integer
  , drawCandidateIntervalStart :: Integer
  , drawCandidateIntervalEnd :: Integer
  }
  deriving stock (Eq, Show)

data DrawRecord subject = DrawRecord
  { drawPurpose :: RandomPurpose
  , drawProfileHash :: Text
  , drawCandidates :: [DrawCandidate subject]
  , drawTotal :: Integer
  , drawStartingCursor :: Integer
  , drawEndingCursor :: Integer
  , drawSampledInteger :: Integer
  , drawChosenIdentity :: Text
  , drawChosenSubject :: subject
  }
  deriving stock (Eq, Show)

importanceFactor :: ForecastProfile -> Maybe (Int, Int) -> Fixed -> Fixed
importanceFactor profile placement confidence =
  case placement of
    Nothing -> importanceNeutral profile
    Just (_, count) | count <= 1 -> fixedOne
    Just (position, count) ->
      let denominator = fromIntegral (count - 1)
          clampedPosition = max 0 (min (count - 1) position)
          rank = Fixed (fromIntegral clampedPosition * 1_000_000 `div` denominator)
          inverse = fixedSub fixedOne rank
          ranked =
            fixedAdd
              (importanceBottom profile)
              ( fixedMul
                  (fixedSub fixedOne (importanceBottom profile))
                  (fixedPow inverse (importanceExponent profile))
              )
       in fixedAdd
            (importanceNeutral profile)
            (fixedMul (clampRatio confidence) (fixedSubSigned ranked (importanceNeutral profile)))

positivePressure :: ForecastProfile -> [ForecastSignal] -> (Fixed, Maybe ForecastSignal, [ForecastSignal])
positivePressure profile signals =
  case ordered of
    [] -> (Fixed 0, Nothing, [])
    strongest : extras ->
      let extra = fixedSub fixedOne (foldl' fixedMul fixedOne (fmap (fixedSub fixedOne . signalStrength) extras))
          bounded =
            fixedMul
              (pressureAdditionalFraction profile)
              (fixedMul (fixedSub fixedOne (signalStrength strongest)) extra)
       in (fixedAdd (signalStrength strongest) bounded, Just strongest, extras)
 where
  consolidated =
    Map.elems $
      Map.fromListWith
        stronger
        [(signalKey signal, signal{signalStrength = clampRatio (signalStrength signal)}) | signal <- signals]
  stronger left right
    | signalStrength left > signalStrength right = left
    | signalStrength right > signalStrength left = right
    | signalExplanation left <= signalExplanation right = left
    | otherwise = right
  ordered = reverse (sortOn (\signal -> (signalStrength signal, signalKey signal, signalExplanation signal)) consolidated)

forecastWeight :: ForecastProfile -> ForecastCandidate subject -> WeightedCandidate subject
forecastWeight profile candidate =
  let factors = forecastFactors candidate
      importance = importanceFactor profile (factorSiblingPosition factors) (factorImportanceConfidence factors)
      (pressure, strongest, extras) = positivePressure profile (factorPositiveSignals factors)
      pressureFactor = fixedAdd fixedOne (fixedMul (pressureGain profile) pressure)
      domainFactor = fixedAdd fixedOne (fixedMul (domainGain profile) (clampRatio (factorDomainAffinity factors)))
      familyFactor = fixedAdd fixedOne (fixedMul (familyGain profile) (clampRatio (factorFamilyAffinity factors)))
      combinedNegative = combineNegative (factorNegativeSignals factors)
      negativeFactor = fixedSub fixedOne (fixedMul (fatigueMaximumReduction profile) combinedNegative)
      result =
        foldl'
          fixedMul
          importance
          [pressureFactor, domainFactor, familyFactor, negativeFactor]
   in WeightedCandidate
        { weightedIdentity = forecastIdentity candidate
        , weightedSubject = forecastSubject candidate
        , weightedInteger = max 1 (unFixed result)
        , weightedImportance = importance
        , weightedPressure = pressure
        , weightedDomain = domainFactor
        , weightedFamily = familyFactor
        , weightedNegative = negativeFactor
        , weightedStrongestSignal = strongest
        , weightedAdditionalSignals = extras
        }

sampleWithInteger :: ForecastProfile -> RandomPurpose -> Integer -> [WeightedCandidate subject] -> Either Text (DrawRecord subject)
sampleWithInteger profile purpose sampled weighted
  | null weighted = Left "A weighted draw needs at least one admitted candidate."
  | sampled < 0 || sampled >= total = Left "The supplied sample is outside the weighted interval."
  | otherwise =
      case filter contains candidates of
        selected : _ ->
          Right
            DrawRecord
              { drawPurpose = purpose
              , drawProfileHash = profileHash profile
              , drawCandidates = candidates
              , drawTotal = total
              , drawStartingCursor = 0
              , drawEndingCursor = 0
              , drawSampledInteger = sampled
              , drawChosenIdentity = drawCandidateIdentity selected
              , drawChosenSubject = drawCandidateSubject selected
              }
        [] -> Left "The weighted intervals are corrupt."
 where
  canonical = sortOn weightedIdentity weighted
  total = sum (fmap weightedInteger canonical)
  candidates = snd (foldl' interval (0, []) canonical)
  interval (start, built) item =
    let end = start + weightedInteger item
        candidate = DrawCandidate (weightedIdentity item) (weightedSubject item) (weightedInteger item) start end
     in (end, built <> [candidate])
  contains candidate = sampled >= drawCandidateIntervalStart candidate && sampled < drawCandidateIntervalEnd candidate

sampleRecorded :: ForecastProfile -> ByteString -> Integer -> RandomPurpose -> [WeightedCandidate subject] -> Either Text (DrawRecord subject)
sampleRecorded profile seed cursor purpose weighted
  | ByteString.length seed /= 32 = Left "A forecast seed must contain exactly 32 bytes."
  | null weighted = Left "A weighted draw needs at least one admitted candidate."
  | total == 1 = withCursor cursor cursor 0 <$> sampleWithInteger profile purpose 0 canonical
  | otherwise = do
      (sampled, ending) <- uniform cursor
      withCursor cursor ending sampled <$> sampleWithInteger profile purpose sampled canonical
 where
  canonical = sortOn weightedIdentity weighted
  total = sum (fmap weightedInteger canonical)
  bitLength value
    | value <= 0 = 0
    | otherwise = 1 + bitLength (value `div` 2)
  bits = bitLength (total - 1)
  blockCount = (bits + 255) `div` 256
  uniform current =
    let blocks = [randomBlock seed purpose (current + offset) | offset <- [0 .. fromIntegral blockCount - 1]]
        raw = bytesInteger (ByteString.concat blocks)
        availableBits = 256 * blockCount
        value = raw `shiftR` (availableBits - bits)
        limit = ((1 `shiftL` bits) `div` total) * total
        next = current + fromIntegral blockCount
     in if value < limit then Right (value `mod` total, next) else uniform next
  withCursor start end sampled record =
    record{drawStartingCursor = start, drawEndingCursor = end, drawSampledInteger = sampled}

combineNegative :: [ForecastSignal] -> Fixed
combineNegative signals =
  fixedSub fixedOne (foldl' fixedMul fixedOne (fmap (fixedSub fixedOne . signalStrength) consolidated))
 where
  consolidated =
    Map.elems $
      Map.fromListWith
        (\left right -> if signalStrength left >= signalStrength right then left else right)
        [(signalKey signal, signal{signalStrength = clampRatio (signalStrength signal)}) | signal <- signals]

randomBlock :: ByteString -> RandomPurpose -> Integer -> ByteString
randomBlock seed purpose cursor =
  SHA256.hash
    ( "little-ant/random/v1"
        <> ByteString.singleton (fromIntegral (ByteString.length purposeBytes))
        <> purposeBytes
        <> seed
        <> integerBytes 16 cursor
    )
 where
  purposeBytes = Text.encodeUtf8 (randomPurposeName purpose)

integerBytes :: Int -> Integer -> ByteString
integerBytes width value =
  ByteString.pack
    [ fromIntegral ((value `shiftR` (8 * offset)) `mod` 256)
    | index <- [0 .. width - 1]
    , let offset = width - index - 1
    ]

bytesInteger :: ByteString -> Integer
bytesInteger = ByteString.foldl' (\accumulator byte -> accumulator * 256 + fromIntegral byte) 0

fixedAdd :: Fixed -> Fixed -> Fixed
fixedAdd (Fixed left) (Fixed right) = Fixed (left + right)

fixedSub :: Fixed -> Fixed -> Fixed
fixedSub (Fixed left) (Fixed right) = Fixed (max 0 (left - right))

fixedSubSigned :: Fixed -> Fixed -> Fixed
fixedSubSigned (Fixed left) (Fixed right) = Fixed (left - right)

fixedMul :: Fixed -> Fixed -> Fixed
fixedMul (Fixed left) (Fixed right) =
  let productValue = left * right
      magnitude = (abs productValue + 500_000) `div` 1_000_000
   in Fixed (if productValue < 0 then negate magnitude else magnitude)

fixedPow :: Fixed -> Int -> Fixed
fixedPow value power = foldl' fixedMul fixedOne (replicate (max 0 power) value)

clampRatio :: Fixed -> Fixed
clampRatio (Fixed value) = Fixed (max 0 (min 1_000_000 value))
