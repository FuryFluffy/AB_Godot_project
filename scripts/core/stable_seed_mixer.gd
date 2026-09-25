class_name StableSeedMixer
extends RefCounted


const FNV_OFFSET_BASIS_32: int = 2166136261
const FNV_PRIME_32: int = 16777619
const UINT32_MASK: int = 4294967295


static func make_seed(
	base_seed: int,
	namespace_id: StringName,
	stable_id: StringName
) -> int:
	var seed_material: String = (
		"%s|%d|%s"
		% [
			String(namespace_id),
			base_seed,
			String(stable_id),
		]
	)

	var hash_value: int = FNV_OFFSET_BASIS_32
	var bytes: PackedByteArray = (
		seed_material.to_utf8_buffer()
	)

	for byte_value: int in bytes:
		hash_value = hash_value ^ byte_value
		hash_value = (
			hash_value * FNV_PRIME_32
		) & UINT32_MASK

	return maxi(hash_value, 1)
