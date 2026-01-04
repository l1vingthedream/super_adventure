# Super Adventure - Implementation Plan

A spiritual successor to the original Legend of Zelda, built with Godot 4.x.

---

## Phase 1: Core Player Mechanics

### 1.1 Player Character
- [x] Create Player scene with AnimatedSprite2D
- [x] 4-directional movement (up, down, left, right)
- [x] Sprite animations: idle, walk (4 directions each)
- [ ] Sprite animations: attack (4 directions)
- [x] Player collision shape (hitbox)
- [x] Movement speed matching NES Zelda feel (~90 pixels/sec)

### 1.2 Screen Transitions
- [x] Detect when player reaches screen edge
- [x] Lock player input during transition
- [x] Smooth camera scroll to adjacent screen
- [x] Reposition player on new screen edge
- [x] Screen boundary collision (prevent walking off-map)

### 1.3 Collision System
- [ ] Implement tile-based collision from tilemap
- [ ] Mark solid tiles (rocks, water, walls, trees)
- [ ] Create collision layer in TileSet
- [ ] Player-to-tile collision detection

---

## Phase 2: Combat Foundation

### 2.1 Basic Sword Attack
- [ ] Sword hitbox (appears in front of player)
- [ ] Attack animation (sword swing)
- [ ] Attack cooldown timer
- [ ] Input handling (action button)
- [ ] Sword collision detection

### 2.2 Health System
- [ ] Player health (hearts) - start with 3
- [ ] Damage and invincibility frames
- [ ] Visual feedback (flash on damage)
- [ ] Death state and respawn logic
- [ ] Knockback on hit

### 2.3 Basic Enemy
- [ ] Create Enemy base class
- [ ] Simple enemy: Octorok-style (moves, shoots projectile)
- [ ] Enemy health and damage values
- [ ] Enemy-to-player collision (contact damage)
- [ ] Enemy death (disappear + drop)
- [ ] Enemy spawning per screen

---

## Phase 3: HUD & UI

### 3.1 Heads-Up Display
- [ ] Health display (heart containers)
- [ ] Rupee counter
- [ ] Key counter
- [ ] Current item slot (B button item)
- [ ] Minimap showing current screen position

### 3.2 Pause Menu
- [ ] Inventory grid display
- [ ] Item selection for B slot
- [ ] Collected items tracking
- [ ] Dungeon map display (when acquired)

### 3.3 Screen Overlays
- [ ] Game over screen
- [ ] Title screen
- [ ] File select / save slots

---

## Phase 4: Items & Inventory

### 4.1 Collectible Drops
- [ ] Rupees (green=1, blue=5, red=20)
- [ ] Hearts (restore health)
- [ ] Keys (dungeon doors)
- [ ] Bombs (ammo pickup)
- [ ] Arrows (ammo pickup)

### 4.2 Equipment Items
- [ ] Wooden Sword (starting weapon)
- [ ] White Sword (upgrade, requires 5 hearts)
- [ ] Magical Sword (upgrade, requires 12 hearts)
- [ ] Wooden Shield (block projectiles)
- [ ] Magical Shield (block more projectiles)

### 4.3 Usable Items (B Button)
- [ ] Bombs - place, timer, explosion, destroy cracked walls
- [ ] Bow & Arrow - ranged attack, costs rupee per shot
- [ ] Boomerang - stuns enemies, retrieves items
- [ ] Candle - burn bushes, light dark rooms
- [ ] Raft - cross water at dock tiles
- [ ] Ladder - cross single water/gap tiles
- [ ] Recorder/Flute - warp between dungeons
- [ ] Magic Wand - ranged magic attack

---

## Phase 5: Expanded Enemies

### 5.1 Overworld Enemies
- [ ] Octorok (red/blue) - walks, shoots rocks
- [ ] Tektite (red/blue) - hops randomly
- [ ] Leever (red/blue) - emerges from sand
- [ ] Peahat - flies, invulnerable while moving
- [ ] Moblin (red/blue) - walks, throws spears
- [ ] Armos - statue, activates when touched
- [ ] Lynel (red/blue) - walks, shoots sword beams
- [ ] Zora - emerges from water, shoots fireballs
- [ ] Rock - falls from mountains

### 5.2 Enemy Behaviors
- [ ] Pathfinding (simple 4-direction)
- [ ] Aggro range detection
- [ ] Varied movement patterns
- [ ] Projectile spawning
- [ ] Damage resistance by enemy type

### 5.3 Enemy Spawning System
- [ ] Screen-based enemy definitions
- [ ] Respawn when re-entering screen
- [ ] Enemy clear state (temporary)
- [ ] Spawn limits per screen

---

## Phase 6: Overworld Secrets

### 6.1 Hidden Caves
- [ ] Bombable walls (cracked rock tiles)
- [ ] Burnable bushes (specific bush tiles)
- [ ] Push-able blocks (Armos statues)
- [ ] Staircase entrances
- [ ] Cave interior scenes

### 6.2 Cave Types
- [ ] Shop - buy items with rupees
- [ ] Item gift - "It's dangerous to go alone"
- [ ] Heart container location
- [ ] Rupee room (pay or take)
- [ ] Hint NPC
- [ ] Gambling game

### 6.3 NPC Dialogue
- [ ] Dialogue box UI
- [ ] Text display system
- [ ] NPC interaction trigger
- [ ] Shop purchase logic

---

## Phase 7: Dungeon System

### 7.1 Dungeon Structure
- [ ] Separate tileset for dungeons
- [ ] Room-based dungeon maps
- [ ] Dungeon entrance/exit logic
- [ ] Room clear state tracking
- [ ] Dungeon-specific enemies

