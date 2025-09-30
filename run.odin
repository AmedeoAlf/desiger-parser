package er

import "common"
import "core:fmt"
import "parsers"

main :: proc() {
  content := string(#load("example_input.txt"))

  entities := make(map[common.Name]common.Entity)
  relationships := make(map[common.Name]common.Relationship)
  generalizations := make(map[common.Name]common.Generalization)

  using parsers
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_relationship(&content, &relationships, entities)
  parse_relationship(&content, &relationships, entities)
  parse_generalization(&content, &generalizations, entities)

  for n, e in entities do fmt.println(entity_to_string(n, e))
  for n, r in relationships do fmt.println(relationship_to_string(n, r))
  for n, g in generalizations do fmt.println(generalization_to_string(n, g))
}
