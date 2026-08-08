module LittleAnt.Catalog (
  FocusCapability (..),
  NatureDefinition (..),
  StructureCapability (..),
  TemplateDefinition (..),
  compatibleTemplates,
  factoryNatures,
  factoryTemplates,
  findNature,
  findTemplate,
  natureIdentifier,
  natureLabel,
  validateFactoryCatalog,
)
where

import Data.List (nub)
import Data.Maybe (isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import LittleAnt.Model

data FocusCapability
  = FiniteFocus
  | RepeatableFocus
  | HabitFocus
  | ChecklistFocus
  | ScheduledFocus
  deriving stock (Eq, Ord, Show)

data StructureCapability
  = NoOwnedStructure
  | FiniteChildBricks
  | OpenChildBricks
  | FiniteListEntries
  | LivingListEntries
  | PreparationBricks
  deriving stock (Eq, Ord, Show)

data NatureDefinition = NatureDefinition
  { natureValue :: BrickNature
  , natureDefinitionId :: Text
  , natureDefinitionVersion :: Text
  , natureDisplayLabel :: Text
  , natureShortcut :: Text
  , natureExample :: Text
  , natureFocusCapability :: FocusCapability
  , natureStructureCapability :: StructureCapability
  }
  deriving stock (Eq, Show)

data TemplateDefinition = TemplateDefinition
  { templateDefinitionId :: Text
  , templateDefinitionVersion :: Text
  , templateNature :: BrickNature
  , templateDisplayLabel :: Text
  , templateExample :: Text
  , templateShortcut :: Maybe Text
  }
  deriving stock (Eq, Show)

factoryNatures :: [NatureDefinition]
factoryNatures =
  [ nature AtomicTask "atomic_task" "atomic task" "a" "Replace a broken light bulb" FiniteFocus NoOwnedStructure
  , nature Project "project" "project" "p" "Migrate the website to a new host" FiniteFocus FiniteChildBricks
  , nature Collection "collection" "collection" "c" "Books to read" FiniteFocus OpenChildBricks
  , nature FiniteChecklist "finite_checklist" "finite checklist" "f" "Pack for the August trip" ChecklistFocus FiniteListEntries
  , nature LivingChecklist "living_checklist" "living checklist" "l" "Grocery list" ChecklistFocus LivingListEntries
  , nature Repeatable "repeatable" "repeatable" "r" "Reread this article in six months" RepeatableFocus NoOwnedStructure
  , nature RecurringObligation "recurring_obligation" "recurring obligation" "o" "Pay the monthly rent" FiniteFocus NoOwnedStructure
  , nature Habit "habit" "habit" "h" "Walk three times a week" HabitFocus NoOwnedStructure
  , nature ScheduledCommitment "scheduled_commitment" "scheduled commitment" "s" "Take flight AD123 to Montevideo" ScheduledFocus PreparationBricks
  ]
 where
  nature value identifier =
    NatureDefinition value identifier "factory@1"

natureIdentifier :: BrickNature -> Text
natureIdentifier value = maybe "unknown" natureDefinitionId (findNature value)

natureLabel :: BrickNature -> Text
natureLabel value = maybe "unknown" natureDisplayLabel (findNature value)

findNature :: BrickNature -> Maybe NatureDefinition
findNature value = firstWhere ((== value) . natureValue) factoryNatures

compatibleTemplates :: BrickNature -> [TemplateDefinition]
compatibleTemplates value = filter ((== value) . templateNature) factoryTemplates

findTemplate :: Text -> Maybe TemplateDefinition
findTemplate identifier = firstWhere ((== identifier) . templateDefinitionId) factoryTemplates

factoryTemplates :: [TemplateDefinition]
factoryTemplates =
  concat
    [ templates
        AtomicTask
        [ ("bug_fix", "Fix one bounded defect", Nothing)
        , ("one_off_errand", "Pick up or deliver one thing", Nothing)
        , ("one_off_purchase", "Buy one independently focusable item", Nothing)
        , ("document_review", "Review one document", Nothing)
        , ("contact_someone", "Make one call, visit, or message", Nothing)
        , ("quick_repair", "Repair one bounded physical item", Nothing)
        , ("application_submission", "Complete and submit one application", Nothing)
        ]
    , templates
        Project
        [ ("software_feature", "Specify, implement, and verify one feature", Nothing)
        , ("product_validation", "Gather evidence and decide", Nothing)
        , ("migration_project", "Plan, move, reconcile, and verify", Nothing)
        , ("research_project", "Research one question and conclude", Nothing)
        , ("event_planning", "Plan and deliver one event", Nothing)
        , ("trip_planning", "Decide and arrange one trip", Nothing)
        , ("home_improvement", "Complete one home improvement", Nothing)
        , ("learning_project", "Reach one finite learning outcome", Nothing)
        , ("incident_follow_up", "Investigate and close one incident", Nothing)
        ]
    , templates
        Collection
        [ ("reading_list", "Books to read", Nothing)
        , ("feature_backlog", "Independently focusable features", Nothing)
        , ("wishlist", "Purchase candidates", Nothing)
        , ("bills_to_pay", "Recurring bill series", Nothing)
        , ("idea_backlog", "Independently developable ideas", Nothing)
        , ("watchlist", "Films, talks, or videos", Nothing)
        , ("places_to_visit", "Places to visit", Nothing)
        , ("people_to_visit", "People to visit", Nothing)
        , ("geocaching_targets", "Caches or routes", Nothing)
        , ("recipes_to_try", "Recipes to try", Nothing)
        , ("home_maintenance_plan", "Independent maintenance work", Nothing)
        ]
    , templates
        FiniteChecklist
        [ ("trip_checklist", "Pack for one trip", Nothing)
        , ("moving_checklist", "Complete one move", Nothing)
        , ("release_checklist", "Verify one release", Nothing)
        , ("event_checklist", "Complete one event checklist", Nothing)
        , ("onboarding_checklist", "Complete one onboarding", Nothing)
        , ("audit_checklist", "Complete one audit", Nothing)
        , ("application_checklist", "Assemble one application", Nothing)
        , ("departure_checklist", "Complete one departure procedure", Nothing)
        ]
    , templates
        LivingChecklist
        [ ("grocery_list", "A reusable list shown all at once", Just "g")
        , ("household_restock_list", "Reusable household supplies", Nothing)
        , ("outing_errands", "One current errand batch", Nothing)
        , ("one_on_one_agenda", "Topics for recurring one-on-ones", Nothing)
        , ("family_agenda", "Topics for family discussion", Nothing)
        , ("questions_for_next_appointment", "Questions for an appointment", Nothing)
        ]
    , templates
        Repeatable
        [ ("article_reading", "Read linked material again later", Nothing)
        , ("periodic_review", "Review the same subject again", Nothing)
        , ("maintenance_task", "Repeat maintenance after completion", Nothing)
        , ("backup_verification", "Recheck a backup", Nothing)
        , ("subscription_review", "Reconsider one subscription", Nothing)
        , ("geocaching_outing", "Suggest another outing", Nothing)
        , ("decluttering_session", "Offer another decluttering session", Nothing)
        , ("personal_retrospective", "Revisit a retrospective", Nothing)
        ]
    , templates
        RecurringObligation
        [ ("bill_payment", "One occurrence per bill period", Nothing)
        , ("rent_payment", "Monthly rent occurrences", Nothing)
        , ("subscription_renewal", "Subscription renewal occurrences", Nothing)
        , ("periodic_filing", "One filing per period", Nothing)
        , ("scheduled_report", "One report per period", Nothing)
        , ("prescription_refill", "Required refill occurrences", Nothing)
        , ("vehicle_registration", "Registration renewals", Nothing)
        , ("insurance_renewal", "Insurance renewals", Nothing)
        , ("medical_checkup", "Required checkups", Nothing)
        , ("birthday_greeting", "Annual greeting", Nothing)
        ]
    , templates
        Habit
        [ ("physical_activity", "Track a physical activity", Nothing)
        , ("keep_in_touch", "Keep in touch with one person", Nothing)
        , ("social_time", "Maintain social contact", Nothing)
        , ("reading_habit", "Regular reading", Nothing)
        , ("study_habit", "Regular study", Nothing)
        , ("meditation_habit", "Regular meditation", Nothing)
        , ("journaling_habit", "Regular journaling", Nothing)
        , ("sleep_routine", "A sleep-related intention", Nothing)
        , ("housekeeping_habit", "Regular housekeeping", Nothing)
        , ("outdoor_time", "Regular time outdoors", Nothing)
        ]
    , templates
        ScheduledCommitment
        [ ("flight", "Flight AD123 to Montevideo", Just "f")
        , ("scheduled_transport", "Train from London to Paris", Just "t")
        , ("appointment", "Dentist appointment", Just "a")
        , ("meeting", "Quarterly planning meeting", Just "m")
        , ("event_attendance", "Attend the security conference", Just "e")
        , ("reservation", "Dinner reservation", Just "r")
        , ("class_session", "Spanish lesson", Just "c")
        , ("exam", "Driver's license exam", Just "x")
        , ("work_shift", "Saturday support shift", Just "w")
        , ("service_window", "Internet technician visit", Just "s")
        , ("hotel_stay", "Stay at Hotel Carrasco", Just "h")
        ]
    ]
 where
  templates natureValue' = fmap (\(identifier, example, shortcut) -> TemplateDefinition identifier "factory@1" natureValue' (label identifier) example shortcut)
  label = mapUnderscores

validateFactoryCatalog :: Either Text ()
validateFactoryCatalog
  | length factoryNatures /= length (nub (fmap natureValue factoryNatures)) = Left "Factory Nature values are repeated."
  | length factoryNatures /= length (nub (fmap natureDefinitionId factoryNatures)) = Left "Factory Nature identifiers are repeated."
  | length factoryTemplates /= length (nub (fmap templateDefinitionId factoryTemplates)) = Left "Factory Template identifiers are repeated."
  | any (isNothing . findNature . templateNature) factoryTemplates = Left "A Template references an unknown Nature."
  | otherwise = Right ()

firstWhere :: (value -> Bool) -> [value] -> Maybe value
firstWhere _ [] = Nothing
firstWhere predicate (value : rest)
  | predicate value = Just value
  | otherwise = firstWhere predicate rest

mapUnderscores :: Text -> Text
mapUnderscores = Text.map (\character -> if character == '_' then ' ' else character)
