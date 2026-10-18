module LittleAnt.Catalog (
  FocusCapability (..),
  NatureDefinition (..),
  StructureCapability (..),
  TemplateDefinition (..),
  TemplateQuestion (..),
  WorkSetting (..),
  compatibleTemplates,
  parseWorkSetting,
  settingTemplates,
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
  , templateSetting :: Maybe WorkSetting
  , templateQuestion :: Maybe TemplateQuestion
  }
  deriving stock (Eq, Show)

-- | Where an atomic task is done; it groups the Templates a person chooses from.
data WorkSetting = DigitalSetting | PhysicalSetting
  deriving stock (Bounded, Enum, Eq, Ord, Show)

parseWorkSetting :: Text -> Maybe WorkSetting
parseWorkSetting = \case
  "digital" -> Just DigitalSetting
  "physical" -> Just PhysicalSetting
  _ -> Nothing

{- | One yes/no question of the Template assistance tree, with concrete
examples, and the reason a yes gives for choosing the Template.
-}
data TemplateQuestion = TemplateQuestion
  { templateQuestionText :: Text
  , templateQuestionExamples :: Text
  , templateQuestionReason :: Text
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

-- | The Templates of one setting, the generic one first.
settingTemplates :: BrickNature -> WorkSetting -> [TemplateDefinition]
settingTemplates value setting = filter ((== Just setting) . templateSetting) (compatibleTemplates value)

findTemplate :: Text -> Maybe TemplateDefinition
findTemplate identifier = firstWhere ((== identifier) . templateDefinitionId) factoryTemplates

factoryTemplates :: [TemplateDefinition]
factoryTemplates =
  concat
    [ [ settingTemplate DigitalSetting "digital_task" "a digital task" "Write the quarterly report" "t" Nothing
      , settingTemplate DigitalSetting "bug_fix" "bug fix" "Fix the broken login page" "b" (question "Is it fixing something broken in software or a system?" "the login page fails, a script crashes, the printer driver stopped working" "it fixes something broken in software or a system")
      , settingTemplate DigitalSetting "document_review" "document review" "Review the contract draft" "d" (question "Is it mainly reading or reviewing one document?" "review the contract draft, read the onboarding guide" "it is mainly reading or reviewing one document")
      , settingTemplate DigitalSetting "application_submission" "application submission" "Submit the visa application" "a" (question "Is it filling in and submitting one form or application?" "a visa application, the income tax return, a job application" "it fills in and submits one form or application")
      , settingTemplate DigitalSetting "contact_someone" "contact someone" "Call or message the accountant" "c" (question "Is it mainly reaching one person by call or message?" "call the accountant, reply to Ana's e-mail" "it mainly reaches one person by call or message")
      , settingTemplate PhysicalSetting "physical_task" "a physical task" "Take the car to the car wash" "t" Nothing
      , settingTemplate PhysicalSetting "one_off_errand" "errand" "Pick up the package at the post office" "e" (question "Is it picking up, returning, or delivering something?" "pick up the package, return the library book" "it picks up, returns, or delivers something")
      , settingTemplate PhysicalSetting "one_off_purchase" "buy something" "Buy a phone charger" "b" (question "Is it buying one thing?" "buy a phone charger, get a birthday gift" "it buys one thing")
      , settingTemplate PhysicalSetting "quick_repair" "repair" "Fix the leaking tap" "r" (question "Is it fixing a physical object?" "fix the leaking tap, replace the light bulb" "it fixes a physical object")
      , settingTemplate PhysicalSetting "meet_in_person" "meet someone in person" "Have coffee with a client" "m" (question "Is it meeting or visiting someone in person?" "visit grandma, have coffee with a client" "it meets or visits someone in person")
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
  templates natureValue' = fmap (\(identifier, example, shortcut) -> TemplateDefinition identifier "factory@1" natureValue' (mapUnderscores identifier) example shortcut Nothing Nothing)
  settingTemplate setting identifier label example shortcut =
    TemplateDefinition identifier "factory@1" AtomicTask label example (Just shortcut) (Just setting)
  question text examples reason = Just (TemplateQuestion text examples reason)

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
