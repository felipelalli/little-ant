-- | Kernel-owned Allium conformance probes.
--
-- Registrations are keyed only by semantic module, category, and construct.
-- Each probe executes the real kernel behavior it claims; obligation IDs are
-- never inspected.
module LittleAnt.V1.PlanCatalog
  ( kernelPlanProbes
  ) where

import Control.Monad (unless)
import Data.Aeson (Object, ToJSON (toJSON), Value (String), encode)
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import LittleAnt.V1.Contract
  (PlanProbe, PlanProbeInput (..), ProbeKey (..))
import LittleAnt.V1.Kernel
  (AppendRequest (..), AppendResult (..), DomainRevision (..),
   EventBatch (..), EventEnvelope (..), KernelError (..), OpaqueId (..),
   ProposedEvent (..), ReplayResult (..), appendSemanticAction,
   emptyKernelState, kernelEntity, kernelEventBatches, kernelRevision,
   kernelValue, replayAll)

kernelPlanProbes :: Map ProbeKey PlanProbe
kernelPlanProbes = Map.fromList
  [ (ProbeKey "interaction" "contract_signature" "CanonicalEventStore.append",
      appendProbe)
  , (ProbeKey "interaction" "contract_signature" "CanonicalEventStore.replay",
      replayProbe)
  , (ProbeKey "root" "invariant" "GloballyOpaqueEntityIds", opaqueIdentityProbe)
  ]

appendProbe :: PlanProbe
appendProbe input = do
  checkMetadata "interaction" "contract_signature"
    "CanonicalEventStore.append" input
  accepted <- mapKernelError (appendSemanticAction multiEventRequest emptyKernelState)
  let next = appendResultState accepted
      batch = appendResultBatch accepted
      envelopes = eventBatchEvents batch
  require (kernelRevision next == DomainRevision 1)
    "accepted action did not advance the domain revision exactly once"
  require (length (kernelEventBatches next) == 1)
    "accepted action did not commit exactly one event batch"
  require (length envelopes == 2)
    "atomic event batch did not retain all proposed events"
  require (map eventIndexInAction envelopes == [0, 1])
    "event envelopes do not preserve action-local order"
  require (all ((== DomainRevision 1) . eventDomainRevision) envelopes)
    "events in one semantic action do not share its revision"
  require (kernelValue "first" next == Just (String "accepted"))
    "first event was not projected"
  require (kernelValue "second" next == Just (toJSON (2 :: Int)))
    "second event was not projected"
  case appendSemanticAction
      (multiEventRequest {appendExpectedRevision = DomainRevision 0}) next of
    Left (RevisionConflict (DomainRevision 0) (DomainRevision 1)) -> pure ()
    Left problem -> Left ("unexpected optimistic-append rejection: "
      <> Text.pack (show problem))
    Right _ -> Left "stale append unexpectedly succeeded"
  require (encode next == encode (appendResultState accepted))
    "rejected append mutated previously accepted state"

replayProbe :: PlanProbe
replayProbe input = do
  checkMetadata "interaction" "contract_signature"
    "CanonicalEventStore.replay" input
  first <- mapKernelError
    (appendSemanticAction multiEventRequest emptyKernelState)
  second <- mapKernelError (appendSemanticAction
    AppendRequest
      { appendExpectedRevision = DomainRevision 1
      , appendSemanticActionId = "probe:replay:second"
      , appendActorOrOrigin = "core:contract-probe"
      , appendOccurredAt = Just "2026-07-27T00:00:01Z"
      , appendProposedEvents = [ProposeValueRemoved "first"]
      }
    (appendResultState first))
  replayed <- mapKernelError
    (replayAll (kernelEventBatches (appendResultState second)))
  require (encode (replayResultState replayed)
      == encode (appendResultState second))
    "deterministic replay did not reconstruct byte-equivalent state"
  require (null (replayResultExternalTrace replayed))
    "canonical replay produced an external adapter trace"

opaqueIdentityProbe :: PlanProbe
opaqueIdentityProbe input = do
  checkMetadata "root" "invariant" "GloballyOpaqueEntityIds" input
  accepted <- mapKernelError (appendSemanticAction
    AppendRequest
      { appendExpectedRevision = DomainRevision 0
      , appendSemanticActionId = "probe:opaque-identities"
      , appendActorOrOrigin = "core:contract-probe"
      , appendOccurredAt = Nothing
      , appendProposedEvents =
          [ ProposeEntityCreated "brick" (objectFields "Repeated title")
          , ProposeEntityCreated "party" (objectFields "Repeated title")
          ]
      }
    emptyKernelState)
  case appendResultAllocatedIds accepted of
    [first@(OpaqueId firstText), second@(OpaqueId secondText)] -> do
      require (first /= second) "two creations reused one entity identity"
      require (not ("Repeated title" `Text.isInfixOf` firstText))
        "entity identity contains its display title"
      require (not ("Repeated title" `Text.isInfixOf` secondText))
        "entity identity contains its display title"
      require (kernelEntity first (appendResultState accepted) /= Nothing)
        "first allocated entity is absent after append"
      require (kernelEntity second (appendResultState accepted) /= Nothing)
        "second allocated entity is absent after append"
    identifiers -> Left ("identity probe allocated an unexpected number of IDs: "
      <> Text.pack (show identifiers))

multiEventRequest :: AppendRequest
multiEventRequest = AppendRequest
  { appendExpectedRevision = DomainRevision 0
  , appendSemanticActionId = "probe:append:atomic"
  , appendActorOrOrigin = "core:contract-probe"
  , appendOccurredAt = Just "2026-07-27T00:00:00Z"
  , appendProposedEvents =
      [ ProposeValueStored "first" (String "accepted")
      , ProposeValueStored "second" (toJSON (2 :: Int))
      ]
  }

objectFields :: Text -> Object
objectFields title = KeyMap.singleton "title" (String title)

checkMetadata :: Text -> Text -> Text -> PlanProbeInput -> Either Text ()
checkMetadata expectedModule expectedCategory expectedConstruct input = do
  require (planProbeModule input == expectedModule)
    "plan probe received the wrong module"
  require (planProbeCategory input == expectedCategory)
    "plan probe received the wrong category"
  require (planProbeSourceConstruct input == expectedConstruct)
    "plan probe received the wrong semantic construct"

require :: Bool -> Text -> Either Text ()
require condition problem = unless condition (Left problem)

mapKernelError :: Either KernelError value -> Either Text value
mapKernelError = either (Left . Text.pack . show) Right
