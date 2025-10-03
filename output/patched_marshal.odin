package output

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:math/bits"
import "core:mem"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"

cast_any_int_to_u128 :: proc(any_int_value: any) -> u128 {
  u: u128 = 0
  switch i in any_int_value {
  case i8:
    u = u128(i)
  case i16:
    u = u128(i)
  case i32:
    u = u128(i)
  case i64:
    u = u128(i)
  case i128:
    u = u128(i)
  case int:
    u = u128(i)
  case u8:
    u = u128(i)
  case u16:
    u = u128(i)
  case u32:
    u = u128(i)
  case u64:
    u = u128(i)
  case u128:
    u = u128(i)
  case uint:
    u = u128(i)
  case uintptr:
    u = u128(i)

  case i16le:
    u = u128(i)
  case i32le:
    u = u128(i)
  case i64le:
    u = u128(i)
  case u16le:
    u = u128(i)
  case u32le:
    u = u128(i)
  case u64le:
    u = u128(i)
  case u128le:
    u = u128(i)

  case i16be:
    u = u128(i)
  case i32be:
    u = u128(i)
  case i64be:
    u = u128(i)
  case u16be:
    u = u128(i)
  case u32be:
    u = u128(i)
  case u64be:
    u = u128(i)
  case u128be:
    u = u128(i)
  }

  return u
}

