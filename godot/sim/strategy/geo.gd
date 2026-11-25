class_name AbyssGeo
## Géométrie du globe (latitude/longitude en degrés, distances en km). Aucune dépendance au rendu.

const R := 6371.0

static func dist_km(a: Vector2, b: Vector2) -> float:
	var la1 := deg_to_rad(a.x)
	var la2 := deg_to_rad(b.x)
	var dla := la2 - la1
	var dlo := deg_to_rad(b.y - a.y)
	var h := sin(dla / 2) ** 2 + cos(la1) * cos(la2) * sin(dlo / 2) ** 2
	return 2.0 * R * asin(minf(1.0, sqrt(h)))

## Vecteur unitaire (repère du globe : Y vers le pôle Nord, longitude 0 vers +Z, 90° E vers +X).
static func to_vec(p: Vector2) -> Vector3:
	var la := deg_to_rad(p.x)
	var lo := deg_to_rad(p.y)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))

static func from_vec(v: Vector3) -> Vector2:
	var n := v.normalized()
	return Vector2(rad_to_deg(asin(clampf(n.y, -1.0, 1.0))), rad_to_deg(atan2(n.x, n.z)))

## Avance de `km` sur le grand cercle de a vers b (s'arrête sur b).
static func step_toward(a: Vector2, b: Vector2, km: float) -> Vector2:
	var d := dist_km(a, b)
	if d <= km or d < 0.001:
		return b
	var va := to_vec(a)
	var vb := to_vec(b)
	var ang := d / R
	var t := km / d
	var s := sin(ang)
	var v := va * (sin((1.0 - t) * ang) / s) + vb * (sin(t * ang) / s)
	return from_vec(v)

## Point à `km` de p dans la direction `bearing` (degrés, 0 = nord).
static func offset(p: Vector2, bearing: float, km: float) -> Vector2:
	var la := deg_to_rad(p.x)
	var lo := deg_to_rad(p.y)
	var br := deg_to_rad(bearing)
	var d := km / R
	var la2 := asin(sin(la) * cos(d) + cos(la) * sin(d) * cos(br))
	var lo2 := lo + atan2(sin(br) * sin(d) * cos(la), cos(d) - sin(la) * sin(la2))
	return Vector2(rad_to_deg(la2), wrapf(rad_to_deg(lo2), -180.0, 180.0))
