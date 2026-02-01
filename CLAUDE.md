## Claude Code Instructions

- Ask for sprites and tiles rather than trying to figure this out solo
- Only implement one feature at a time for testing and bug fixing
- Test thoroughly after each feature implementation
- Do not push to GitHub unless explicitly prompted by the user
- Follow IMPLEMENTATION_PLAN.md for feature sequencing
- After implementing a feature, update IMPLEMENTATION_PLAN.md checkboxes

---

## Architecture Quick Reference

### Autoloads (project.godot)
| Singleton   | File                               | Purpose                          |
|-------------|-------------------------------------|----------------------------------|
| GameManager | scripts/autoload/game_manager.gd   | Inventory, pause, game state     |
| SaveManager | scripts/autoload/save_manager.gd   | Save/load persistent data        |
| DropSystem  | scripts/autoload/drop_system.gd    | Weighted loot drops from enemies |
| FontManager | scripts/autoload/font_manager.gd   | Custom NES font rendering        |

### Collision Layers
| Layer | Used By                    |
|-------|----------------------------|
| 1     | World tiles (solid terrain)|
| 2     | Player                     |
| 4     | Enemies                    |

Pickups: `collision_layer = 0`, `collision_mask = 2` (detect player only).

### Screen Dimensions
- Viewport: 256x232px (256 game + 56 HUD)
- Screen: 256x176px (16x11 tiles)
- TILE_SIZE: 16px
- HUD_HEIGHT: 56px
- Starting screen: Vector2i(7, 7)

### Key Enums (GameManager)
```gdscript
enum Item { NONE, BOOMERANG, BOMBS, BOW, CANDLE, RECORDER, FOOD, LETTER, WAND }
enum Sword { NONE, WOODEN, WHITE, MAGICAL }
```

### Input Map
| Action   | Key         | Notes                    |
|----------|-------------|--------------------------|
| move_*   | WASD/Arrows | 4-directional            |
| attack   | X           | Sword (A button)         |
| use_item | Z           | Equipped item (B button) |
| pause    | Escape      | Pause menu toggle        |
| start    | Enter       | Start/confirm            |

### Debug Keys (when DEBUG_INPUTS_ENABLED = true)
1=+10 rupees, 2=+1 key, 3=+1 bomb, 4=all items, 5=+5 arrows, 6=+3 hearts, 7=teleport to merchant, 8=respawn enemies, 9=god mode toggle, 0=warp menu

---

## Hotspot Files

- `scripts/screen_manager.gd` — Enemy spawning per screen, cave entrances, screen transitions
- `scripts/player/player.gd` — Player mechanics, item use, combat

---

## Sprite Atlases

| Atlas                  | Contents                                    |
|------------------------|---------------------------------------------|
| adventure_enemies.png  | All enemy sprites (Octorok, Tektite, etc.)  |
| Player_Sprites.png     | Player walk/idle/attack all directions      |
| items_weapons.png      | Swords, items, pickups                      |
| enemy_death.png        | Universal death poof animation              |
| HUDs.png               | HUD elements, hearts, minimap               |
| NPCs.png               | Old man, merchant                           |
| overworld_tileset.png  | 16x6 grid of 16px tiles                     |
| Fonts.png              | Custom NES font characters                  |

---

## Recipe: Add a New Enemy

### 1. Scene (scenes/enemies/my_enemy.tscn)
Copy node tree from octorok.tscn or tektite.tscn:
```
CharacterBody2D (my_enemy.gd)
├── AnimatedSprite2D        # ShaderMaterial with enemy_palette_swap.gdshader
├── Hitbox (Area2D)         # collision_layer=4, collision_mask=0
│   └── CollisionShape2D
├── ContactDamage (Area2D)  # collision_layer=0, collision_mask=2
│   └── CollisionShape2D
└── CollisionShape2D        # collision_layer=4, collision_mask=1 (body)
```

