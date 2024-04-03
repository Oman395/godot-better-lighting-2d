extends PointLight2D

var points: Array[Vector2] = [
	Vector2(50, 50),
	Vector2(1230, 50),
	Vector2(1230, 670),
	Vector2(1080, 670),
	Vector2(1080, 200),
	Vector2(200, 200),
	Vector2(200, 475),
	Vector2(740, 475),
	Vector2(740, 275),
	Vector2(540, 275),
	Vector2(540, 670),
	Vector2(50, 670),
	Vector2(50,50)
]

var pos: float = points.size() - 2
var lengths: Array[float]
var totalLength: float
var speed: float = 0.1

# Called when the node enters the scene tree for the first time.
func _ready():
	totalLength = 0.0;
	for i in range(points.size() - 1):
		lengths.push_back((points[i]).distance_to(points[i + 1]))
		totalLength += lengths[i]
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var p0 := points[floor(pos)]
	var p1 := points[ceil(pos)]
	position = (p0 * (1.0 - fmod(pos, 1.0)) + p1 * fmod(pos, 1.0))
	# rotation = atan2(position.y - 360, position.x - 630) + PI / 2.0
	pos += delta * (speed / (lengths[floor(pos)] / totalLength))
	pos = fmod(pos, points.size() - 1)
	pass
