module LittleAnt.JudgmentUI (
  makeEffortClassEnvelope,
  makeEffortExemplarEnvelope,
  makeEffortContradictionEnvelope,
  makeEffortNarrowedEnvelope,
  makeEffortProposalEnvelope,
  makeImpactBasisEnvelope,
  makeImpactClassEnvelope,
  makeImpactComparisonEnvelope,
  makeImpactContradictionEnvelope,
  makeImpactEvidenceEnvelope,
  makeImpactMaturityEnvelope,
  makeImpactMaturityPreviewEnvelope,
  makeImportanceAidEnvelope,
  makeImportanceContradictionEnvelope,
  makeImportanceDirectionEnvelope,
  makeImportanceDiscoveryEnvelope,
  makeImportanceEitherEnvelope,
  makeImportanceProvisionalEnvelope,
  makeImportanceReviewEnvelope,
  makeJudgmentContradictionAidEnvelope,
  makeJudgmentResultEnvelope,
  makeOrderResultEnvelope,
  makeOrderScopeEnvelope,
  makePhaseEnvelope,
)
where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
import LittleAnt.Id
import LittleAnt.Interaction
import LittleAnt.Judgment (effortPlanningHours)
import LittleAnt.Model
import LittleAnt.Store

makeOrderScopeEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> InteractionEnvelope
makeOrderScopeEnvelope identity cursor precondition now state =
  newEnvelope
    identity
    cursor
    precondition
    now
    state
    ChoiceGrammar
    OrderScopeOpportunity
    (EnvelopeContent "Order what?" Nothing [] Nothing)
    ( [ Action "order.all" ("all groups    " <> scopeCounts state Nothing) "a" True "Review every unresolved sibling group."
      ]
        <> currentGroup
        <> [ Action "order.pick" "pick a Brick or Domain..." "p" False "Choose one sibling group or Domain."
           , assistance "order.scope-assistance" "Explain the available ordering scopes."
           , more
           ]
    )
    (commands Nothing)
    (Just "choose_order_scope")
    (baseFooter now state)
 where
  currentGroup = case currentParent state of
    Nothing -> []
    Just parent -> [Action "order.current" ("current group    " <> scopeCounts state (Just parent)) "c" False "Review the current sibling group."]

makeImportanceReviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> UUIDv7 -> UUIDv7 -> Int -> [UUIDv7] -> Bool -> InteractionEnvelope
makeImportanceReviewEnvelope previous now state session first second skips skipped provocative =
  nextEnvelope
    previous
    now
    state
    ComparisonGrammar
    (ImportanceReviewOpportunity session first second skips skipped provocative)
    ( EnvelopeContent
        "Is"
        (Just (citation state first))
        ["", "    more important than", "", citation state second]
        (Just "?")
    )
    [ Action "importance.more" "more important" "m" False "Record that the first Brick is more important."
    , Action "importance.less" "less important" "l" False "Record that the second Brick is more important."
    , Action "importance.skip" "skip" "s" False "Try one bounded nearby comparison or keep the current order."
    , assistance "importance.assistance" "Use the bounded importance-discovery tree."
    , more
    ]
    (CommandOption "tie-break" "/tie-break" "Choose a deterministic provisional direction" : commands (Just first))
    (Just "discover_importance")
    (brickFooter now state first "Ordered")

makeImportanceContradictionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> UUIDv7 -> UUIDv7 -> [UUIDv7] -> InteractionEnvelope
makeImportanceContradictionEnvelope previous now state session first second path =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (ImportanceContradictionOpportunity session first second path)
    ( EnvelopeContent
        "Contradiction detected:"
        Nothing
        (fmap (judgmentLine state) path <> ["", "Just now", citation state first <> " was more important than " <> citation state second])
        (Just "What happened?")
    )
    [ Action "contradiction.changed" "changed    The new judgment is current; stop using the conflicting path." "c" False "Retire the conflicting path and accept the new direction."
    , Action "contradiction.mistake" "mistake    Record the reverse direction instead." "m" False "Retract the proposed direction and record its reverse."
    , assistance "contradiction.aid" "Compare a bounded triad."
    , more
    ]
    (commands (Just first))
    (Just "resolve_contradiction")
    (brickFooter now state first "Last reviewed")

makeImportanceAidEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> [UUIDv7] -> InteractionEnvelope
makeImportanceAidEnvelope previous now state session triad =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (ImportanceContradictionAidOpportunity session triad)
    (EnvelopeContent "Let's untangle this:" Nothing ["If only one of these could ever be done, which one should it be?"] Nothing)
    ( zipWith winner ["a", "b", "c"] triad
        <> [Action "contradiction.unresolved" "I still don't know" "?" False "Keep the last coherent order and review the segment later.", more]
    )
    (commands (safeHead triad))
    (Just "resolve_three_way_contradiction")
    (maybe (baseFooter now state) (\identity -> brickFooter now state identity "Last reviewed") (safeHead triad))
 where
  winner shortcut identity = Action ("contradiction.winner." <> renderUUIDv7 identity) (citation state identity) shortcut False "Make this Brick the winner against the other displayed Bricks."

makeImportanceDiscoveryEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> UUIDv7 -> UUIDv7 -> ImportanceDiscoveryNode -> Bool -> InteractionEnvelope
makeImportanceDiscoveryEnvelope previous now state session first second node alternate =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (ImportanceDiscoveryOpportunity session first second node alternate)
    (EnvelopeContent "Importance" Nothing [citation state first, citation state second, ""] (Just (importanceDiscoveryQuestion state first second node alternate)))
    [ Action "importance.discovery.yes" "yes" "y" False "Follow the yes branch."
    , Action "importance.discovery.no" "no" "n" False "Follow the no branch."
    , assistance "importance.discovery.unknown" "Use the node-specific uncertainty branch."
    , more
    ]
    (commands (Just first))
    (Just "bounded_importance_discovery")
    (brickFooter now state first "Ordered")

makeImportanceDirectionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> UUIDv7 -> UUIDv7 -> InteractionEnvelope
makeImportanceDirectionEnvelope previous now state session first second =
  confirmation
    previous
    now
    state
    (ImportanceDirectionConfirmationOpportunity session first second)
    "Importance judgment:"
    [citation state first, "", "    is more important than", "", citation state second, "", "Because, if only one could ever be completed, you chose " <> shortCitation state first <> "."]
    "Record this judgment?"
    "importance.direction.accept"
    "importance.direction.reject"
    first

makeImportanceEitherEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> UUIDv7 -> UUIDv7 -> InteractionEnvelope
makeImportanceEitherEnvelope previous now state session first second =
  confirmation
    previous
    now
    state
    (ImportanceEitherConfirmationOpportunity session first second)
    "Ordering judgment:"
    ["Either order is fine between", "", citation state first, citation state second, "", "Place them next to each other in either deterministic order?"]
    "Confirm?"
    "importance.either.accept"
    "importance.either.reject"
    first

makeImportanceProvisionalEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> UUIDv7 -> UUIDv7 -> InteractionEnvelope
makeImportanceProvisionalEnvelope previous now state session first second =
  confirmation
    previous
    now
    state
    (ImportanceProvisionalConfirmationOpportunity session first second)
    "No honest direction was found."
    ["Keep a deterministic provisional position near the current comparator", "and review it later?"]
    "Confirm?"
    "importance.provisional.accept"
    "importance.provisional.reject"
    first

makeOrderResultEnvelope :: InteractionEnvelope -> ZonedTime -> State -> OrderSession -> Bool -> Int -> InteractionEnvelope
makeOrderResultEnvelope previous now state session complete remaining =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (OrderResultOpportunity session complete remaining)
    ( EnvelopeContent
        (if complete then "Order reviewed:" else "Ordering paused:")
        Nothing
        [scopeLabel state (orderSessionScope session), "", Text.pack (show (orderSessionComparisons session)) <> " comparisons recorded.", resultLine]
        Nothing
    )
    (resume <> [Action "next" "next" "n" False "Return to the global forecast.", more])
    (commands Nothing)
    Nothing
    (baseFooter now state)
 where
  resume = [Action "order.resume" "resume" "r" False "Resume this exact ordering scope." | not complete]
  resultLine
    | complete && remaining == 0 = Text.pack (show (length (orderSessionGroups session))) <> " sibling groups are coherent."
    | otherwise = Text.pack (show remaining) <> " placements still need review."

makeImpactClassEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeImpactClassEnvelope identity cursor precondition now state brick =
  newEnvelope
    identity
    cursor
    precondition
    now
    state
    ChoiceGrammar
    (ImpactClassOpportunity (brickId brick))
    (EnvelopeContent "Impact:" (Just (citation state (brickId brick))) ["Considering its likely result and uncertainty, how much difference is it expected to make?"] Nothing)
    (zipWith impactAction [1 :: Int ..] [minBound .. maxBound] <> [assistance "impact.unknown" "Compare reviewed roots or explain why no class can be inferred.", more])
    (commands (Just (brickId brick)))
    (Just "discover_impact")
    (brickFooter now state (brickId brick) "Last focused")

makeImpactBasisEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ImpactClass -> InteractionEnvelope
makeImpactBasisEnvelope previous now state brick impact =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (ImpactBasisOpportunity (brickId brick) impact)
    (EnvelopeContent "Impact:" (Just (citation state (brickId brick))) ["Class: " <> impactLabel impact] (Just "What supports this estimate?"))
    [ Action "impact.speculative" "speculative    A judgment without selected supporting evidence." "s" True "Record a speculative impact class."
    , Action "impact.evidence" "evidence...    Review attached material or completed validation Work." "e" False "Choose inspectable supporting evidence."
    , Action "impact.back" "back" "b" False "Choose another impact class."
    , assistance "impact.basis-unknown" "Explain evidence maturity."
    , more
    ]
    (commands (Just (brickId brick)))
    (Just "choose_impact_basis")
    (brickFooter now state (brickId brick) "Last focused")

makeImpactEvidenceEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ImpactClass -> [UUIDv7] -> InteractionEnvelope
makeImpactEvidenceEnvelope previous now state brick impact candidates =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (ImpactEvidenceOpportunity (brickId brick) impact candidates)
    (EnvelopeContent "Impact evidence:" (Just (citation state (brickId brick))) ["Choose one inspectable item that supports this judgment."] Nothing)
    ( zipWith candidateAction [1 :: Int ..] candidates
        <> [ Action "impact.evidence.feed" "feed supporting material..." "f" False "Feed new material, then return to this review."
           , Action "impact.evidence.back" "back" "b" False "Return to the evidence-basis screen."
           , assistance "impact.evidence.unknown" "Explain what qualifies as supporting evidence."
           , more
           ]
    )
    (commands (Just (brickId brick)))
    (Just "choose_inspectable_impact_evidence")
    (brickFooter now state (brickId brick) "Last focused")
 where
  candidateAction number identity =
    Action
      ("impact.evidence.select." <> renderUUIDv7 identity)
      (evidenceCitation state identity)
      (Text.pack (show number))
      False
      "Review the selected evidence's maturity and applicability."

makeImpactMaturityEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ImpactClass -> UUIDv7 -> ImpactMaturityQuestion -> Bool -> InteractionEnvelope
makeImpactMaturityEnvelope previous now state brick impact evidence question alternate =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (ImpactMaturityOpportunity (brickId brick) impact evidence question alternate)
    ( EnvelopeContent
        "Evidence maturity:"
        (Just (citation state (brickId brick)))
        ["Impact: " <> impactLabel impact, "Evidence: " <> evidenceCitation state evidence]
        (Just (maturityQuestionText question alternate))
    )
    [ Action "impact.maturity.yes" "yes" "y" False "Accept this evidence level."
    , Action "impact.maturity.no" "no" "n" False "Continue to the next lower evidence level."
    , assistance "impact.maturity.unknown" "Continue conservatively without recording negative evidence."
    , more
    ]
    (commands (Just (brickId brick)))
    (Just "discover_impact_maturity")
    (brickFooter now state (brickId brick) "Last reviewed")

makeImpactMaturityPreviewEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> ImpactClass -> UUIDv7 -> ImpactMaturity -> InteractionEnvelope
makeImpactMaturityPreviewEnvelope previous now state brick impact evidence maturity =
  nextEnvelope
    previous
    now
    state
    ConfirmationGrammar
    (ImpactMaturityPreviewOpportunity (brickId brick) impact evidence maturity)
    ( EnvelopeContent
        "Review impact?"
        (Just (citation state (brickId brick)))
        [ "Impact: " <> impactLabel impact
        , "Maturity: " <> maturityLabel maturity
        , "Relies on: " <> evidenceCitation state evidence
        ]
        Nothing
    )
    [ Action "impact.preview.accept" "yes" "y" True "Record the class, maturity, and selected evidence together."
    , Action "impact.preview.edit" "edit" "e" False "Choose evidence or class again."
    , Action "impact.preview.reject" "no" "n" False "Return without recording this judgment."
    , assistance "impact.preview.unknown" "Explain what this preview will record."
    , more
    ]
    (commands (Just (brickId brick)))
    (Just "confirm_impact_judgment")
    (brickFooter now state (brickId brick) "Last reviewed")

