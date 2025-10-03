package parsers

import er "../common"
import "core:fmt"

parse_relationship_member :: proc(
  between_map: ^map[er.Name]er.Relationship_Cardinality,
  entities: er.Entities,
  member_str: string,
) -> (
  ok: bool,
) {
  cursor := member_str
  name := parse_until(&cursor)

  if name not_in entities {
    fmt.println("Member", name, "is not an entity")
    return false
  }

  if !(len(cursor) > 0 && consume_if_starts(&cursor, ':')) {
    fmt.println("Missing `:` after member", name)
    return false
  }
  skip_whitespace(&cursor) or_return

  cardinality_str := parse_until(&cursor, is_space)
  cardinality: er.Relationship_Cardinality
  switch cardinality_str {
  case "zero..one":
    cardinality = .ZeroOne
  case "zero..many":
    cardinality = .ZeroMany
  case "one..one":
    cardinality = .OneOne
  case "one..many":
    cardinality = .OneMany
  case:
    fmt.printfln(
      "Invalid cardinality `%s` for member %s",
      cardinality_str,
      name,
    )
    fmt.println(
      "(Supported ones are `zero..one` `zero..many` `one..one` `one..many`)",
    )
    return false
  }

  between_map[clone(name)] = cardinality
  return true
}

parse_relationship :: proc(
  cursor: ^string,
  relationships: ^er.Relationships,
  entities: er.Entities,
) -> Parser_Result {
  my_cursor := cursor^

  skip_whitespace(&my_cursor)
  if parse_until(&my_cursor) != "relationship" ||
     !skip_whitespace(
         &my_cursor,
         at_least = 1,
         whitespace = is_a_0x20,
       ) {return .Incompatible}


  name := parse_until(&my_cursor)
  skip_whitespace(&my_cursor, whitespace = is_a_0x20)

  rel := er.Relationship{}

  if len(my_cursor) > 0 && consume_if_starts(&my_cursor, '(') {
    rel.between = make(map[er.Name]er.Relationship_Cardinality)
    for my_cursor[0] != ')' {
      if member, ok := next_list_element(&my_cursor, close_on = .Parenthesis);
         !ok {
        fmt.println("Invalid member list for relationship", name)
        delete(rel.between)
        return .Failed
      } else {
        if !parse_relationship_member(&rel.between, entities, member) do fmt.printfln("Invalid member `%s` for relationship %s", member, name)
      }
    }
    my_cursor = my_cursor[1:]
    skip_whitespace(&my_cursor)
  }

  if len(my_cursor) > 0 && consume_if_starts(&my_cursor, '{') {
    rel.attributes = make(map[er.Name]er.relationship_is_optional_t)
    for my_cursor[0] != '}' {
      if attr, ok := next_list_element(&my_cursor); !ok {
        fmt.println("Invalid attribute list for relationship", name)
        delete(rel.attributes)
        delete(rel.between)
        return .Failed
      } else {
        attr_cursor := attr
        attr_name := parse_until(&attr_cursor)
        skip_whitespace(&attr_cursor)

        rel.attributes[clone(attr_name)] = false
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

  relationships[clone(name)] = rel
  cursor^ = my_cursor

  return .Succeded
}
