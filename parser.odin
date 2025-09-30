package er

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"

parse_attribute :: proc(
  entity_attrs: ^map[Name]Attribute,
  attr_str: string,
) -> (
  ok: bool,
) {
  cursor := attr_str
  name := parse_until(&cursor)
  skip_whitespace(&cursor)

  if len(cursor) == 0 {
    entity_attrs[strings.clone(name)] = Attribute{}
    return true
  }

  attribute := Attribute{}

  if consume_if_starts(&cursor, '(') {
    for cursor[0] != ')' {
      if el, ok := next_list_element(&cursor, close_on = .Parenthesis); !ok {
        fmt.println("Unclosed '(' inside attribute", attr_str)
        return false
      } else {
        switch el {
        case "optional":
          attribute.flags += {.Optional}
        case "multi":
          attribute.flags += {.Multi}
        case "id":
          attribute.flags += {.Id}
        case:
          fmt.printfln(
            "Unknown attribute flag \"%s\" for attribute %s, ignoring",
            el,
            attr_str,
          )
        }
      }
    }
    cursor = cursor[1:]
    skip_whitespace(&cursor)
  }

  if len(cursor) > 0 && consume_if_starts(&cursor, '{') {
    attribute.subAttributes = make(map[Name]void)
    for cursor[0] != '}' {
      if el, ok := next_list_element(&cursor); !ok {
        fmt.println("Unclosed '{' inside attribute", attr_str)
        delete(attribute.subAttributes)
        return false
      } else {
        attribute.subAttributes[strings.clone(parse_until(&el))] = {}
      }}
    cursor = cursor[1:]
  }

  entity_attrs[strings.clone(name)] = attribute

  return true
}

parse_entity :: proc(cursor: ^string, entities: ^Entities) -> (ok: bool) {
  my_cursor := cursor^

  skip_whitespace(&my_cursor)
  (parse_until(&my_cursor) == "entity") or_return
  skip_whitespace(&my_cursor, at_least = 1, whitespace = is_a_0x20) or_return


  name := parse_until(&my_cursor)
  skip_whitespace(&my_cursor, whitespace = is_a_0x20)

  // newline -> no attributes -> return
  // '{' -> has attributes
  // else -> invalid
  if r := consume_rune(&my_cursor); r == '\n' || r != '{' {
    if r != '\n' {
      fmt.println(
        "entity",
        name,
        "might be incomplete, no attributes could be parsed",
      )
    }
    entities[strings.clone(name)] = Entity{nil}
    return true
  }

  entity := Entity {
    attributes = make(map[Name]Attribute),
  }

  cursor^ = cursor[1:]
  for my_cursor[0] != '}' {
    if attr, ok := next_list_element(&my_cursor); !ok {
      fmt.println("Invalid attribute list for", name)
      delete(entity.attributes)
      return false
    } else {
      if !parse_attribute(&entity.attributes, attr) do fmt.println("Invalid attribute", attr, "for", name)
    }
  }

  entities[strings.clone(name)] = entity

  cursor^ = my_cursor[1:]
  return true
}

parse_relationship_member :: proc(
  between_map: ^map[Name]Relationship_Cardinality,
  entities: Entities,
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

  cardinality_str := parse_until(&cursor, strings.is_space)
  cardinality: Relationship_Cardinality
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

  between_map[strings.clone(name)] = cardinality
  return true
}

parse_relationship :: proc(
  cursor: ^string,
  relationships: ^Relationships,
  entities: Entities,
) -> (
  ok: bool,
) {
  my_cursor := cursor^

  skip_whitespace(&my_cursor)
  (parse_until(&my_cursor) == "relationship") or_return
  skip_whitespace(&my_cursor, at_least = 1, whitespace = is_a_0x20) or_return


  name := parse_until(&my_cursor)
  skip_whitespace(&my_cursor, whitespace = is_a_0x20)

  rel := Relationship{}

  if consume_if_starts(&my_cursor, '(') {
    rel.between = make(map[Name]Relationship_Cardinality)
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
    rel.attributes = make(map[Name]relationship_is_optional_t)
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

main :: proc() {
  content := string(#load("example.txt"))

  entities := make(map[Name]Entity)
  relationships := make(map[Name]Relationship)

  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_entity(&content, &entities)
  parse_relationship(&content, &relationships, entities)
  parse_relationship(&content, &relationships, entities)

  for n, e in entities do fmt.println(entity_to_string(n, e))
  for n, r in relationships do fmt.println(relationship_to_string(n, r))
}