### 2. Script (scripts/enemies/my_enemy.gd)
```gdscript
extends CharacterBody2D

const DAMAGE_FLASH_DURATION := 0.3
const DAMAGE_FLASH_SPEED := 15.0
const HEALTH := 2

var health := HEALTH
var is_dead := false
var damage_flash_timer := 0.0
var palette_frame := 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var contact_damage: Area2D = $ContactDamage

func _ready() -> void:
    hitbox.add_to_group("enemies")  # REQUIRED for sword detection
    contact_damage.body_entered.connect(_on_contact_damage_body_entered)

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    if damage_flash_timer > 0:
        damage_flash_timer -= delta
        palette_frame = 1 + int(damage_flash_timer * DAMAGE_FLASH_SPEED) % 3
        sprite.material.set_shader_parameter("palette_frame", palette_frame)
        if damage_flash_timer <= 0:
            palette_frame = 0
            sprite.material.set_shader_parameter("palette_frame", 0)
    # ... movement logic here ...

func take_damage(amount: int) -> void:  # REQUIRED - called by sword
    if is_dead:
        return
    health -= amount
    damage_flash_timer = DAMAGE_FLASH_DURATION
    if health <= 0:
        _die()

func _die() -> void:
    is_dead = true
    var death_effect = preload("res://scenes/enemies/enemy_death.tscn").instantiate()
    death_effect.global_position = global_position
    get_parent().add_child(death_effect)
    DropSystem.spawn_drop(global_position, get_parent())
    queue_free()

func _on_contact_damage_body_entered(body: Node2D) -> void:
    if body.name == "Player" and body.has_method("take_damage"):
        body.take_damage(1, global_position)
```

### 3. Register spawning in screen_manager.gd
Add spawn helper + entry in `_spawn_enemies_for_screen()`:
```gdscript
func _spawn_my_enemy(pos: Vector2) -> void:
    var enemy = preload("res://scenes/enemies/my_enemy.tscn").instantiate()
    enemy.global_position = pos
    enemies_container.add_child(enemy)

# In _spawn_enemies_for_screen():
if screen == Vector2i(X, Y):
    _spawn_my_enemy(Vector2(screen_left + 128, screen_top + 88))
```

### 4. Color variants
Use `@export var color` enum, set BEFORE add_child(). See tektite.gd for example.

### Enemy Checklist
- [ ] Hitbox Area2D added to "enemies" group in _ready()
- [ ] take_damage(amount: int) method exists
- [ ] ShaderMaterial with enemy_palette_swap.gdshader on AnimatedSprite2D
- [ ] Death spawns enemy_death.tscn + calls DropSystem.spawn_drop()
- [ ] ContactDamage calls body.take_damage(1, global_position)
- [ ] Randomize initial timers to prevent sync (randf() * COOLDOWN)
- [ ] Spawn function added to screen_manager.gd

---

## Recipe: Add a New Pickup

### 1. Script (scripts/pickups/my_pickup.gd)
```gdscript
extends Pickup
class_name MyPickup

func _apply_pickup(_player: Node2D) -> void:
    GameManager.add_rupees(1)  # or whatever effect
```
Base Pickup class handles despawn, blink, and player detection.

### 2. Scene (scenes/pickups/my_pickup.tscn)
```
Area2D (my_pickup.gd, extends Pickup)
├── Sprite2D              # region_enabled=true, region_rect for atlas
├── CollisionShape2D      # CircleShape2D radius 6.0
└── DespawnTimer (Timer)  # one_shot=true
```

### 3. Register in DropSystem (if droppable)
In `scripts/autoload/drop_system.gd`:
- Add to `PICKUP_SCENES`: `"my_pickup": preload("res://scenes/pickups/my_pickup.tscn")`
- Add to drop tables with weight value

---

## Recipe: Add Enemies to a Screen

In `scripts/screen_manager.gd`, inside `_spawn_enemies_for_screen()`:
```gdscript
if screen == Vector2i(col, row):
    _spawn_octorok(Vector2(screen_left + X, screen_top + Y))
```
- Screen origin = `Vector2(screen.x * 256, screen.y * 176)`
- Safe spawn area: X in 32..224, Y in 32..144 (avoid edges)
- Typical: 2-4 enemies per screen

---

## Recipe: Add a New B-Item (Usable Item)

### 1. Script (scripts/items/my_item.gd)
Follow the bomb pattern in `scripts/items/bomb.gd`.

### 2. Scene (scenes/items/my_item.tscn)
Node tree depends on item behavior. See bomb.tscn for a placed-object item.

### 3. Wire into player.gd
In `_use_equipped_item()` (line ~469), add a match case:
```gdscript
GameManager.Item.BOW:
    _shoot_arrow()
```
Then add the corresponding method below `_place_bomb()`.

