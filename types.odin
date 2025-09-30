package er

void :: struct {
}

Name :: string

// For entities
Entity :: struct {
  attributes: map[Name]Attribute,
}

Attribute_Flag :: enum {
  Id,
  Optional,
  Multi,
}

Attribute :: struct {
  flags:         bit_set[Attribute_Flag],
  subAttributes: map[Name]void,
}

Entities :: map[Name]Entity

// For relationships
Relationship_Cardinality :: enum {
  ZeroOne,
  ZeroMany,
  OneOne,
  OneMany,
}

relationship_is_optional_t :: bool

Relationship :: struct {
  between:    map[Name]Relationship_Cardinality,
  attributes: map[Name]relationship_is_optional_t,
  // bool = is_optional
}

Relationships :: map[Name]Relationship

// For generalizations
Genralization_Flag :: enum {
  Total,
  Overlapping,
}
Generalization :: struct {
  flags:    bit_set[Genralization_Flag],
  entities: map[Name]void,
}

Generalizations :: map[Name]Generalization

Database :: struct {
  entities:        Entities,
  realationships:  Relationships,
  generalizations: Generalizations,
}
