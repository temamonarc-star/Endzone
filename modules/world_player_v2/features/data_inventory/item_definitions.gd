extends RefCounted
class_name ItemDefinitionsV2
## ItemDefinitions - Определения категорий и предметов (ENDZONE RP)

enum ItemCategory {
	NONE,
	TOOL,
	BUCKET,
	RESOURCE,
	BLOCK,
	OBJECT,
	PROP,
	SHOVEL,
	VEHICLE
}

static func get_test_items() -> Array[Dictionary]:
	return [
		{
			"id": "pickaxe_stone",
			"name": "Каменная кирка",
			"category": ItemCategory.TOOL,
			"damage": 2,
			"mining_strength": 1.5,
			"stack_size": 1
		},
		{
			"id": "axe_stone",
			"name": "Каменный топор",
			"category": ItemCategory.TOOL,
			"damage": 3,
			"mining_strength": 0.5,
			"stack_size": 1
		},
		{
			"id": "bucket_water",
			"name": "Ведро воды",
			"category": ItemCategory.BUCKET,
			"damage": 1,
			"mining_strength": 0.0,
			"stack_size": 1
		},
		{
			"id": "shovel",
			"name": "Лопата",
			"category": ItemCategory.TOOL,
			"damage": 2,
			"mining_strength": 1.5,
			"stack_size": 1
		},
		{
			"id": "dirt",
			"name": "Земля",
			"category": ItemCategory.RESOURCE,
			"damage": 0,
			"mining_strength": 0.0,
			"stack_size": 64,
			"mat_id": 0
		},
		{
			"id": "block_cube",
			"name": "Деревянный куб",
			"category": ItemCategory.BLOCK,
			"block_id": 1,
			"damage": 0,
			"mining_strength": 0.0,
			"stack_size": 64
		},
		{
			"id": "block_ramp",
			"name": "Рампа",
			"category": ItemCategory.BLOCK,
			"block_id": 2,
			"damage": 0,
			"mining_strength": 0.0,
			"stack_size": 64
		},
		{
			"id": "object_door",
			"name": "Деревянная дверь",
			"category": ItemCategory.OBJECT,
			"object_id": 4,
			"damage": 0,
			"mining_strength": 0.0,
			"stack_size": 16
		},
		{
			"id": "object_cardboard",
			"name": "Картонная коробка",
			"category": ItemCategory.OBJECT,
			"object_id": 1,
			"damage": 0,
			"mining_strength": 0.0,
			"stack_size": 16
		},
		{
			"id": "car_keys",
			"name": "Ключи от авто",
			"category": ItemCategory.VEHICLE,
			"damage": 0,
			"mining_strength": 0.0,
			"stack_size": 1,
			"vehicle_scene": "res://world_vehicles/drivable_car.tscn"
		}
	]

static func get_category_name(category: ItemCategory) -> String:
	match category:
		ItemCategory.NONE: return "Пусто"
		ItemCategory.TOOL: return "Инструмент"
		ItemCategory.BUCKET: return "Ёмкость"
		ItemCategory.RESOURCE: return "Ресурс"
		ItemCategory.BLOCK: return "Блок"
		ItemCategory.OBJECT: return "Объект"
		ItemCategory.PROP: return "Предмет"
		ItemCategory.SHOVEL: return "Лопата"
		ItemCategory.VEHICLE: return "Транспорт"
	return "Неизвестно"

static func is_build_category(category: ItemCategory) -> bool:
	return category in [ItemCategory.BLOCK, ItemCategory.OBJECT, ItemCategory.PROP]

static func is_build_item(item: Dictionary) -> bool:
	var category = item.get("category", ItemCategory.NONE)
	if item.get("is_firearm", false):
		return false
	return is_build_category(category)

static func is_play_category(category: ItemCategory) -> bool:
	return category in [ItemCategory.NONE, ItemCategory.TOOL, ItemCategory.BUCKET, ItemCategory.RESOURCE, ItemCategory.SHOVEL, ItemCategory.VEHICLE]

static func get_fists_item() -> Dictionary:
	return {
		"id": "fists",
		"name": "Кулаки",
		"category": ItemCategory.NONE,
		"damage": 1,
		"mining_strength": 1.0,
		"stack_size": 1
	}

static func get_terrain_resources() -> Dictionary:
	return {
		0: {"id": "res_grass", "name": "Трава", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 0},
		1: {"id": "res_stone", "name": "Камень", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 1},
		2: {"id": "res_ore", "name": "Руда", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 2},
		3: {"id": "res_sand", "name": "Песок", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 3},
		4: {"id": "res_gravel", "name": "Гравий", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 4},
		5: {"id": "res_snow", "name": "Снег", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 5},
		9: {"id": "res_granite", "name": "Гранит", "category": ItemCategory.RESOURCE, "stack_size": 64, "mat_id": 9},
	}

static func get_vegetation_resources() -> Dictionary:
	return {
		"wood": {"id": "veg_wood", "name": "Древесина", "category": ItemCategory.BLOCK, "block_id": 1, "stack_size": 64},
		"fiber": {"id": "veg_fiber", "name": "Растительное волокно", "category": ItemCategory.RESOURCE, "stack_size": 64},
		"rock": {"id": "veg_rock", "name": "Булыжник", "category": ItemCategory.RESOURCE, "stack_size": 64},
	}

static func get_vegetation_resource(veg_type: String) -> Dictionary:
	var resources = get_vegetation_resources()
	if resources.has(veg_type):
		return resources[veg_type].duplicate()
	return {}

static func get_resource_for_material(mat_id: int) -> Dictionary:
	var base_mat_id = mat_id % 100 if mat_id >= 100 else mat_id
	var resources = get_terrain_resources()
	if resources.has(base_mat_id):
		return resources[base_mat_id].duplicate()
	return resources[1].duplicate()

static func get_item_for_block(block_id: int) -> Dictionary:
	var items = get_test_items()
	for item in items:
		if item.get("category") == ItemCategory.BLOCK and item.get("block_id") == block_id:
			return item.duplicate()
	return {}

static func get_heavy_pistol_definition() -> Dictionary:
	return {
		"id": "heavy_pistol",
		"name": "Тяжёлый пистолет",
		"category": ItemCategory.PROP,
		"is_firearm": true,
		"damage": 5,
		"range": 50.0,
		"stack_size": 1,
		"scene": "res://models/pistol/heavy_pistol_physics.tscn"
	}

static func get_car_keys_definition() -> Dictionary:
	return {
		"id": "car_keys",
		"name": "Ключи от авто",
		"category": ItemCategory.VEHICLE,
		"damage": 0,
		"mining_strength": 0.0,
		"stack_size": 1,
		"vehicle_scene": "res://world_vehicles/drivable_car.tscn"
	}
