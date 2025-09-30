package parsers

import er ".."
import "core:fmt"
import "core:strings"

parse_relationship :: proc(
  cursor: ^string,
  relationships: ^er.Relationships,
  entities: er.Entities,
) -> (
  ok: bool,
) {
  my_cursor := cursor^

  skip_whitespace(&my_cursor)
  (parse_until(&my_cursor) == "relationship") or_return
  skip_whitespace(&my_cursor, at_least = 1, whitespace = is_a_0x20) or_return


  name := parse_until(&my_cursor)
  skip_whitespace(&my_cursor, whitespace = is_a_0x20)

  rel := er.Relationship{}

  if consume_if_starts(&my_cursor, '(') {
    rel.between = make(map[er.Name]er.Relationship_Cardinality)
    for my_cursor[0] != ')' {
      if member, ok := next_list_element(&my_cursor, close_on = .Parenthesis);
         !ok {
        fmt.println("Invalid member list for relationship", name)
        delete(rel.between)
        return false
      } else {
        if !parse_relationship_member(&rel.between, entities, member) do fmt.printfln("Invalid member `%s` for relationship %s", member, name)
      }
    }
    my_cursor = my_cursor[1:]
    skip_whitespace(&my_cursor)
  }

  if consume_if_starts(&my_cursor, '{') {
    rel.attributes = make(map[er.Name]er.relationship_is_optional_t)
    for my_cursor[0] != '}' {
      if attr, ok := next_list_element(&my_cursor); !ok {
        fmt.println("Invalid attribute list for relationship", name)
        delete(rel.attributes)
        return false
      } else {
        attr_cursor := attr
        attr_name := parse_until(&attr_cursor)
        skip_whitespace(&attr_cursor)

        rel.attributes[strings.clone(attr_name)] = false
        if len(attr_cursor) == 0 do continue

        OPTIONAL_STR :: "(optional)"
        if attr_cursor[:max(len(attr_cursor), len(OPTIONAL_STR))] ==
           OPTIONAL_STR {
          rel.attributes[attr_name] = true
        } else {
          fmt.printfln(
            "Ignoring trailing code `%s` for attribute %s in relationship %s",
            attr_cursor,
            attr_name,
            name,
          )
        }
      }
    }
    my_cursor = my_cursor[1:]
  }

  relationships[strings.clone(name)] = rel
  cursor^ = my_cursor

  return true
}