marshal_to_writer :: proc(
  w: io.Writer,
  v: any,
  opt: ^json.Marshal_Options,
) -> (
  err: json.Marshal_Error,
) {
  if v == nil {
    io.write_string(w, "null") or_return
    return
  }

  ti := runtime.type_info_base(type_info_of(v.id))
  a := any{v.data, ti.id}


  switch info in ti.variant {
  case runtime.Type_Info_Struct:
  case runtime.Type_Info_Named:
    unreachable()

  case runtime.Type_Info_Integer:
    buf: [40]byte
    u := cast_any_int_to_u128(a)

    s: string

    // allow uints to be printed as hex
    if opt.write_uint_as_hex && (opt.spec == .JSON5 || opt.spec == .MJSON) {
      switch i in a {
      case u8, u16, u32, u64, u128:
        s = strconv.write_bits_128(
          buf[:],
          u,
          16,
          info.signed,
          8 * ti.size,
          "0123456789abcdef",
          {.Prefix},
        )

      case:
        s = strconv.write_bits_128(
          buf[:],
          u,
          10,
          info.signed,
          8 * ti.size,
          "0123456789",
          nil,
        )
      }
    } else {
      s = strconv.write_bits_128(
        buf[:],
        u,
        10,
        info.signed,
        8 * ti.size,
        "0123456789",
        nil,
      )
    }

    io.write_string(w, s) or_return


  case runtime.Type_Info_Rune:
    r := a.(rune)
    io.write_byte(w, '"') or_return
    io.write_escaped_rune(w, r, '"', true) or_return
    io.write_byte(w, '"') or_return

  case runtime.Type_Info_Float:
    switch f in a {
    case f16:
      io.write_f16(w, f) or_return
    case f32:
      io.write_f32(w, f) or_return
    case f64:
      io.write_f64(w, f) or_return
    case:
      return .Unsupported_Type
    }

  case runtime.Type_Info_Complex:
    r, i: f64
    switch z in a {
    case complex32:
      r, i = f64(real(z)), f64(imag(z))
    case complex64:
      r, i = f64(real(z)), f64(imag(z))
    case complex128:
      r, i = f64(real(z)), f64(imag(z))
    case:
      return .Unsupported_Type
    }

    io.write_byte(w, '[') or_return
    io.write_f64(w, r) or_return
    io.write_string(w, ", ") or_return
    io.write_f64(w, i) or_return
    io.write_byte(w, ']') or_return

  case runtime.Type_Info_Quaternion:
    return .Unsupported_Type

  case runtime.Type_Info_String:
    switch s in a {
    case string:
      io.write_quoted_string(w, s, '"', nil, true) or_return
    case cstring:
      io.write_quoted_string(w, string(s), '"', nil, true) or_return
    }

  case runtime.Type_Info_Boolean:
    val: bool
    switch b in a {
    case bool:
      val = bool(b)
    case b8:
      val = bool(b)
    case b16:
      val = bool(b)
    case b32:
      val = bool(b)
    case b64:
      val = bool(b)
    }
    io.write_string(w, val ? "true" : "false") or_return

  case runtime.Type_Info_Any:
    return .Unsupported_Type

  case runtime.Type_Info_Type_Id:
    return .Unsupported_Type

  case runtime.Type_Info_Pointer:
    ptr := a.(rawptr)


    if ptr == nil {
      io.write_string(w, "null") or_return
    } else {
      return .Unsupported_Type
    }

  case runtime.Type_Info_Multi_Pointer:
    return .Unsupported_Type

  case runtime.Type_Info_Soa_Pointer:
    return .Unsupported_Type

  case runtime.Type_Info_Procedure:
    return .Unsupported_Type

  case runtime.Type_Info_Parameters:
    return .Unsupported_Type

  case runtime.Type_Info_Simd_Vector:
    return .Unsupported_Type

  case runtime.Type_Info_Matrix:
    return .Unsupported_Type

  case runtime.Type_Info_Bit_Field:
    return .Unsupported_Type

  case runtime.Type_Info_Array:
    json.opt_write_start(w, opt, '[') or_return
    for i in 0 ..< info.count {
      json.opt_write_iteration(w, opt, i == 0) or_return
      data := uintptr(v.data) + uintptr(i * info.elem_size)
      marshal_to_writer(w, any{rawptr(data), info.elem.id}, opt) or_return
    }
    json.opt_write_end(w, opt, ']') or_return

  case runtime.Type_Info_Enumerated_Array:
    index_type := reflect.type_info_base(info.index)
    enum_type := index_type.variant.(reflect.Type_Info_Enum)

    json.opt_write_start(w, opt, '{') or_return
    for i in 0 ..< info.count {
      value := cast(runtime.Type_Info_Enum_Value)i
      index, found := slice.linear_search(enum_type.values, value)
      if !found {
        continue
      }

      json.opt_write_iteration(w, opt, i == 0) or_return
      json.opt_write_key(w, opt, enum_type.names[index]) or_return
      data := uintptr(v.data) + uintptr(i * info.elem_size)
      marshal_to_writer(w, any{rawptr(data), info.elem.id}, opt) or_return
    }
    json.opt_write_end(w, opt, '}') or_return

  case runtime.Type_Info_Dynamic_Array:
    json.opt_write_start(w, opt, '[') or_return
    array := cast(^mem.Raw_Dynamic_Array)v.data
    for i in 0 ..< array.len {
      json.opt_write_iteration(w, opt, i == 0) or_return
      data := uintptr(array.data) + uintptr(i * info.elem_size)
      marshal_to_writer(w, any{rawptr(data), info.elem.id}, opt) or_return
    }
    json.opt_write_end(w, opt, ']') or_return

  case runtime.Type_Info_Slice:
    json.opt_write_start(w, opt, '[') or_return
    slice := cast(^mem.Raw_Slice)v.data
    for i in 0 ..< slice.len {
      json.opt_write_iteration(w, opt, i == 0) or_return
      data := uintptr(slice.data) + uintptr(i * info.elem_size)
      marshal_to_writer(w, any{rawptr(data), info.elem.id}, opt) or_return
    }
    json.opt_write_end(w, opt, ']') or_return

  case runtime.Type_Info_Map:
    m := (^mem.Raw_Map)(v.data)
    json.opt_write_start(w, opt, '{') or_return

    if m != nil {
      if info.map_info == nil {
        return .Unsupported_Type
      }
      map_cap := uintptr(runtime.map_cap(m^))
      ks, vs, hs, _, _ := runtime.map_kvh_data_dynamic(m^, info.map_info)

      if !opt.sort_maps_by_key {
        i := 0
        for bucket_index in 0 ..< map_cap {
          runtime.map_hash_is_valid(hs[bucket_index]) or_continue

          json.opt_write_iteration(w, opt, i == 0) or_return
          i += 1

          key := rawptr(
            runtime.map_cell_index_dynamic(ks, info.map_info.ks, bucket_index),
          )
          value := rawptr(
            runtime.map_cell_index_dynamic(vs, info.map_info.vs, bucket_index),
          )

          // check for string type
          {
            kv := any{key, info.key.id}
            kti := runtime.type_info_base(type_info_of(kv.id))
            ka := any{kv.data, kti.id}
            name: string

            #partial switch info in kti.variant {
            case runtime.Type_Info_String:
              switch s in ka {
              case string:
                name = s
              case cstring:
                name = string(s)
              }
              json.opt_write_key(w, opt, name) or_return
            case runtime.Type_Info_Integer:
              buf: [40]byte
              u := cast_any_int_to_u128(ka)
              name = strconv.write_bits_128(
                buf[:],
                u,
                10,
                info.signed,
                8 * kti.size,
                "0123456789",
                nil,
              )

              json.opt_write_key(w, opt, name) or_return
            case:
              return .Unsupported_Type
            }
          }

          marshal_to_writer(w, any{value, info.value.id}, opt) or_return
        }
      } else {
        Entry :: struct {
          key:   string,
          value: any,
        }

        // If we are sorting the map by key, then we temp alloc an array
        // and sort it, then output the result.
        sorted := make([dynamic]Entry, 0, map_cap, context.temp_allocator)
        for bucket_index in 0 ..< map_cap {
          runtime.map_hash_is_valid(hs[bucket_index]) or_continue

          key := rawptr(
            runtime.map_cell_index_dynamic(ks, info.map_info.ks, bucket_index),
          )
          value := rawptr(
            runtime.map_cell_index_dynamic(vs, info.map_info.vs, bucket_index),
          )
          name: string

          // check for string type
          {
            kv := any{key, info.key.id}
            kti := runtime.type_info_base(type_info_of(kv.id))
            ka := any{kv.data, kti.id}

            #partial switch info in kti.variant {
            case runtime.Type_Info_String:
              switch s in ka {
              case string:
                name = s
              case cstring:
                name = string(s)
              }

            case:
              return .Unsupported_Type
            }
          }

          append(&sorted, Entry{key = name, value = any{value, info.value.id}})
        }

        slice.sort_by(
          sorted[:],
          proc(i, j: Entry) -> bool {return i.key < j.key},
        )

        for s, i in sorted {
          json.opt_write_iteration(w, opt, i == 0) or_return
          json.opt_write_key(w, opt, s.key) or_return
          marshal_to_writer(w, s.value, opt) or_return
        }
      }
    }

    json.opt_write_end(w, opt, '}') or_return

  case runtime.Type_Info_Union:
    if len(info.variants) == 0 || v.data == nil {
      io.write_string(w, "null") or_return
      return nil
    }

    tag_ptr := uintptr(v.data) + info.tag_offset
    tag_any := any{rawptr(tag_ptr), info.tag_type.id}

    tag: i64 = -1
    switch i in tag_any {
    case u8:
      tag = i64(i)
    case i8:
      tag = i64(i)
    case u16:
      tag = i64(i)
    case i16:
      tag = i64(i)
    case u32:
      tag = i64(i)
    case i32:
      tag = i64(i)
    case u64:
      tag = i64(i)
    case i64:
      tag = i64(i)
    case:
      panic("Invalid union tag type")
    }

    if !info.no_nil {
      if tag == 0 {
        io.write_string(w, "null") or_return
        return nil
      }
      tag -= 1
    }
    id := info.variants[tag].id
    return marshal_to_writer(w, any{v.data, id}, opt)

  case runtime.Type_Info_Enum:
    if !opt.use_enum_names || len(info.names) == 0 {
      return marshal_to_writer(w, any{v.data, info.base.id}, opt)
    } else {
      name, found := reflect.enum_name_from_value_any(v)
      if found {
        return marshal_to_writer(w, name, opt)
      } else {
        return marshal_to_writer(w, any{v.data, info.base.id}, opt)
      }
    }

  case runtime.Type_Info_Bit_Set:
    is_bit_set_different_endian_to_platform :: proc(
      ti: ^runtime.Type_Info,
    ) -> bool {
      if ti == nil {
        return false
      }
      t := runtime.type_info_base(ti)
      #partial switch info in t.variant {
      case runtime.Type_Info_Integer:
        switch info.endianness {
        case .Platform:
          return false
        case .Little:
          return ODIN_ENDIAN != .Little
        case .Big:
          return ODIN_ENDIAN != .Big
        }
      }
      return false
    }

    bit_data: u64
    bit_size := u64(8 * ti.size)

    do_byte_swap := is_bit_set_different_endian_to_platform(info.underlying)

    switch bit_size {
    case 0:
      bit_data = 0
    case 8:
      x := (^u8)(v.data)^
      bit_data = u64(x)
    case 16:
      x := (^u16)(v.data)^
      if do_byte_swap {
        x = bits.byte_swap(x)
      }
      bit_data = u64(x)
    case 32:
      x := (^u32)(v.data)^
      if do_byte_swap {
        x = bits.byte_swap(x)
      }
      bit_data = u64(x)
    case 64:
      x := (^u64)(v.data)^
      if do_byte_swap {
        x = bits.byte_swap(x)
      }
      bit_data = u64(x)
    case:
      panic("unknown bit_size size")
    }
    io.write_u64(w, bit_data) or_return
  }

  return
}
