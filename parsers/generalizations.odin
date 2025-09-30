package parsers

import "../common"
import "core:fmt"

parse_generalization :: proc(
  cursor: ^string,
  generalizations: ^common.Generalizations,
  entities: common.Entities,
) -> Parser_Result {
  my_cursor := cursor^

  skip_whitespace(&my_cursor)
  name := parse_until(&my_cursor)
  skip_whitespace(&my_cursor, whitespace = is_a_0x20)

  if !(len(my_cursor) > 2 && my_cursor[:2] == "<=") do return .Incompatible

  if name not_in entities {
    fmt.println("Generalization with parent", name, "(a non declared entity)")
    return .Failed
  }

  my_cursor = my_cursor[2:]

  skip_whitespace(&my_cursor)

  if !consume_if_starts(&my_cursor, '{') {
    fmt.println("No opening `{` after generalization", name)
    return .Failed
  }

  gen := common.Generalization {
    entities = make(map[common.Name]common.void),
  }

  for my_cursor[0] != '}' {
    if entity, ok := next_list_element(&my_cursor); !ok {
      fmt.println("Invalid member list for generalization", name)
      delete(gen.entities)
      return .Failed
    } else {
      entity = parse_until(&entity)
      if entity not_in entities {
        fmt.println(
          "Entity",
          entity,
          "connected to parent",
          name,
          "not declared",
        )
        return .Failed
      }
      gen.entities[clone(entity)] = {}
    }
  }
  my_cursor = my_cursor[1:]
  skip_whitespace(&my_cursor)

  if !consume_if_starts(&my_cursor, '(') {
    fmt.println("Missing generalization type specifier for", name)
    return .Failed
  }
  part_or_total, ok1 := next_list_element(&my_cursor, close_on = .Parenthesis)
  excl_or_overl, ok2 := next_list_element(&my_cursor, close_on = .Parenthesis)

  if !(ok1 && ok2 && len(my_cursor) >= 1) {
    fmt.println("Invalid generalization type specifier for", name)
    return .Failed
  }
  switch part_or_total {
  case "partial":
  case "total":
    gen.flags += {.Total}
  case:
    fmt.println(
      "Invalid flag",
      part_or_total,
      "as first generalization type specifier for",
      name,
    )
    fmt.println("(Must be `partial` or `total`)")
  }

  switch excl_or_overl {
  case "exclusive":
  case "overlapping":
    gen.flags += {.Overlapping}
  case:
    fmt.println(
      "Invalid flag",
      excl_or_overl,
      "as second generalization type specifier for",
      name,
    )
    fmt.println("(Must be `exclusive` or `overlapping`)")
  }

  if my_cursor[0] != ')' do fmt.printfln("There are some extra type specifiers in generalization %s, ignoring", name)

  my_cursor = my_cursor[1:]

  generalizations[clone(name)] = gen
  cursor^ = my_cursor

  return .Succeded
}
