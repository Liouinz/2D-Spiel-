class_name Fmt
extends RefCounted
## Zahlen für Anzeigen — an EINER Stelle.
##
## Die Leistungsanzeige und die Entwicklerinfo zeigen dieselben Messwerte, und
## sie hatten dafür dieselben vier Funktionen zeichengleich doppelt, samt
## kopierter Erklärung. Zwei Anzeigen derselben Zahl, die sich beim nächsten
## Umbau unterschiedlich runden, sind ein Fehler, den niemand sucht.
##
## Gemeinsame Regel für alles hier: **was die Engine nicht misst, bekommt einen
## Gedankenstrich, keine Zahl.** Auch eine glatte 0 gilt als „nicht gemessen" —
## manche Treiber füllen den Zähler nicht, und eine Null sähe aus wie ein
## echter Messwert.

const NOTHING := "—"

## Millisekunden.
static func ms(v: float) -> String:
	return NOTHING if v <= 0.0 else "%.2f ms" % v

## Ein Zählwert.
static func count(v: int) -> String:
	return NOTHING if v <= 0 else "%d" % v

## Speicher in Mebibyte.
static func mib(bytes: int) -> String:
	return NOTHING if bytes <= 0 else "%.0f MiB" % (float(bytes) / 1048576.0)

## Speicher in Gibibyte — für Werte, bei denen MiB vierstellig würde.
static func gib(bytes: int) -> String:
	return NOTHING if bytes <= 0 else "%.1f GiB" % (float(bytes) / 1073741824.0)
