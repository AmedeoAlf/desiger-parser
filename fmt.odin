package er

import "core:fmt"
import "core:strings"

ATTRIBUTE_FLAGS_STRINGS := [Attribute_Flag]string {
  .Id       = "id",
  .Multi    = "multi",
  .Optional = "optional",
}

entities_to_string :: proc(entities: Entities) -> string {
  using strings

  builder := builder_make_none()
  defer builder_destroy(&builder)

  for e_name, entity in entities {
    fmt.sbprintf(&builder, "entity %s", e_name)

    if len(entity.attributes) != 0 {
      write_string(&builder, " {\n")

      for a_name, attribute in entity.attributes {
        fmt.sbprintf(&builder, "    %s", a_name)

        // write flags
        if card(attribute.flags) != 0 {
          write_string(&builder, " (")
          for flag in attribute.flags {
            fmt.sbprintf(&builder, "%s, ", ATTRIBUTE_FLAGS_STRINGS[flag])
          }
          resize(&builder.buf, len(builder.buf) - 2) // Remove last ", "
          write_string(&builder, ")")
        }

        // write subattributes
        if len(attribute.subAttributes) != 0 {

        }

        write_string(&builder, ",\n")
      }
      resize(&builder.buf, len(builder.buf) - 2) // Remove last ", "
      write_string(&builder, "\n}")
    }

    write_byte(&builder, '\n')
  }
  return clone(to_string(builder))
}
