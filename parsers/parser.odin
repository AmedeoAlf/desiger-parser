package parsers

import er ".."
import "core:fmt"
import "core:strings"

main :: proc() {
  content := string(#load("../example_input.txt"))

  entities := make(map[er.Name]er.Entity)
  relationships := make(map[er.Name]er.Relationship)

  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_relationship(&content, &relationships, entities)
  parse_relationship(&content, &relationships, entities)

  for n, e in entities do fmt.println(er.entity_to_string(n, e))
  for n, r in relationships do fmt.println(er.relationship_to_string(n, r))
}
