class_name WorldShaders
extends RefCounted
## Bewegung im Boden selbst — Wind über dem Gras, Licht auf dem Wasser.
##
## Beides läuft als Shader auf der jeweiligen Bodenschicht. Das ist hier die
## einzige vertretbare Bauform: der Boden sind vier `TileMapLayer` mit Millionen
## möglicher Kacheln. Jede einzeln zu animieren wäre nicht bezahlbar, ein Knoten
## je bewegtem Halm erst recht nicht. So kostet die Bewegung genau drei
## Materialien — unabhängig davon, wie gross die Welt ist.
##
## Zwei Entscheidungen stecken darin, und beide waren nötig:
##
## 1. Gerechnet wird im VERTEX-Schritt, nicht je Bildpunkt. Eine Kachel hat vier
##    Eckpunkte und 1024 Bildpunkte; die Welle im Fragment zu rechnen kostete das
##    Zweihundertfache. Gemessen (Software-Rasterizer, 1280 x 720): 13,8 ms je
##    Bild ohne Bewegung, 66 ms mit Bewegung im Fragment, wieder rund 14 ms mit
##    Bewegung im Vertex. Die Wellenlänge liegt bei mehreren hundert Bildpunkten,
##    die lineare Interpolation über eine 32er-Kachel sieht man nicht.
##
## 2. Verändert wird die HELLIGKEIT, nicht die Lage der Bildpunkte. Die Kacheln
##    kommen aus einem Atlas; ein verschobenes UV griffe in die Nachbarkachel im
##    Atlasbild und es entstünden Streifen fremder Farbe an jeder Kachelkante.
##    Eine wandernde Aufhellung liest sich als Böe über einem Feld und kann das
##    nicht.
##
## Es gibt bewusst kein `fragment()`: ohne eines nimmt Godot das voreingestellte
## `COLOR *= texture(TEXTURE, UV)` — genau das, was hier gebraucht wird.

## Windböen über dem Gras. Zwei Wellen mit verschiedener Richtung und Frequenz;
## eine einzelne ergäbe sichtbare Streifen statt Böen.
const GRASS := """
shader_type canvas_item;

uniform float strength = 1.0;
uniform float speed = 0.32;
uniform float scale = 0.011;
uniform float amount = 0.05;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float wave = sin(w.x * scale + TIME * speed)
		+ 0.6 * sin((w.x + w.y * 0.7) * scale * 1.7 - TIME * speed * 1.35);
	COLOR.rgb *= 1.0 + wave * amount * strength;
}
"""

## Eine Welle statt zweier: ruhiger, nicht billiger. Wer die Böen als unruhig
## empfindet, bekommt hier ein gleichmässiges Wehen.
const GRASS_SIMPLE := """
shader_type canvas_item;

uniform float strength = 1.0;
uniform float speed = 0.32;
uniform float scale = 0.011;
uniform float amount = 0.05;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	COLOR.rgb *= 1.0 + sin(w.x * scale + TIME * speed) * amount * strength;
}
"""

## Wasser: kein Abdunkeln, sondern wandernde helle Stellen — so wirkt es wie
## Licht auf einer Oberflaeche und nicht wie flackernde Farbe.
##
## ZWEI Wellen statt einer, und das ist der Punkt. Eine einzelne Welle laeuft
## als durchgehendes helles Band ueber die ganze Wasserflaeche: jeder Punkt auf
## derselben Linie wird im selben Augenblick hell, und ueber einen See hinweg
## sieht man einen Balken wandern. Wasser tut das nicht.
##
## Zwei Wellen mit ungleicher Richtung, Groesse und Geschwindigkeit ergeben ein
## Muster, das sich erst nach sehr langer Zeit wiederholt (die Frequenzen stehen
## bewusst in keinem einfachen Verhaeltnis). Multipliziert statt addiert: hell
## wird es nur, wo BEIDE Wellen gerade oben sind — daraus werden einzelne
## Glanzstellen, die aufleuchten und vergehen, statt eines Streifens.
const WATER := """
shader_type canvas_item;

uniform float strength = 1.0;
uniform float speed = 0.55;
uniform float scale = 0.016;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float a = sin(w.x * scale + w.y * scale * 0.6 + TIME * speed);
	float b = sin(w.x * scale * 0.43 - w.y * scale * 1.31 - TIME * speed * 0.67);
	float wave = max(a, 0.0) * max(b * 0.5 + 0.5, 0.0);
	COLOR.rgb += vec3(0.06, 0.085, 0.11) * wave * wave * strength;
}
"""

## Baut ein Material aus einem der Quelltexte oben.
static func make(source: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = source
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat

## Setzt die Stärke aller übergebenen Materialien.
static func set_strength(materials: Array, value: float) -> void:
	for m: ShaderMaterial in materials:
		if is_instance_valid(m):
			m.set_shader_parameter("strength", value)

## Welches Material gehört auf die Grasschicht?
##
## Bei „Aus" kommt NULL zurück und nicht ein Shader mit Stärke null: ein Shader
## mit Faktor null rechnet trotzdem. Ohne Material kostet die Stufe „Aus"
## wirklich nichts — sonst wäre sie ein Versprechen, das sie nicht hält.
static func grass_for(level: int, simple: ShaderMaterial, full: ShaderMaterial) -> ShaderMaterial:
	if level <= 0:
		return null
	return simple if level == 1 else full
