package er

import "common"
import "core:fmt"
import "core:os"
import "output"
import "parsers"

main :: proc() {
  content := string(os.read_entire_file_from_filename("input.txt") or_else {})

  db, ok := parsers.parse_file(content)
  if !ok do os.exit(1)

  fmt.eprintln(output.db_to_string(db))

  output.write_er(db, os.stream_from_handle(os.stdout))
}
