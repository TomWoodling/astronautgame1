extends Node3D

func _ready() -> void:
	# Create a simple platform course
	var platforms = [
		{position = Vector3(0, 0, 0), size = Vector3(10, 1, 10)},
		{position = Vector3(8, 2, 0), size = Vector3(3, 1, 3)},
		{position = Vector3(16, 4, 0), size = Vector3(3, 1, 3)},
		{position = Vector3(16, 4, 8), size = Vector3(3, 1, 3)},
		{position = Vector3(8, 6, 8), size = Vector3(3, 1, 3)}
	]
	
	for platform in platforms:
		var mesh = BoxMesh.new()
		mesh.size = platform.size
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.position = platform.position
		
		var static_body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = platform.size
		collision.shape = shape
		
		static_body.add_child(collision)
		mesh_instance.add_child(static_body)
		add_child(mesh_instance)
