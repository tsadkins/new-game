extends Node

# This script registers all items into the database automatically when game starts

func _ready():
    register_all_items()

func register_all_items():
    # === WEAPONS ===
    
    var iron_sword = ItemDefinition.new()
    iron_sword.name = "Iron Sword"
    iron_sword.description = "A basic iron sword for combat"
    iron_sword.type = "weapon"
    iron_sword.rarity = "common"
    iron_sword.base_damage = 15.0
    iron_sword.weight = 3.0
    iron_sword.icon_path = ""
    
    var steel_sword = ItemDefinition.new()
    steel_sword.name = "Steel Sword"
    steel_sword.description = "A stronger sword made of steel"
    steel_sword.type = "weapon"
    steel_sword.rarity = "uncommon"
    steel_sword.base_damage = 25.0
    steel_sword.weight = 4.0
    
    var dagger_rapid = ItemDefinition.new()
    dagger_rapid.name = "Rapid Dagger"
    dagger_rapid.description = "A quick, light dagger for fast attacks"
    dagger_rapid.type = "weapon"
    dagger_rapid.rarity = "common"
    dagger_rapid.base_damage = 12.0
    dagger_rapid.weight = 1.5
    dagger_rapid.equip_slot = "main_hand"
    
    # === ARMOR ===
    
    var helmet_iron = ItemDefinition.new()
    helmet_iron.name = "Iron Helmet"
    helmet_iron.description = "Basic iron helmet for head protection"
    helmet_iron.type = "armor"
    helmet_iron.rarity = "common"
    helmet_iron.defense = 5
    helmet_iron.weight = 2.0
    helmet_iron.equip_slot = "head"
    
    var chestplate_chain = ItemDefinition.new()
    chestplate_chain.name = "Chainmail Chestplate"
    chestplate_chain.description = "Light armor made of chain links"
    chestplate_chain.type = "armor"
    chestplate_chain.rarity = "uncommon"
    chestplate_chain.defense = 12
    chestplate_chain.weight = 6.0
    chestplate_chain.equip_slot = "chest"
    
    # === CONSUMABLES ===
    
    var potion_health_small = ItemDefinition.new()
    potion_health_small.name = "Health Potion (Small)"
    potion_health_small.description = "Restores a small amount of health"
    potion_health_small.type = "consumable"
    potion_health_small.rarity = "common"
    potion_health_small.health_restore = 30.0
    potion_health_small.stack_size = 5
    potion_health_small.sell_value = 5.0
    
    var potion_mana = ItemDefinition.new()
    potion_mana.name = "Mana Potion"
    potion_mana.description = "Restores mana for spellcasting"
    potion_mana.type = "consumable"
    potion_mana.rarity = "common"
    potion_mana.mana_restore = 40.0
    potion_mana.stack_size = 3
    potion_mana.sell_value = 8.0
    
    var bread = ItemDefinition.new()
    bread.name = "Bread"
    bread.description = "Simple bread that restores a bit of health"
    bread.type = "consumable"
    bread.rarity = "common"
    bread.health_restore = 15.0
    bread.weight = 0.5
    bread.stack_size = 99
    bread.sell_value = 2.0
    
    # === REGISTER ALL ITEMS TO DATABASE ===
    
    ItemDatabase.register_item(iron_sword)
    ItemDatabase.register_item(steel_sword)
    ItemDatabase.register_item(dagger_rapid)
    ItemDatabase.register_item(helmet_iron)
    ItemDatabase.register_item(chestplate_chain)
    ItemDatabase.register_item(potion_health_small)
    ItemDatabase.register_item(potion_mana)
    ItemDatabase.register_item(bread)
    
    # === PRINT CONFIRMATION TO CONSOLE ===
    
    print("=== Items Registered Successfully ===")
    var all_items = ItemDatabase.get_all_items()
    for item in all_items:
        print(item.name, "-", item.type, "-", item.rarity)
