package parsers

import er "../common"
import "core:fmt"

parse_attribute :: proc(
  entity_attrs: ^map[er.Name]er.Attribute,
  attr_str: string,
) -> (
  ok: bool,
) {
  cursor := attr_str
  name := parse_until(&cursor)
  skip_whitespace(&cursor)

  if len(cursor) == 0 {
    entity_attrs[clone(name)] = er.Attribute{}
    return true
  }

  attribute := er.Attribute{}

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
    attribute.subAttributes = make(map[er.Name]er.void)
    for cursor[0] != '}' {
      if el, ok := next_list_element(&cursor); !ok {
        fmt.println("Unclosed '{' inside attribute", attr_str)
        delete(attribute.subAttributes)
        return false
      } else {
        attribute.subAttributes[clone(parse_until(&el))] = {}
      }}
    cursor = cursor[1:]
  }

  entity_attrs[clone(name)] = attribute

  return true
}

parse_entity :: proc(
  cursor: ^string,
  entities: ^er.Entities,
) -> Parser_Result {
  my_cursor := cursor^

  skip_whitespace(&my_cursor)
  if parse_until(&my_cursor) != "entity" do return .Incompatible
  if !skip_whitespace(&my_cursor, at_least = 1, whitespace = is_a_0x20) do return .Incompatible


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
    entities[clone(name)] = er.Entity{nil}
    return .Succeded
  }

  entity := er.Entity {
    attributes = make(map[er.Name]er.Attribute),
  }

  cursor^ = cursor[1:]
  for my_cursor[0] != '}' {
    if attr, ok := next_list_element(&my_cursor); !ok {
      fmt.println("Invalid attribute list for", name)
      delete(entity.attributes)
      return .Failed
    } else {
      if !parse_attribute(&entity.attributes, attr) do fmt.println("Invalid attribute", attr, "for", name)
    }
  }

  entities[clone(name)] = entity

  cursor^ = my_cursor[1:]
  return .Succeded
}
