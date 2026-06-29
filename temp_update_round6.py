import re

# 1. READ TSCN
with open('scenes/gameplay/rounds/Round6_MemoryTiles.tscn', 'r', encoding='utf-8') as f:
    tscn = f.read()

# 2. UPDATE TILE POSITIONS & ADD NEW TILES
grid = []
for z in [-6, -2, 2, 6]:
    for x in [-6, -2, 2, 6]:
        grid.append((x, z))

new_tiles_str = ""

for i in range(1, 17):
    x, z = grid[i-1]
    
    # If the tile already exists (1 to 9), we just want to update its transform
    if i <= 9:
        # Match the transform of Tile i
        pattern = r'(\[node name="Tile' + str(i) + r'" type="AnimatableBody3D" parent="Tiles"\]\ntransform = Transform3D\([^)]*\))'
        
        replacement = '[node name="Tile' + str(i) + '" type="AnimatableBody3D" parent="Tiles"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, ' + str(x) + ', -0.25, ' + str(z) + ')'
        
        tscn = re.sub(pattern, replacement, tscn)
    else:
        # Generate new tile string
        new_tile = f'''
[node name="Tile{i}" type="AnimatableBody3D" parent="Tiles"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, -0.25, {z})
collision_layer = 1
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="Tiles/Tile{i}"]
shape = SubResource("Shape_Tile")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Tiles/Tile{i}"]
mesh = SubResource("Mesh_Tile")
surface_material_override/0 = SubResource("Mat_Tile")

[node name="Label3D" type="Label3D" parent="Tiles/Tile{i}"]
transform = Transform3D(1, 0, 0, 0, -4.37114e-08, 1, 0, -1, -4.37114e-08, 0, 0.26, 0)
text = ""
font_size = 64
outline_size = 12
visible = false
'''
        new_tiles_str += new_tile

tscn += new_tiles_str

# 3. ADD SWEEPER AND TEMPLE GEOMETRY
temple_str = '''
[node name="TempleWalls" type="CSGCombiner3D" parent="MapGeometry"]
use_collision = true

[node name="WallLeft" type="CSGBox3D" parent="MapGeometry/TempleWalls"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, 4, 0)
size = Vector3(2, 12, 32)
material = SubResource("Mat_Platform")

[node name="WallRight" type="CSGBox3D" parent="MapGeometry/TempleWalls"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, 4, 0)
size = Vector3(2, 12, 32)
material = SubResource("Mat_Platform")

[node name="WallBack" type="CSGBox3D" parent="MapGeometry/TempleWalls"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4, -16)
size = Vector3(26, 12, 2)
material = SubResource("Mat_Platform")

[node name="Pillar1" type="CSGCylinder3D" parent="MapGeometry/TempleWalls"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10, 4, -14)
radius = 1.5
height = 16.0
material = SubResource("Mat_Gold")

[node name="Pillar2" type="CSGCylinder3D" parent="MapGeometry/TempleWalls"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 10, 4, -14)
radius = 1.5
height = 16.0
material = SubResource("Mat_Gold")

[node name="Spikes" type="CSGBox3D" parent="MapGeometry"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -10, 0)
size = Vector3(30, 1, 30)
material = SubResource("Mat_Abyss")

[node name="Sweeper" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)

[node name="SweeperBase" type="CSGCylinder3D" parent="Sweeper"]
radius = 1.0
height = 2.0
material = SubResource("Mat_Platform")

[node name="SweeperArm" type="AnimatableBody3D" parent="Sweeper"]
collision_layer = 1
collision_mask = 2
sync_to_physics = false

[node name="MeshInstance3D" type="CSGBox3D" parent="Sweeper/SweeperArm"]
size = Vector3(20, 1, 1)
material = SubResource("Mat_Gold")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Sweeper/SweeperArm"]
shape = SubResource("Shape_Sweeper")
'''

tscn = tscn.replace(
'''[sub_resource type="BoxShape3D" id="Shape_Kill"]
size = Vector3(200, 8, 200)''',
'''[sub_resource type="BoxShape3D" id="Shape_Kill"]
size = Vector3(200, 8, 200)

[sub_resource type="BoxShape3D" id="Shape_Sweeper"]
size = Vector3(20, 1, 1)'''
)

tscn += temple_str

with open('scenes/gameplay/rounds/Round6_MemoryTiles.tscn', 'w', encoding='utf-8') as f:
    f.write(tscn)

# 4. READ SCRIPT
with open('scripts/rounds/Round6_MemoryTiles.gd', 'r', encoding='utf-8') as f:
    gd = f.read()

# 5. UPDATE SCRIPT
sweeper_vars = '''
@onready var sweeper: Node3D = $Sweeper
var sweeper_speed: float = 0.0
var time_passed: float = 0.0
'''
gd = gd.replace('var target_symbol: String = ""', sweeper_vars + '\nvar target_symbol: String = ""')

sweeper_logic = '''
	if current_state == State.FINISHED:
		sweeper_speed = 0.0
	
	if sweeper and sweeper_speed > 0.0:
		sweeper.rotation.y += sweeper_speed * delta
		
	time_passed += delta
	# Undulate tiles
	for i in range(tiles.size()):
		if tiles[i].visible and current_state != State.ELIMINATE:
			tiles[i].global_position.y = original_tile_y + sin(time_passed * 2.0 + i) * 0.2
'''
gd = gd.replace('\tif current_state == State.FINISHED:\n\t\treturn', sweeper_logic + '\n\tif current_state == State.FINISHED:\n\t\treturn')

gd = gd.replace('func _start_memorize() -> void:', 'func _start_memorize() -> void:\n\tsweeper_speed = 0.5 + (current_phase * 0.2)')
gd = gd.replace('func _start_target() -> void:', 'func _start_target() -> void:\n\tsweeper_speed = 0.8 + (current_phase * 0.3)')
gd = gd.replace('func _start_eliminate() -> void:', 'func _start_eliminate() -> void:\n\tsweeper_speed = 1.0 + (current_phase * 0.4)')
gd = gd.replace('tw.tween_property(tile, "global_position:y", original_tile_y - 30.0, 0.8)', 'tw.tween_property(tile, "global_position:y", tile.global_position.y - 30.0, 0.8)')

with open('scripts/rounds/Round6_MemoryTiles.gd', 'w', encoding='utf-8') as f:
    f.write(gd)

print("Scene and script updated successfully!")
