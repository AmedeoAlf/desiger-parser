package parsers

import "../common"
import "core:fmt"

parse_file :: proc(file: string) -> (db: common.Database, ok: bool) {
  cursor := file
  db = {
    entities        = make(common.Entities),
    relationships   = make(common.Relationships),
    generalizations = make(common.Generalizations),
  }
  skip_whitespace(&cursor)
  for len(cursor) > 0 {
    res := Parser_Result.Incompatible

    // Goto could've been much easier
    res = parse_entity(&cursor, &db.entities)
    if res == .Incompatible {
      res = parse_relationship(&cursor, &db.relationships, db.entities)
      if res == .Incompatible {
        res = parse_generalization(&cursor, &db.generalizations, db.entities)
      }
    }

    switch res {
    case .Incompatible:
      fmt.eprintfln(
        "Couldn't find any expression (from \"%s\" onwards)",
        cursor[:min(20, len(cursor))],
      )
      return {}, false
    case .Failed:
      return {}, false
    case .Succeded:
    }
    skip_whitespace(&cursor)
  }

  return db, true
}
