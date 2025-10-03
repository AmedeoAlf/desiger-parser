package parsers

import "core:fmt"
import "core:strings"

Brackets :: enum {
  Parenthesis,
  Square,
  Curly,
}

BRACKET_RUNES := [Brackets][2]rune {
  .Parenthesis = [2]rune{'(', ')'},
  .Square      = [2]rune{'[', ']'},
  .Curly       = [2]rune{'{', '}'},
}

Parser_Result :: enum {
  Incompatible,
  Failed,
  Succeded,
}

clone :: strings.clone
is_a_0x20 :: proc(r: rune) -> bool {return r == ' '}
is_space :: strings.is_space
is_separator :: strings.is_separator

consume_rune :: proc(str: ^string) -> rune {
  ru := rune(0)
  for r, pos in str {
    if ru != 0 {
      str^ = str[pos:]
      return ru
    }
    ru = r
  }
  return 0
}

consume_if_starts :: proc(str: ^string, b: byte) -> bool {
  if str[0] == b {
    str^ = str[1:]
    return true
  } else do return false
}

// Return false only if it hasn't skipped `at_least` runes
skip_whitespace :: proc(
  cursor: ^string,
  at_least := 0,
  whitespace := is_space,
) -> (
  ok: bool,
) {
  count, total := 0, 0
  comment := false
  for r, pos in cursor {
    if comment {
      if cursor[pos - 1:pos + 1] == "*/" do comment = false
      continue
    }

    if len(cursor) >= pos + 2 && cursor[pos:pos + 2] == "/*" {
      comment = true
      continue
    }

    if whitespace(r) {
      count += 1
    } else {
      cursor^ = cursor[pos:]
      return count >= at_least
    }
  }
  cursor^ = cursor[len(cursor):]
  return count >= at_least
}

// `ok = false` only in case of uncomplete expression (no delimiter nor closed bracket)
//
// EXAMPLE:
// `cursor = " Element_A (1) { _, _, _ },   Element_B (2) { _, _, _}   }"`
// **After 1st call**
// `el = "Element_A (1) { _, _, _ }"`
// `cursor = "   Element_B (2) { _, _, _}   }"`
// **After 2nd call**
// `el = "Element_B (2) { _, _, _}"`
// `cursor = "}"`
next_list_element :: proc(
  cursor: ^string,
  delimiter := ',',
  close_on := Brackets.Curly,
  cutset := " \n",
) -> (
  el: string,
  ok: bool,
) {
  brackets_stack := make([dynamic]Brackets, context.temp_allocator)
  defer delete(brackets_stack)
  append(&brackets_stack, close_on)
  for r, pos in cursor {
    // Check for delimiter
    if r == delimiter && len(brackets_stack) == 1 {
      defer cursor^ = cursor[pos + 1:]
      return strings.trim(cursor[:pos], cutset), true
    }
    // Check if we are closing a bracket
    if r == BRACKET_RUNES[brackets_stack[len(brackets_stack) - 1]][1] {
      pop(&brackets_stack)
      // Return if we are closing the last bracket
      if len(brackets_stack) == 0 {
        defer cursor^ = cursor[pos:]
        return strings.trim(cursor[:pos], cutset), true
      }
      continue
    }
    // Check if we are opening a bracket
    for runes, type in BRACKET_RUNES do if r == runes[0] {
      append(&brackets_stack, type)
      continue
    }
  }
  return "", false
}

parse_until :: proc(cursor: ^string, invalid := is_separator) -> (s: string) {
  for r, p in cursor^ do if invalid(r) {
    defer cursor^ = cursor[p:]
    return cursor[:p]
  }
  defer cursor^ = cursor[len(cursor):]
  return cursor^
}
