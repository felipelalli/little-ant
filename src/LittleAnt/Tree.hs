module LittleAnt.Tree (
  Tree (..),
  fromIndentedLabels,
  filterForest,
  treeRows,
)
where

import Data.Text (Text)
import Data.Text qualified as Text

data Tree value = Node value [Tree value]

-- List projections encode composition depth as two leading spaces.
fromIndentedLabels :: (value -> Text) -> [value] -> [Tree value]
fromIndentedLabels label = fst . forest (-1) . fmap (\value -> (Text.length (Text.takeWhile (== ' ') (label value)) `div` 2, value))
 where
  forest _ [] = ([], [])
  forest parent remaining@((depth, value) : rest)
    | depth <= parent = ([], remaining)
    | otherwise =
        let (children, afterChildren) = forest depth rest
            (siblings, afterSiblings) = forest parent afterChildren
         in (Node value children : siblings, afterSiblings)

-- A descendant match retains its ancestors; a parent match retains its parts.
filterForest :: (value -> Bool) -> [Tree value] -> [Tree value]
filterForest matches = concatMap keep
 where
  keep node@(Node value children)
    | matches value = [node]
    | otherwise = case filterForest matches children of
        [] -> []
        visible -> [Node value visible]

-- Prefixes for the title and subsequent detail/blank lines of each node.
treeRows :: [Tree value] -> [(Text, Text, value)]
treeRows = concatMap root
 where
  root (Node value children) = ("", continuation "" children, value) : branch "" children
  branch _ [] = []
  branch prefix (Node value children : siblings) =
    let lastSibling = null siblings
        elbow = if lastSibling then "└── " else "├── "
        stem = prefix <> if lastSibling then "    " else "│   "
     in (prefix <> elbow, continuation stem children, value) : branch stem children <> branch prefix siblings
  continuation prefix children = prefix <> if null children then "" else "│   "