makeImpactComparisonEnvelope :: InteractionEnvelope -> ZonedTime -> State -> UUIDv7 -> UUIDv7 -> Int -> [UUIDv7] -> Bool -> InteractionEnvelope
makeImpactComparisonEnvelope previous now state first second skips skipped provocative =
  nextEnvelope
    previous
    now
    state
    ComparisonGrammar
    (ImpactComparisonOpportunity first second skips skipped provocative)
    ( EnvelopeContent
        "Impact:"
        (Just (citation state first))
        ["", "compared with", "", citation state second, "", "Considering what is known, " <> shortCitation state first <> " is expected to have:"]
        Nothing
    )
    [ Action "impact.more" "more impact" "m" False "Record greater expected impact for the first root."
    , Action "impact.less" "less impact" "l" False "Record greater expected impact for the second root."
    , Action "impact.same" "about the same" "a" False "Record pair-local similar expected impact."
    , Action "impact.skip" "skip" "s" False "Try one other reviewed root, then stop."
    , assistance "impact.comparison-unknown" "Inspect the outcomes and evidence without inventing a class."
    , more
    ]
    (commands (Just first))
    (Just "compare_expected_impact")
    (brickFooter now state first "Last reviewed")

makeImpactContradictionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> UUIDv7 -> UUIDv7 -> UUIDv7 -> UUIDv7 -> JudgmentRelation -> [UUIDv7] -> InteractionEnvelope
makeImpactContradictionEnvelope previous now state subject comparator above below relation path =
  axisContradictionEnvelope
    previous
    now
    state
    ImpactAxis
    (ImpactContradictionOpportunity subject comparator above below relation path)
    above
    below
    path

makeEffortContradictionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> UUIDv7 -> UUIDv7 -> Int -> [EffortClass] -> [UUIDv7] -> UUIDv7 -> UUIDv7 -> JudgmentRelation -> [UUIDv7] -> InteractionEnvelope
makeEffortContradictionEnvelope previous now state brickId exemplar index remaining tried above below relation path =
  axisContradictionEnvelope
    previous
    now
    state
    EffortAxis
    (EffortContradictionOpportunity brickId exemplar index remaining tried above below relation path)
    above
    below
    path

makeJudgmentContradictionAidEnvelope :: InteractionEnvelope -> ZonedTime -> State -> JudgmentAxis -> UUIDv7 -> [UUIDv7] -> [UUIDv7] -> InteractionEnvelope
makeJudgmentContradictionAidEnvelope previous now state axis subject triad retired =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (JudgmentContradictionAidOpportunity axis subject triad retired)
    (EnvelopeContent "Let's untangle this:" Nothing [axisAidQuestion axis] Nothing)
    ( zipWith winnerAction [1 :: Int ..] triad
        <> [ Action "judgment.aid.same" "about the same" "a" False "Record pair-local similar evidence across the displayed units."
           , assistance "judgment.aid.unresolved" "Keep the last coherent result and revisit this segment later."
           , more
           ]
    )
    (commands (Just subject))
    (Just "resolve_judgment_contradiction")
    (brickFooter now state subject "Last reviewed")
 where
  winnerAction number identity =
    Action
      ("judgment.aid.winner." <> renderUUIDv7 identity)
      (citation state identity)
      (Text.pack (show number))
      False
      (if axis == EffortAxis then "Choose the least total effort." else "Choose the greatest expected effect.")

axisContradictionEnvelope :: InteractionEnvelope -> ZonedTime -> State -> JudgmentAxis -> Opportunity -> UUIDv7 -> UUIDv7 -> [UUIDv7] -> InteractionEnvelope
axisContradictionEnvelope previous now state axis opportunity above below path =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    opportunity
    ( EnvelopeContent
        (axisLabel axis <> " contradiction detected:")
        Nothing
        (fmap (axisJudgmentLine state axis) path <> ["", "Just now", axisRelationSentence state axis above below])
        (Just "What happened?")
    )
    [ Action "judgment.changed" "changed    The newest judgment reflects a real change." "c" False "Retire only the conflicting current path and accept the new relation."
    , Action "judgment.revise" "revise answer    Return without recording the newest relation." "r" False "Restore the original comparison."
    , assistance "judgment.aid" "Compare the smallest affected set directly."
    , more
    ]
    (commands (Just above))
    (Just "resolve_judgment_contradiction")
    (brickFooter now state above "Last reviewed")

makeEffortClassEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makeEffortClassEnvelope identity cursor precondition now state brick =
  newEnvelope
    identity
    cursor
    precondition
    now
    state
    ChoiceGrammar
    (EffortClassOpportunity (brickId brick))
    (EnvelopeContent "Effort:" (Just (citation state (brickId brick))) ["How much total effort would the current scope take from start to finish?"] Nothing)
    (zipWith effortAction [1 :: Int ..] [minBound .. maxBound] <> [assistance "effort.unknown" "Compare reviewed exemplars without inventing a default.", more])
    (commands (Just (brickId brick)))
    (Just "discover_effort")
    (brickFooter now state (brickId brick) "Last reviewed")

makeEffortExemplarEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> Brick -> Int -> [EffortClass] -> [UUIDv7] -> InteractionEnvelope
makeEffortExemplarEnvelope previous now state brick exemplar index remaining tried =
  nextEnvelope
    previous
    now
    state
    ComparisonGrammar
    (EffortExemplarOpportunity (brickId brick) (brickId exemplar) index remaining tried)
    ( EnvelopeContent
        "Effort:"
        (Just (citation state (brickId brick)))
        [ ""
        , "compared with reviewed work"
        , ""
        , citation state (brickId exemplar)
        , exemplarEffortLine state exemplar
        , ""
        , shortCitation state (brickId brick) <> " would require:"
        ]
        Nothing
    )
    [ Action "effort.more" "more effort" "m" False "Narrow the subject above this reviewed exemplar."
    , Action "effort.less" "less effort" "l" False "Narrow the subject below this reviewed exemplar."
    , Action "effort.same" "about the same" "a" False "Narrow the subject to the exemplar's class."
    , Action "effort.skip" "skip" "s" False "Record no effort evidence and try another useful exemplar."
    , assistance "effort.comparison-unknown" "Explain total-scope comparability and the exemplar profile."
    , more
    ]
    (commands (Just (brickId brick)))
    (Just "compare_total_effort")
    (brickFooter now state (brickId brick) "Last reviewed")

makeEffortNarrowedEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> [EffortClass] -> InteractionEnvelope
makeEffortNarrowedEnvelope previous now state brick remaining =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (EffortNarrowedOpportunity (brickId brick) remaining)
    (EnvelopeContent "Effort:" (Just (citation state (brickId brick))) ["The comparisons narrowed the plausible classes. Choose one explicitly:"] Nothing)
    (zipWith effortAction [1 :: Int ..] remaining <> [assistance "effort.narrowed-unknown" "Leave effort unclassified.", more])
    (commands (Just (brickId brick)))
    (Just "choose_narrowed_effort")
    (brickFooter now state (brickId brick) "Last reviewed")

makeEffortProposalEnvelope :: InteractionEnvelope -> ZonedTime -> State -> Brick -> EffortClass -> InteractionEnvelope
makeEffortProposalEnvelope previous now state brick effort =
  nextEnvelope
    previous
    now
    state
    ConfirmationGrammar
    (EffortProposalOpportunity (brickId brick) effort)
    (EnvelopeContent "Effort proposal:" (Just (citation state (brickId brick))) [effortLabel effort <> " (~" <> Text.pack (show (effortPlanningHours effort)) <> " work hours)", "Derived from the comparisons you just accepted."] (Just "Record this class?"))
    [ Action "effort.proposal.accept" "yes" "y" True "Record this explicit reviewed effort class."
    , Action "effort.proposal.reject" "no" "n" False "Return to the full class ladder."
    , assistance "effort.proposal-unknown" "Explain the derivation, then return."
    , more
    ]
    (commands (Just (brickId brick)))
    (Just "confirm_effort_proposal")
    (brickFooter now state (brickId brick) "Last reviewed")

makePhaseEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> Brick -> InteractionEnvelope
makePhaseEnvelope identity cursor precondition now state brick =
  newEnvelope
    identity
    cursor
    precondition
    now
    state
    ChoiceGrammar
    (PhaseOpportunity (brickId brick))
    (EnvelopeContent "Phase:" (Just (citation state (brickId brick))) [] (Just "Which optional descriptive phase fits now?"))
    ( [ Action "phase.idea" "idea    An immature possibility." "i" False "Record idea phase."
      , Action "phase.spec" "spec    Planning or specification." "s" False "Record spec phase."
      , Action "phase.execution" "execution    Work is being carried out." "e" False "Record execution phase."
      , Action "phase.validation" "validation    Testing, proof, or acceptance." "v" False "Record validation phase."
      ]
        <> clearOrLeave
        <> [assistance "phase.unknown" "Explain that phase is optional and never controls importance.", more]
    )
    (commands (Just (brickId brick)))
    (Just "choose_optional_phase")
    (brickFooter now state (brickId brick) "Last reviewed")
 where
  clearOrLeave = case Map.lookup (brickId brick) (statePhaseClaims state) of
    Just _ -> [Action "phase.clear" "clear phase    Leave it unspecified." "c" False "Clear the current phase claim."]
    Nothing -> [Action "phase.leave" "leave unspecified" "l" False "Keep phase absent."]

