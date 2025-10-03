#+feature dynamic-literals
package output

import "../common"
import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:strconv"
import "core:strings"

TEMPLATE :: #load("template.er")

Entity_Positions_Map :: map[common.Name][2]i64
Relationship_Positions_Map :: map[common.Name][2]i64

_parent_extra_size :: proc(name: string) -> i64 {
  return i64(len(name)) * 60 / 15
}

get_model :: proc(
  template: []byte,
) -> (
  file: json.Object,
  model: json.Object,
) {
  val, err := json.parse(TEMPLATE)
  assert(err == .None)

  file = val.(json.Object)
  model = file["erDesign"].(json.Object)["model"].(json.Object)
  // Leaks but we do not care
  file["erRestructuring"] = file["erDesign"]
  return file, model
}

_write_entities :: proc(
  entities: common.Entities,
  itemsArray: ^json.Array,
) -> (
  name_to_entity: map[common.Name]i64,
) {
  name_to_entity = make(map[common.Name]i64)
  pos_y := 0
  for e in entities {
    name := strings.clone(e)

    name_to_entity[name] = i64(len(itemsArray^) + 1)

    entity_obj := json.Object {
      "__type" = "Entity",
      "_id"    = i64(len(itemsArray) + 1),
      "_name"  = name,
      "_x"     = 0,
      "_y"     = i64(pos_y),
      "_mag"   = false,
    }
    pos_y += 150
    append(itemsArray, entity_obj)
  }
  return
}

_write_generalizations :: proc(
  generalizations: common.Generalizations,
  name_to_entity: map[common.Name]i64,
  itemsArray: ^json.Array,
) {
  name_to_generalization := make(map[common.Name]i64)
  defer delete(name_to_generalization)

  for n, gen in generalizations {
    name := strings.clone(n)

    name_to_generalization[name] = i64(len(itemsArray^) + 1)

    gen_obj := json.Object {
      "__type"    = "Generalization",
      "_id"       = i64(len(itemsArray^) + 1),
      "_entityId" = name_to_entity[n],
    }

    switch gen.flags {
    case {}:
      gen_obj["_type"] = "p_e"
    case {.Overlapping}:
      gen_obj["_type"] = "p_o"
    case {.Total}:
      gen_obj["_type"] = "t_e"
    case {.Total, .Overlapping}:
      gen_obj["_type"] = "t_o"
    }
    append(itemsArray, gen_obj)
  }

  for name, id in name_to_generalization {
    genchild_obj := json.Object {
      "__type"            = "GeneralizationChild",
      "_id"               = i64(len(itemsArray^) + 1),
      "_entityId"         = name_to_entity[name],
      "_generalizationId" = id,
    }
    append(itemsArray, genchild_obj)
  }

  return
}

_write_attributes :: proc(
  entities: common.Entities,
  name_to_entity: map[common.Name]i64,
  itemsArray: ^json.Array,
) {
  for e_name, entity in entities {
    attr_count: i64 = 0
    for a_name, attr in entity.attributes {

      attr_count += 1
      pos_y := (attr_count % 2 * 2 - 1) * attr_count / 2 * 35

      attr_obj := json.Object {
        "__type"              = "Attribute",
        "_id"                 = i64(len(itemsArray^) + 1),
        "_name"               = strings.clone(a_name),
        "_identifier"         = .Id in attr.flags,
        // FIXME: Impossibile avere un externalIdentifier = true
        "_externalIdentifier" = false,
        "_parentId"           = name_to_entity[e_name],
        "_x"                  = -130 - _parent_extra_size(e_name),
        "_y"                  = pos_y,
      }

      switch attr.flags & {.Optional, .Multi} {
      case {}:
        attr_obj["_cardinality"] = "1_1"
      case {.Optional}:
        attr_obj["_cardinality"] = "0_1"
      case {.Multi}:
        attr_obj["_cardinality"] = "1_N"
      case {.Optional, .Multi}:
        attr_obj["_cardinality"] = "0_N"
      }

      append(itemsArray, attr_obj)

      attr_id := i64(len(itemsArray))
      subattr_count: i64 = 0
      for sub_name in attr.subAttributes {
        subattr_count += 1
        pos_y := (subattr_count % 2 * 2 - 1) * subattr_count / 2 * 28
        subattr_obj := json.Object {
          "__type"              = "Attribute",
          "_id"                 = i64(len(itemsArray^) + 1),
          "_name"               = strings.clone(sub_name),
          "_identifier"         = false,
          "_externalIdentifier" = false,
          "_parentId"           = attr_id,
          "_cardinality"        = attr_obj["_cardinality"].(json.String),
          "_x"                  = -100,
          "_y"                  = pos_y,
        }

        append(itemsArray, subattr_obj)
      }
    }
  }
}

