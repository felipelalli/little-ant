-- | The canonical interaction grammar: the single source of truth for the
-- letters any operator (human or LLM) uses when driving a session. Letters
-- are owned by the core so that every operator renders the same interface;
-- a skill that invents its own letters is off-spec.
module LittleAnt.Grammar
  ( grammarView
  , grammarHuman
  ) where

import Data.Aeson
import Data.Aeson.Key (fromText)
import Data.Text (Text)
import qualified Data.Text as T

-- | One namespace: a name plus its letter/word pairs. Collisions across
-- namespaces are fine by design (a bare letter is read against the pending
-- question's namespace); collisions inside one namespace are not.
namespaces :: [(Text, [(Text, Text)])]
namespaces =
  [ ( "commands"
    , [ ("x", "next"), ("s", "skip"), ("b", "break"), ("u", "unify")
      , ("d", "done"), ("g", "delegate"), ("c", "capture")
      , ("q", "questions")
      ]
    )
  , ( "answers"
    , [ ("y", "yes"), ("n", "no"), ("l", "later") ]
    )
  , ( "skip_reasons"
    , [ ("h", "hard"), ("v", "vague"), ("p", "not_priority")
      , ("w", "waiting"), ("t", "tired"), ("m", "meh"), ("k", "kill")
      , ("a", "alternatives")
      ]
    )
  , ( "triage"
    , [ ("p", "promote"), ("s", "skip"), ("k", "kill"), ("d", "done") ]
    )
  ]

markers :: [(Text, Text)]
markers = [ ("*", "suggested default; a bare * accepts it")
          , ("?", "universal: dunno / more info / help me decide")
          ]

rules :: [Text]
rules =
  [ "With a question pending, a bare letter is an answer; a whole word is always a command."
  , "The operator shows no default when it has no basis to guess."
  , "UI language is English unless the personal manifest overrides it."
  ]

grammarView :: Value
grammarView = object
  [ "namespaces" .= object
      [ fromText ns .= [ object [ "letter" .= l, "word" .= w ]
                       | (l, w) <- pairs' ]
      | (ns, pairs') <- namespaces
      ]
  , "markers" .= object [ fromText m .= d | (m, d) <- markers ]
  , "rules" .= rules
  ]

grammarHuman :: Text
grammarHuman = T.intercalate "\n" $
  [ ns <> ":  " <> T.intercalate " · " [ l <> " " <> w | (l, w) <- pairs' ]
  | (ns, pairs') <- namespaces
  ]
  <> [ m <> "  " <> d | (m, d) <- markers ]
  <> rules