### 4. Wire into game_manager.gd
- Item enum at line 25 already has entries (BOOMERANG, BOW, CANDLE, etc.)
- If your item needs ammo, use existing `use_arrow()` / `add_arrows()` pattern
- Call `GameManager.acquire_item(GameManager.Item.BOW)` when player obtains it

### 5. Wire into pause_menu.gd
Item should appear in inventory grid when owned. Check pause_menu.gd item display logic.

---

## When the User Reports a Bug

1. **Read the relevant script file(s) FIRST** before suggesting fixes
2. Check for these common issues:
   - Sprite region/offset calculations (sprites are 16x16 tiles)
   - Area2D group membership (enemies must be in "enemies" group via `add_to_group()` in `_ready()`)
   - Signal connections (check both emit and connect sides)
   - Collision layers/masks mismatch (see table above)
   - Preload paths (must start with `res://`)
   - Properties set AFTER `add_child()` instead of before
3. **Make ONE targeted fix at a time** — don't refactor surrounding code
4. After fixing, explain what to look for when testing
5. If the user provides Godot console output or screenshots, use those as primary evidence

---

## Branching Workflow (for parallel Claude instances)

If another Claude instance is running on this project:
1. Check branch: `git branch --show-current`
2. If on `main` and another instance is also on `main` editing the same files, create a branch:
   `git checkout -b feature/<descriptive-name>`
3. When done, tell the user the branch is ready to merge

If working alone on `main`, no branch needed.

---

## Testing After Implementation

After implementing a feature, recommend the following to the user:

### 1. Godot Console Output
Run the game from terminal to capture logs for debugging:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/michaelbegic/devprojects/super_adventure 2>&1 | tee /tmp/godot_output.txt
```
If the user reports a bug, ask them to share `/tmp/godot_output.txt` so you can read the exact errors and stack traces.

### 2. Screenshots
The user can paste screenshots or provide file paths to screenshots of visual bugs. Use these as primary evidence — they're faster and more accurate than text descriptions.

### 3. Automated Script Validation
A PostToolUse hook automatically runs Godot headless after `git commit` to catch GDScript parse errors. If errors are reported, fix them before continuing.

### 4. What to Tell the User to Test
After each feature, give the user a specific test checklist, e.g.:
- "Navigate to screen (6,7) and verify 4 red Tektites spawn"
- "Walk into an enemy and confirm you take damage with knockback"
- "Press Z to use the equipped item and confirm it fires"
- "Press Escape to open pause menu and verify the new item appears in inventory"

### 5. Debug Keys
Remind the user of debug keys when relevant:
- `1`=+10 rupees, `2`=+1 key, `3`=+1 bomb, `4`=all items, `5`=+5 arrows, `6`=+3 hearts, `7`=teleport to merchant, `8`=respawn enemies, `9`=god mode toggle, `0`=warp menu

---

## Common Gotchas

1. **Set properties BEFORE add_child()** — @export vars must be set before the node enters the tree, or _ready() uses defaults
2. **Sprite positioning is fiddly** — NES sprites use top-left origin. Test positions visually, expect iteration
3. **Palette swap shader must be unique** — ShaderMaterial on AnimatedSprite2D must be per-instance, not shared
4. **DespawnTimer must exist** — Named exactly "DespawnTimer" for the base Pickup class
5. **Player detection uses name** — `body.name == "Player"`, not group checks
6. **Bomb drops are gated** — Only drop if `GameManager.has_purchased_bombs == true`
7. **Custom drop tables** — Pass as third arg to `DropSystem.spawn_drop(pos, parent, table)`

---

## File Layout
```
scripts/
├── autoload/           # GameManager, SaveManager, DropSystem, FontManager
├── player/player.gd    # Player movement, combat, items
├── enemies/            # One .gd per enemy type
├── pickups/            # pickup.gd (base), one .gd per pickup type
├── items/              # Placeable items (bombs, sword pickups)
├── npcs/               # Old man, merchant
├── caves/              # Cave interior logic
├── ui/                 # HUD, pause menu, dialogue, title, game over, file select
└── screen_manager.gd   # Overworld tilemap, camera, transitions, enemy spawning

scenes/                 # Mirrors scripts/ structure, .tscn files

assets/
├── shaders/            # palette_swap, enemy_palette_swap, game_over_darken
├── sprites/*.png       # Sprite atlases (see table above)
├── tilesets/           # overworld_tileset.png, overworld.json
└── tile_collision_data.json
```
