package wren

import "core:mem"

MIN_CAPACITY     :: 16  // Initial and minimum capacity of a non-empty list or map objects
GROW_FACTOR      :: 2   // The rate at which a collection's capacity grows when the size exceeds the current capacity
MAP_LOAD_PERCENT :: 75  // The maximum percentage of map entries that can be illed before the map is grown. A lower load takes more memory but reduces collisions which makes lookup faster


Map_Entry :: struct {
	key  : Value,   // The entry's key, or UNDEFINED_VAL if the entry is not in use
	value: Value,   // The value associated with the key. If the key is UNDEFINED_VAL, this will be false to indicate an open available entry or true to indicate a tombstone -- an entry that has previously in use but was then deleted
}



new_map :: proc(vm: ^VM) -> ^Map {
	m := vm_allocate(vm, Map)
	object_init(vm, &m.obj, .Map, vm.map_class)
	m.entries = nil
	return m
}

@private
hash_bits :: #force_inline proc "contextless" (hash: u64) -> u32 {
	hash := hash
	hash  = ~hash + (hash << 18)
	hash  = hash ~ (hash >> 31)
	hash  = hash * 21
	hash  = hash ~ (hash >> 11)
	hash  = hash + (hash << 6)
	hash  = hash ~ (hash >> 22)
	return u32(hash & 0x3fffffff)
}

@private
hash_number :: #force_inline proc "contextless" (num: f64) -> u32 {
	return hash_bits(transmute(u64)num)
}

@private
hash_object :: proc(object: ^Object) -> u32 {
	#partial switch object.type {
	case .Class:
		return hash_object(&object.class_obj.name.obj) // Classes just use their name
	case .Fn:
		// allow bare minimum non-closure functions so that we can use a map to find existing constants in a function's constant table. This is only used internally. 
		// Since user code never sees a non-closure function, they cannot use them as map keys
		fn := cast(^Fn)object
		return hash_number(cast(f64)fn.arity) ~ hash_number(cast(f64)len(fn.code))
	case .Range:
		range := cast(^Range)object
		return hash_number(range.from) ~ hash_number(range.to)
	case .String:
		return (cast(^String)object).hash
	case: panic("Only immutable objects can be hashed.")
	}
	return 0
}

@private
hash_value :: proc(value: Value) -> u32 {
	when NAN_TAGGING {
		if value_is_obj(value) do return hash_object(value_as_object(value))
		return hash_bits(value)
	} else {
		#panic("Unimplemented hash_value for !NAN_TAGGING")
	}
}

// Note(Dragos): capacity is basically len(entries)

// Looks for an entry with [key] in an array of [capacity] [entries].
//
// If found, sets [result] to point to it and returns `true`. Otherwise,
// returns `false` and points [result] to the entry where the key/value pair
// should be inserted.
@private
find_entry :: proc(entries: []Map_Entry, key: Value) -> (result: ^Map_Entry, found: bool) {
	capacity := cast(u32)len(entries)
	if capacity == 0 do return

	// Figure out where to insert it in the table. Use open addressing and
  	// basic linear probing.
	start_index := hash_value(key) % capacity
	index := start_index

	// If we pass a tombstone and don't end up finding the key, its entry will
  	// be re-used for the insert.
	tombstone: ^Map_Entry

	for { // Note(Dragos): This should be a do-while
		entry := &entries[index]
		if value_is_undefined(entry.key) {
			// if we found an empty slot, the key is not in the table. 
			// If we found a slot that contains a deleted key, we have to keep looking
			if value_is_false(entry.value) {
			// We found an empty slot, so we've reached the end of the probe
			// sequence without finding the key. If we passed a tombstone, then
			// that's where we should insert the item, otherwise, put it here at
			// the end of the sequence.
				result = tombstone if tombstone != nil else entry
				return result, false
			} else {
				// We found a tombstone. We need to keep looking in case the key is
				// after it, but we'll use this entry as the insertion point if the
				// key ends up not being found.
				if tombstone == nil do tombstone = entry
			}
		} else if values_equal(entry.key, key) {
			// We found the key
			result = entry
			found = true
			return result, found
		}
		index = (index + 1) % capacity // try the next slot
		if index == start_index do break // Walk the probe sequence until we've tried every slot
	}

	// If we get here, the table is full of tombstones, return the first one we found
	assert(tombstone != nil, "Map should have tombstones or empty entries")
	result = tombstone
	found = false
	return result, found
}

// Inserts [key] and [value] in the array of [entries] with the given
// [capacity].
//
// Returns `true` if this is the first time [key] was added to the map.
@private
insert_entry :: proc(entries: []Map_Entry, key, value: Value) -> bool {
	assert(entries != nil, "Should ensure capacity before inserting")
	
	if entry, found := find_entry(entries, key); found {
		// Already present, so just replace the value
		entry.value = value
		return false
	} else {
		entry.key = key
		entry.value = value
		return true
	}
}

// Update [map] entry array to [capacity]
@private
resize_map :: proc(vm: ^VM, m: ^Map, capacity: u32) {
	entries := make([]Map_Entry, capacity, vm.config.allocator)
	for &entry in entries {
		entry.key = UNDEFINED_VAL
		entry.value = FALSE_VAL
	}
	for entry in m.entries {
		if value_is_undefined(entry.key) do continue
		insert_entry(entries, entry.key, entry.value)
	}
	delete(m.entries, vm.config.allocator)
	m.entries = entries
}

map_get :: proc(m: ^Map, key: Value) -> Value {
	if entry, found := find_entry(m.entries, key); found do return entry.value
	return UNDEFINED_VAL
}

map_set :: proc(vm: ^VM, m: ^Map, key, value: Value) {
	if m.count + 1 > len(m.entries) * MAP_LOAD_PERCENT / 100 {
		capacity := len(m.entries) * GROW_FACTOR
		if capacity < MIN_CAPACITY do capacity = MIN_CAPACITY
		resize_map(vm, m, cast(u32)capacity)
	}

	if insert_entry(m.entries, key, value) {
		m.count += 1
	}
}

map_clear :: proc(vm: ^VM, m: ^Map) {
	delete(m.entries, vm.config.allocator)
	m.entries = nil
	m.count   = 0
}

map_remove_key :: proc(vm: ^VM, m: ^Map, key: Value) -> Value {
	entry, found := find_entry(m.entries, key)
	if !found do return NULL_VAL
	// Remove the entry from the map. Set this value to true, which marks it as a
	// deleted slot. When searching for a key, we will stop on empty slots, but
	// continue past deleted slots.
	value := entry.value
	entry.key = UNDEFINED_VAL
	entry.value = TRUE_VAL
	if value_is_obj(value) do push_root(vm, value_as_object(value))
	defer if value_is_obj(value) do pop_root(vm)
	m.count -= 1
	if m.count == 0 do map_clear(vm, m)
	else if len(m.entries) > MIN_CAPACITY && m.count < len(m.entries) / GROW_FACTOR * MAP_LOAD_PERCENT / 100 {
		capacity := len(m.entries) / GROW_FACTOR
		if capacity < MIN_CAPACITY do capacity = MIN_CAPACITY
		resize_map(vm, m, cast(u32)capacity)
	}
	return value
	
}