makeJudgmentResultEnvelope :: InteractionEnvelope -> ZonedTime -> State -> JudgmentAxis -> UUIDv7 -> Text -> InteractionEnvelope
makeJudgmentResultEnvelope previous now state axis brickId message =
  nextEnvelope
    previous
    now
    state
    ChoiceGrammar
    (JudgmentResultOpportunity axis brickId message)
    (EnvelopeContent ("✓ " <> message) Nothing [] Nothing)
    [Action "next" "next" "n" False "Return to the global forecast.", more]
    (commands (Just brickId))
    Nothing
    (brickFooter now state brickId "Last reviewed")

confirmation :: InteractionEnvelope -> ZonedTime -> State -> Opportunity -> Text -> [Text] -> Text -> Text -> Text -> UUIDv7 -> InteractionEnvelope
confirmation previous now state opportunity heading body question accept reject brickId =
  nextEnvelope
    previous
    now
    state
    ConfirmationGrammar
    opportunity
    (EnvelopeContent heading Nothing body (Just question))
    [ Action accept "yes" "y" True "Accept this explicit judgment."
    , Action reject "no" "n" False "Return without recording it."
    , assistance (reject <> ".unknown") "Return to the decisive question with an alternate probe."
    , more
    ]
    (commands (Just brickId))
    (Just "confirm_judgment")
    (brickFooter now state brickId "Ordered")

newEnvelope :: UUIDv7 -> DatasetCursor -> Text -> ZonedTime -> State -> ScreenGrammar -> Opportunity -> EnvelopeContent -> [Action] -> [CommandOption] -> Maybe Text -> Footer -> InteractionEnvelope
newEnvelope identity cursor precondition _ _ grammar opportunity content actions availableCommands uncertainty footer =
  resealEnvelope (InteractionEnvelope identity 1 cursor precondition grammar opportunity content actions availableCommands uncertainty footer 0 "core" "")

nextEnvelope :: InteractionEnvelope -> ZonedTime -> State -> ScreenGrammar -> Opportunity -> EnvelopeContent -> [Action] -> [CommandOption] -> Maybe Text -> Footer -> InteractionEnvelope
nextEnvelope previous _ _ grammar opportunity content actions availableCommands uncertainty footer =
  resealEnvelope
    previous
      { envelopeRevision = envelopeRevision previous + 1
      , envelopeGrammar = grammar
      , envelopeOpportunity = opportunity
      , envelopeContent = content
      , envelopeActions = actions
      , envelopeCommands = availableCommands
      , envelopeUncertaintyRoute = uncertainty
      , envelopeFooter = footer
      , envelopeNoticeTurn = envelopeNoticeTurn previous + 1
      , envelopeProvenance = "core"
      }

baseFooter :: ZonedTime -> State -> Footer
baseFooter now state =
  Footer "<root>" "<no Domain>" "Workday" (formatTimeText "%a, %b %-d" now) (formatTimeText "%a, %b %-d, %H:%M" now) (brickCount state) (rawCount state) (rawCount state + Map.size (stateLazyReviews state)) "dumb" focus Nothing 0
 where
  focus = maybe "idle" (\identity -> maybe "idle" (renderHandle BrickHandle . brickHandle) (Map.lookup identity (stateBricks state))) (stateCurrentFocus state)

brickFooter :: ZonedTime -> State -> UUIDv7 -> Text -> Footer
brickFooter now state identity label =
  case Map.lookup identity (stateBricks state) of
    Nothing -> baseFooter now state
    Just brick ->
      (baseFooter now state)
        { footerParent = maybe "<root>" (citation state) (brickParent brick)
        , footerDomain = domainSetText state (brickDomains brick)
        , footerTimeLabel = label
        , footerTimeValue = formatTimeText "%a, %b %-d, %H:%M" (utcToZonedTime (zonedTimeZone now) (brickCreatedAt brick))
        }

commands :: Maybe UUIDv7 -> [CommandOption]
commands subject =
  [CommandOption "feed" "/feed" "Feed Little Ant"]
    <> maybe [] (\identity -> [CommandOption "show" ("/show " <> renderUUIDv7 identity) "Inspect the current Brick"]) subject
    <> [ CommandOption "history" "/history" "Open interaction history"
       , CommandOption "help" "/help" "Open Little Ant help"
       , CommandOption "exit" "/exit" "Leave this presentation session"
       ]

