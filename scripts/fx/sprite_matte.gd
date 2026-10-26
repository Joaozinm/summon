class_name SpriteMatte
## Cuts the flat dark backdrop out of the Muse's battle sprites (delivered as opaque WebP) at
## load time, in memory — the delivered files are used untouched.
## Flood fill from the image border through pixels close to the measured backdrop colour: dark
## areas *inside* a character (Kess's black outfit, Orin's robe) sit behind the bold ink outline
## and are never reached. Enclosed pockets of pure backdrop (between an arm and the body) are
## removed separately. Results are cached per path.

const WORK_HEIGHT := 256
const FILL_TOLERANCE := 0.045  # max per-channel distance from the backdrop treated as backdrop
const EDGE_RAMP := 0.10  # lighter-than-backdrop anti-aliased edge pixels fade in over this range
const HOLE_TOLERANCE := 0.02  # enclosed pockets must be this close to the backdrop...
const HOLE_MIN_PIXELS := 24  # ...and at least this big (working resolution) to be removed

static var _cache := {}


static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_height() > WORK_HEIGHT:
		var w := roundi(img.get_width() * float(WORK_HEIGHT) / img.get_height())
		img.resize(w, WORK_HEIGHT, Image.INTERPOLATE_LANCZOS)
	cut(img)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex


@warning_ignore("integer_division")
static func cut(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var px := img.get_data()
	var bg := _backdrop(img)
	var bg_lum := bg.get_luminance()

	var dist := PackedFloat32Array()
	dist.resize(n)
	for i in n:
		var o := i * 4
		dist[i] = maxf(maxf(absf(px[o] / 255.0 - bg.r), absf(px[o + 1] / 255.0 - bg.g)),
				absf(px[o + 2] / 255.0 - bg.b))

	# 1) Flood from every border pixel that looks like backdrop.
	var is_bg := PackedByteArray()
	is_bg.resize(n)
	var queue := PackedInt32Array()
	var seeds := PackedInt32Array()
	for x in w:
		seeds.append(x)
		seeds.append((h - 1) * w + x)
	for y in h:
		seeds.append(y * w)
		seeds.append(y * w + w - 1)
	for s in seeds:
		if is_bg[s] == 0 and dist[s] <= FILL_TOLERANCE:
			is_bg[s] = 1
			queue.append(s)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var y := i / w
		for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1,
				i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
			if j >= 0 and is_bg[j] == 0 and dist[j] <= FILL_TOLERANCE:
				is_bg[j] = 1
				queue.append(j)

	# 2) Enclosed pockets of pure backdrop.
	var seen := is_bg.duplicate()
	for start in n:
		if seen[start] != 0 or dist[start] > HOLE_TOLERANCE:
			continue
		var comp := PackedInt32Array([start])
		seen[start] = 1
		var k := 0
		while k < comp.size():
			var i := comp[k]
			k += 1
			var x := i % w
			var y := i / w
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1,
					i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if j >= 0 and seen[j] == 0 and dist[j] <= HOLE_TOLERANCE:
					seen[j] = 1
					comp.append(j)
		if comp.size() >= HOLE_MIN_PIXELS:
			for i in comp:
				is_bg[i] = 1

	# 3) Alpha. Edge pixels lighter than the backdrop are anti-aliasing: fade them in and remove
	# the backdrop's contribution. Darker ones are the ink outline and stay solid.
	for i in n:
		var o := i * 4
		if is_bg[i] == 1:
			px[o + 3] = 0
			continue
		var x := i % w
		var y := i / w
		var edge := (x > 0 and is_bg[i - 1] == 1) or (x < w - 1 and is_bg[i + 1] == 1) \
				or (y > 0 and is_bg[i - w] == 1) or (y < h - 1 and is_bg[i + w] == 1)
		if not edge:
			continue
		var c := Color8(px[o], px[o + 1], px[o + 2])
		if c.get_luminance() <= bg_lum:
			continue
		var a := clampf((dist[i] - FILL_TOLERANCE) / EDGE_RAMP, 0.15, 1.0)
		var clean := Color(bg.r + (c.r - bg.r) / a, bg.g + (c.g - bg.g) / a, bg.b + (c.b - bg.b) / a)
		px[o] = clampi(roundi(clean.r * 255.0), 0, 255)
		px[o + 1] = clampi(roundi(clean.g * 255.0), 0, 255)
		px[o + 2] = clampi(roundi(clean.b * 255.0), 0, 255)
		px[o + 3] = roundi(a * 255.0)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px)


@warning_ignore("integer_division")
## Per-channel median of a 2px frame around the image.
static func _backdrop(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var rs: Array[float] = []
	var gs: Array[float] = []
	var bs: Array[float] = []
	for x in w:
		for y in [0, 1, h - 2, h - 1]:
			var c := img.get_pixel(x, y)
			rs.append(c.r)
			gs.append(c.g)
			bs.append(c.b)
	for y in h:
		for x in [0, 1, w - 2, w - 1]:
			var c := img.get_pixel(x, y)
			rs.append(c.r)
			gs.append(c.g)
			bs.append(c.b)
	rs.sort()
	gs.sort()
	bs.sort()
	var m := rs.size() / 2
	return Color(rs[m], gs[m], bs[m])
