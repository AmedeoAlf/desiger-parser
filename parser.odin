package er

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"

parse_attribute :: proc(attr_str: string, entity: ^Entity) -> (ok: bool) {
  cursor := attr_str
  name := parse_until(&cursor)
  skip_whitespace(&cursor)
  if len(cursor) == 0 {
    entity.attributes[strings.clone(name)] = Attribute{}
    return true
  }

  attribute := Attribute{}
  skip_whitespace(&cursor)
  for len(cursor) > 0 {
    switch consume_rune(&cursor) {
    case '(':
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
    case '{':
      attribute.subAttributes = make(map[Name]void)
      for cursor[0] != '}' {
        if el, ok := next_list_element(&cursor); !ok {
          fmt.println("Unclosed '{' inside attribute", attr_str)
          delete(attribute.subAttributes)
          return false
        } else {
          attribute.subAttributes[strings.clone(parse_until(&el))] = {}
        }
      }
      cursor = cursor[1:]
    }
    skip_whitespace(&cursor)
  }

  entity.attributes[strings.clone(name)] = attribute

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
  if r := consume_rune(&my_cursor); r == '\n' {
    entities[strings.clone(name)] = Entity{nil}
    return true
  } else if r != '{' {
    return false
  }

  entity := Entity {
    attributes = make(map[Name]Attribute),
  }

  for my_cursor[0] != '}' {
    my_cursor = my_cursor[1:]
    if attr, ok := next_list_element(&my_cursor); !ok {
      fmt.println("Invalid attribute list for", name)
      delete(entity.attributes)
      return false
    } else {
      if !parse_attribute(attr, &entity) do fmt.println("Invalid attribute", attr, "for", name)
    }
  }

  entities[strings.clone(name)] = entity

  cursor^ = my_cursor[1:]
  return true
}

// Return false
parse_until :: proc(
  cursor: ^string,
  invalid := strings.is_separator,
) -> (
  s: string,
) {
  for r, p in cursor^ do if invalid(r) {
    defer cursor^ = cursor[p:]
    return cursor[:p]
  }
  defer cursor^ = cursor[len(cursor):]
  return cursor^
}


parse :: proc(text: string) {
  cursor := text
  name := parse_until(&cursor)

}

main :: proc() {
  content, ok := os.read_entire_file_from_filename("example.txt")
  if !ok do return

  entities := make(map[Name]Entity)

  parse_entity(transmute(^string)&content, &entities)
  parse_entity(transmute(^string)&content, &entities)
  parse_entity(transmute(^string)&content, &entities)
  parse_entity(transmute(^string)&content, &entities)
  fmt.println(entities_to_string(entities))
}
