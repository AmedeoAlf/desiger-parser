package output

import "../common"
import "core:fmt"
import "core:strings"

ATTRIBUTE_FLAGS_STRINGS := [common.Attribute_Flag]string {
  .Id       = "id",
  .Multi    = "multi",
  .Optional = "optional",
}

CARDINALITIES_STRINGS := [common.Relationship_Cardinality]string {
  .ZeroOne  = "zero..one",
  .OneMany  = "one..many",
  .OneOne   = "one..one",
  .ZeroMany = "zero..many",
}

// Result must be freed
entity_to_string :: proc(name: common.Name, entity: common.Entity) -> string {
  using strings

  builder := builder_make_none()
  defer builder_destroy(&builder)

  fmt.sbprintf(&builder, "entity %s", name)

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
        write_byte(&builder, ')')
      }

      // write subattributes
      if len(attribute.subAttributes) != 0 {
        write_string(&builder, " {\n")
        for subattr in attribute.subAttributes {
          fmt.sbprintf(&builder, "        %s,\n", subattr)
        }
        resize(&builder.buf, len(builder.buf) - 2) // Remove last ",\n"
        write_string(&builder, "\n    }")
      }

      write_string(&builder, ",\n")
    }
    resize(&builder.buf, len(builder.buf) - 2) // Remove last ",\n"
    write_string(&builder, "\n}")
  }

  return clone(to_string(builder))
}

// Result must be freed
relationship_to_string :: proc(
  name: common.Name,
  relationship: common.Relationship,
) -> string {
  using strings

  builder := builder_make_none()
  defer builder_destroy(&builder)

  fmt.sbprintf(&builder, "relationship %s", name)

  if len(relationship.between) != 0 {
    write_string(&builder, " (\n")

    for member, cardinality in relationship.between {
      fmt.sbprintfln(
        &builder,
        "    %s: %s,",
        member,
        CARDINALITIES_STRINGS[cardinality],
      )
    }
    resize(&builder.buf, len(builder.buf) - 2) // Remove last ",\n"
    write_string(&builder, "\n)")
  }

  if len(relationship.attributes) != 0 {
    write_string(&builder, " {\n")

    for attr, optional in relationship.attributes {
      fmt.sbprintf(&builder, "    %s", attr)
      if optional do write_string(&builder, " (optional)")
      write_string(&builder, ",\n")
    }
    resize(&builder.buf, len(builder.buf) - 2) // Remove last ",\n"
    write_string(&builder, "\n}")
  }

  return clone(to_string(builder))
}

// Result must be freed
generalization_to_string :: proc(
  name: common.Name,
  generalization: common.Generalization,
) -> string {
  using strings

  builder := builder_make_none()
  defer builder_destroy(&builder)

  fmt.sbprintfln(&builder, "%s <= {{", name)

  for entity in generalization.entities do fmt.sbprintfln(&builder, "    %s,", entity)
  resize(&builder.buf, len(builder.buf) - 2) // Remove last ",\n"

  write_string(&builder, "\n} (")

  write_string(
    &builder,
    "total" if .Total in generalization.flags else "partial",
  )

  write_string(&builder, ", ")

  write_string(
    &builder,
    "overlapping" if .Overlapping in generalization.flags else "exclusive",
  )

  write_byte(&builder, ')')

  return clone(to_string(builder))
}

// Result must be freed
db_to_string :: proc(db: common.Database) -> string {
  using strings

  orig_alloc := context.allocator
  context.allocator = context.temp_allocator

  builder := builder_make_none()
  defer builder_destroy(&builder)

  move_to_builder :: proc(b: ^strings.Builder, s: string) {
    strings.write_string(b, s)
    strings.write_byte(b, '\n')
    delete(s)
  }

  for e_name, entity in db.entities do move_to_builder(&builder, entity_to_string(e_name, entity))
  for r_name, rel in db.relationships do move_to_builder(&builder, relationship_to_string(r_name, rel))
  for g_name, gen in db.generalizations do move_to_builder(&builder, generalization_to_string(g_name, gen))

  return clone(to_string(builder), orig_alloc)
}