_write_relationships :: proc(
  relationships: common.Relationships,
  name_to_entity: map[common.Name]i64,
  itemsArray: ^json.Array,
) {
  pos_y: i64 = 0
  for r_name, rel in relationships {

    rel_obj := json.Object {
      "__type" = "Relationship",
      "_id"    = i64(len(itemsArray^) + 1),
      "_name"  = strings.clone(r_name),
      "_x"     = 300,
      "_y"     = pos_y,
    }
    pos_y += 150

    append(itemsArray, rel_obj)

    rel_id := i64(len(itemsArray^))
    for p_name, cardinality in rel.between {
      par_obj := json.Object {
        "__type"              = "Participation",
        "_id"                 = i64(len(itemsArray^) + 1),
        "_entityId"           = name_to_entity[p_name],
        "_tableId"            = json.Null{},
        "_relationshipId"     = rel_id,
        "_externalIdentifier" = false,
        "_role"               = "",
      }

      switch cardinality {
      case .ZeroOne:
        par_obj["_cardinality"] = "0_1"
      case .ZeroMany:
        par_obj["_cardinality"] = "0_N"
      case .OneOne:
        par_obj["_cardinality"] = "1_1"
      case .OneMany:
        par_obj["_cardinality"] = "1_N"
      }

      append(itemsArray, par_obj)
    }

    attr_count: i64 = 0
    for a_name, opt in rel.attributes {
      attr_count += 1
      attr_obj := json.Object {
        "__type"              = "Attribute",
        "_id"                 = i64(len(itemsArray^) + 1),
        "_name"               = strings.clone(a_name),
        "_identifier"         = false,
        "_externalIdentifier" = false,
        "_cardinality"        = "0_1" if opt else "1_1",
        "_parentId"           = rel_id,
        "_x"                  = 130,
        "_y"                  = attr_count * 35,
      }
      append(itemsArray, attr_obj)
    }
  }
}

build_position_maps :: proc(
  db: common.Database,
) -> (
  epos_map: Entity_Positions_Map,
  rpos_map: Relationship_Positions_Map,
) {
  epos_map = make(Entity_Positions_Map)
  rpos_map = make(Relationship_Positions_Map)


  return
}

write_er :: proc(db: common.Database, writer: io.Writer) {
  context.allocator = context.temp_allocator

  // epos_map, rpos_map := build_position_maps(db)

  file, model := get_model(TEMPLATE)

  model["erCode"] = db_to_string(db)

  itemsArr := &(&model["itemsArray"]).(json.Array)
  name_to_entity := _write_entities(db.entities, itemsArr)
  _write_generalizations(db.generalizations, name_to_entity, itemsArr)
  _write_attributes(db.entities, name_to_entity, itemsArr)
  _write_relationships(db.relationships, name_to_entity, itemsArr)

  itemsMap := &(&model["itemsMap"]).(json.Object)
  for item, pos in itemsArr {
    itoa_buf: [8]byte
    pos_str := strconv.itoa(itoa_buf[:], pos + 1)
    itemsMap[strings.clone(pos_str)] = item
  }

  marshal_opts := &json.Marshal_Options{pretty = false}
  err := marshal_to_writer(writer, file, marshal_opts)
  if err != nil {
    fmt.eprintln("There was an error writing the database", err)
  }

  free_all()
}