### 7.2 Dungeon Mechanics
- [ ] Locked doors (require keys)
- [ ] Shutter doors (open when enemies cleared)
- [ ] Bombable walls
- [ ] Push blocks (puzzle element)
- [ ] Dark rooms (require candle)
- [ ] Water/gaps (require ladder/raft)
- [ ] Trap rooms

### 7.3 Dungeon Items
- [ ] Compass (shows Triforce location)
- [ ] Map (reveals dungeon layout)
- [ ] Boss Key (big key for boss door)
- [ ] Dungeon-specific item reward

### 7.4 Dungeon Bosses
- [ ] Boss health bar
- [ ] Boss attack patterns
- [ ] Boss room lock-in
- [ ] Triforce piece reward
- [ ] Heart container drop

---

## Phase 8: Boss Encounters

### 8.1 Boss Base System
- [ ] Boss health display
- [ ] Phase-based behavior
- [ ] Vulnerability windows
- [ ] Death sequence

### 8.2 Dungeon Bosses (9 total)
- [ ] Aquamentus - dragon, shoots fireballs
- [ ] Dodongo - dinosaur, vulnerable to bombs
- [ ] Manhandla - plant, 4 destroyable heads
- [ ] Gleeok - multi-headed dragon
- [ ] Digdogger - shrinks with recorder
- [ ] Gohma - spider, vulnerable eye
- [ ] Boss remixes for later dungeons
- [ ] Ganon - final boss, invisible until hit

---

## Phase 9: Progression & Game Flow

### 9.1 Save System
- [ ] Save player position (last dungeon or start)
- [ ] Save inventory state
- [ ] Save heart containers collected
- [ ] Save Triforce pieces collected
- [ ] Save dungeon completion state
- [ ] 3 save file slots

### 9.2 Game Progression
- [ ] Track Triforce pieces (8 total)
- [ ] Death Mountain access (requires items)
- [ ] Second quest unlock (after completion)
- [ ] Power scaling (enemy difficulty)

### 9.3 World State
- [ ] Persistent item collection
- [ ] One-time secrets (heart containers)
- [ ] Shop inventory state
- [ ] NPC state changes

---

## Phase 10: Audio

### 10.1 Sound Effects
- [ ] Sword swing/hit
- [ ] Enemy damage/death
- [ ] Player damage
- [ ] Item pickup
- [ ] Door open
- [ ] Bomb explosion
- [ ] Low health warning beep
- [ ] Secret discovered jingle

### 10.2 Music
- [ ] Overworld theme
- [ ] Dungeon theme
- [ ] Boss battle theme
- [ ] Game over theme
- [ ] Title screen theme
- [ ] Ending theme
- [ ] Cave/shop theme

---

## Phase 11: Polish & Feel

### 11.1 Visual Effects
- [ ] Screen flash on damage
- [ ] Enemy death poof animation
- [ ] Sparkle on item pickup
- [ ] Sword beam particle effect
- [ ] Water animation
- [ ] Torch/fire animation

### 11.2 Game Feel
- [ ] Screen shake on bomb/boss
- [ ] Hitstop on damage (brief pause)
- [ ] Satisfying knockback
- [ ] Input buffering for attacks
- [ ] Coyote time for movement

### 11.3 Quality of Life
- [ ] Control remapping
- [ ] Difficulty options (optional)
- [ ] Speed run timer (optional)

---

## Technical Architecture

### Scene Structure
```
res://
├── scenes/
│   ├── main.tscn              # Game manager, screen stack
│   ├── overworld.tscn         # Overworld tilemap
│   ├── player/
│   │   └── player.tscn        # Player character
│   ├── enemies/
│   │   ├── enemy_base.tscn    # Base enemy
│   │   ├── octorok.tscn
│   │   └── ...
│   ├── items/
│   │   ├── pickup.tscn        # Base pickup
│   │   ├── heart.tscn
│   │   └── ...
│   ├── dungeons/
│   │   ├── dungeon_1.tscn
│   │   └── ...
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── pause_menu.tscn
│   │   └── dialogue_box.tscn
│   └── caves/
│       ├── shop.tscn
│       └── ...
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd    # Global game state
│   │   ├── save_manager.gd    # Save/load system
│   │   └── audio_manager.gd   # Sound/music control
│   ├── player/
│   │   ├── player.gd
│   │   ├── player_states.gd   # State machine
│   │   └── inventory.gd
│   ├── enemies/
│   │   ├── enemy_base.gd
│   │   └── ...
│   └── ...
└── assets/
    ├── sprites/
    ├── audio/
    └── tilesets/
```

### Autoload Singletons
- **GameManager** - game state, pause, screen management
- **SaveManager** - save/load, persistent data
- **AudioManager** - music/sfx playback, crossfade
- **EventBus** - signal-based communication

---

## Asset Requirements

### Sprites Needed
- Player (4 directions × 3 states × 3 frames minimum)
- Enemies (15+ types, each with animations)
- Items (20+ pickup/equipment sprites)
- NPCs (shopkeepers, old men)
- Bosses (8+ with attack animations)
- Effects (explosions, sparkles, etc.)

### Tilesets Needed
- Overworld (already have base)
- Dungeon interiors
- Cave interiors
- Boss rooms

### Audio Needed
- 15+ sound effects
- 6+ music tracks

---

## Milestones

### Milestone 1: Playable Demo
- Player movement and screen transitions
- Sword combat
- 2-3 enemy types
- Basic HUD
- One dungeon with boss

### Milestone 2: Core Loop
- Full inventory system
- All overworld enemies
- Multiple dungeon items
- Save/load working
- 3 dungeons playable

### Milestone 3: Content Complete
- All 9 dungeons
- All enemies and bosses
- All items
- Full overworld secrets
- Complete audio

### Milestone 4: Polish & Release
- Bug fixes
- Balance tuning
- Second quest
- Final polish