more :: Action
more = Action "palette.open" "more..." "/" False "Open contextual commands."

assistance :: Text -> Text -> Action
assistance identifier = Action identifier "I don't know" "?" False

citation :: State -> UUIDv7 -> Text
citation state identity = maybe ("<missing " <> renderUUIDv7 identity <> ">") (\brick -> renderHandle BrickHandle (brickHandle brick) <> " \"" <> brickTitle brick <> "\"") (Map.lookup identity (stateBricks state))

shortCitation :: State -> UUIDv7 -> Text
shortCitation state identity = maybe (renderUUIDv7 identity) (renderHandle BrickHandle . brickHandle) (Map.lookup identity (stateBricks state))

judgmentLine :: State -> UUIDv7 -> Text
judgmentLine state identity = case Map.lookup identity (statePairJudgments state) of
  Nothing -> "<missing judgment>"
  Just judgment ->
    Text.pack (formatTime defaultTimeLocale "%b %-d, %Y · %H:%M" (judgmentRecordedAt judgment))
      <> "\n"
      <> citation state (judgmentFirst judgment)
      <> " was more important than "
      <> citation state (judgmentSecond judgment)

axisAidQuestion :: JudgmentAxis -> Text
axisAidQuestion = \case
  ImpactAxis -> "Considering what is known, which would be expected to make the biggest difference?"
  EffortAxis -> "Which would require the least total effort from start to finish?"
  ImportanceAxis -> "If only one could ever be completed, which one should it be?"

axisLabel :: JudgmentAxis -> Text
axisLabel = \case
  ImportanceAxis -> "Importance"
  ImpactAxis -> "Impact"
  EffortAxis -> "Effort"

axisJudgmentLine :: State -> JudgmentAxis -> UUIDv7 -> Text
axisJudgmentLine state axis identity = case Map.lookup identity (statePairJudgments state) of
  Nothing -> "<missing judgment>"
  Just judgment ->
    Text.pack (formatTime defaultTimeLocale "%b %-d, %Y · %H:%M" (judgmentRecordedAt judgment))
      <> "\n"
      <> axisRelationSentence state axis (judgmentFirst judgment) (judgmentSecond judgment)

axisRelationSentence :: State -> JudgmentAxis -> UUIDv7 -> UUIDv7 -> Text
axisRelationSentence state axis first second =
  citation state first
    <> case axis of
      ImpactAxis -> " had more impact than "
      EffortAxis -> " required more effort than "
      ImportanceAxis -> " was more important than "
    <> citation state second

scopeCounts :: State -> Maybe UUIDv7 -> Text
scopeCounts state parent = Text.pack (show (length (siblingBricks state parent))) <> " siblings"

currentParent :: State -> Maybe UUIDv7
currentParent state = stateCurrentFocus state >>= (brickParent <=< (`Map.lookup` stateBricks state))

scopeLabel :: State -> OrderScope -> Text
scopeLabel state = \case
  AllSiblingGroups -> "All sibling groups"
  OneSiblingGroup Nothing -> "<root>"
  OneSiblingGroup (Just identity) -> citation state identity
  DomainSiblingGroups identity -> domainPath state identity

domainSetText :: State -> Set.Set UUIDv7 -> Text
domainSetText state identities
  | Set.null identities = "<no Domain>"
  | otherwise = Text.intercalate ", " (fmap (domainPath state) (Set.toAscList identities))

domainPath :: State -> UUIDv7 -> Text
domainPath state identity = case Map.lookup identity (stateDomains state) of
  Nothing -> "<missing Domain>"
  Just domain -> maybe "" (\parent -> domainPath state parent <> " › ") (domainParent domain) <> domainName domain

impactAction :: Int -> ImpactClass -> Action
impactAction number impact = Action ("impact.class." <> impactKey impact) (impactLabel impact <> "    " <> impactAnchor impact) (Text.pack (show number)) False "Choose this expected-impact class."

impactKey :: ImpactClass -> Text
impactKey = \case VeryLowImpact -> "very-low"; LowImpact -> "low"; MediumImpact -> "medium"; HighImpact -> "high"; VeryHighImpact -> "very-high"; CriticalImpact -> "critical"

impactLabel :: ImpactClass -> Text
impactLabel = Text.toUpper . Text.replace "-" " " . impactKey

impactAnchor :: ImpactClass -> Text
impactAnchor = \case
  VeryLowImpact -> "A barely noticeable, local improvement."
  LowImpact -> "A small, limited improvement."
  MediumImpact -> "A meaningful but bounded result."
  HighImpact -> "A major result for an important responsibility."
  VeryHighImpact -> "A transformative result or major loss avoided."
  CriticalImpact -> "Safety, legality, or essential continuity is at stake."

