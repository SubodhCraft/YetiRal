extends PathFollow3D

@export var raft_speed: float = 8.0
@export var is_active: bool = true

func _physics_process(delta):
    if not is_active:
        return
        
    # Move the raft forward along the curve
    progress += raft_speed * delta
    
    if progress_ratio >= 1.0:
        progress_ratio = 0.0