effortAction :: Int -> EffortClass -> Action
effortAction number effort = Action ("effort.class." <> effortKey effort) (effortLabel effort <> "    ~" <> Text.pack (show (effortPlanningHours effort)) <> " work hours") (Text.pack (show number)) False "Choose this total-effort class."

effortKey :: EffortClass -> Text
effortKey = \case VeryEasyEffort -> "very-easy"; EasyEffort -> "easy"; NormalEffort -> "normal"; ModerateEffort -> "moderate"; HardEffort -> "hard"; VeryHardEffort -> "very-hard"; MiniProjectEffort -> "mini-project"; ProjectEffort -> "project"

effortLabel :: EffortClass -> Text
effortLabel = Text.toUpper . Text.replace "-" " " . effortKey

maturityLabel :: ImpactMaturity -> Text
maturityLabel = \case
  SpeculativeImpact -> "SPECULATIVE"
  SupportedImpact -> "SUPPORTED"
  ValidatedImpact -> "VALIDATED"
  ObservedImpact -> "OBSERVED"

maturityQuestionText :: ImpactMaturityQuestion -> Bool -> Text
maturityQuestionText question alternate = case (question, alternate) of
  (ObservedResultQuestion, False) -> "Was the claimed result observed in its real intended setting?"
  (ObservedResultQuestion, True) -> "Did this evidence record the result where it was actually meant to occur?"
  (RepresentativeTestQuestion, False) -> "Was it directly tested in a representative setting?"
  (RepresentativeTestQuestion, True) -> "Did a deliberate test reproduce the relevant conditions?"
  (RelevantSupportQuestion, False) -> "Is there relevant support beyond intuition or the original claim?"
  (RelevantSupportQuestion, True) -> "Would a skeptical reader find independent support in this evidence?"

evidenceCitation :: State -> UUIDv7 -> Text
evidenceCitation state identity =
  case Map.lookup identity (stateRaws state) of
    Just raw -> renderHandle RawHandle (rawHandle raw) <> " \"" <> rawPreview raw <> "\""
    Nothing -> citation state identity

exemplarEffortLine :: State -> Brick -> Text
exemplarEffortLine state exemplar = case Map.lookup (brickId exemplar) (stateEffortClaims state) of
  Nothing -> "Effort: not classified"
  Just claim -> "Effort: " <> effortLabel (effortClaimClass claim) <> " (~" <> Text.pack (show (effortPlanningHours (effortClaimClass claim))) <> " work hours)"

rawPreview :: Raw -> Text
rawPreview = Text.take 72 . Text.unwords . Text.words . rawOriginal

importanceDiscoveryQuestion :: State -> UUIDv7 -> UUIDv7 -> ImportanceDiscoveryNode -> Bool -> Text
importanceDiscoveryQuestion state first second node alternate =
  case (node, alternate) of
    (UnderstandFirstResult, False) -> "Do you understand what result " <> shortCitation state first <> " is meant to produce and what would be lost if it were never done?"
    (UnderstandFirstResult, True) -> "Could you explain the lasting consequence of never doing " <> shortCitation state first <> "?"
    (InspectFirstContext, _) -> "Would inspecting the first Brick's context help?"
    (UnderstandSecondResult, False) -> "Do you understand what result " <> shortCitation state second <> " is meant to produce and what would be lost if it were never done?"
    (UnderstandSecondResult, True) -> "Could you explain the lasting consequence of never doing " <> shortCitation state second <> "?"
    (InspectSecondContext, _) -> "Would inspecting the second Brick's context help?"
    (ChooseFirstForever, _) -> "If only one could ever be completed, would you choose " <> shortCitation state first <> "?"
    (ChooseSecondForever, _) -> "If only one could ever be completed, would you choose " <> shortCitation state second <> "?"
    (AcceptEitherOrder, _) -> "Would either relative order be fine for this exact pair?"
    (SeekNewEvidence, _) -> "Would new evidence help determine which Brick is more important?"
    (TryNearbySibling, _) -> "Would comparing against one nearby sibling be easier?"

formatTimeText :: String -> ZonedTime -> Text
formatTimeText format = Text.pack . formatTime defaultTimeLocale format

safeHead :: [value] -> Maybe value
safeHead = \case [] -> Nothing; first : _ -> Just first

(<=<) :: (b -> Maybe c) -> (a -> Maybe b) -> a -> Maybe c
(<=<) left right value = right value >>= left
