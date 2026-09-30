#!/usr/bin/env python3
"""Draws art/diner.png: the diner pieces the Kenney packs don't have (grill,
fryer, jukebox, booths, neon...), as 16x16 pixel art in the same flat style,
seen from the front and a little above like the Kenney furniture.

Run from short_order/:  python3 tools/make_diner_sheet.py
Needs Pillow. Writes art/diner.png and prints the tile list, which must match
DINER in world/sprites.gd (name -> [column, row, width in tiles, height]).
"""
from PIL import Image

P = {
	"k": "#3d3846",  # outline
	"t": "#2b2a31", "T": "#4a4854",
	"h": "#6d7581", "g": "#9aa3ae", "G": "#c7ced6", "H": "#e8edf1",
	"w": "#f6f2ea", "W": "#dcd4c6",
	"r": "#d24b3e", "R": "#9a3129", "p": "#f08a7c",
	"y": "#f5c64f", "Y": "#c9952c", "q": "#fff4b8",
	"o": "#e9893b", "O": "#b8612a",
	"b": "#5ba9dc", "B": "#2f6e9e", "c": "#a8e1f5",
	"n": "#c48f5d", "N": "#8a5a35", "m": "#dfb584",
	"e": "#5ba251", "E": "#306d34", "l": "#a5e27c",
	"v": "#9b70c5", "s": "#f0c9a0", "S": "#c99a6e",
}
COLS = 16
tiles = {}          # name -> (col, row, w, h)
_cursor = [0, 0, 1]   # column, row, tallest piece in this row
sheet = Image.new("RGBA", (COLS * 17, 16 * 17), (0, 0, 0, 0))


class Canvas:
	def __init__(self, w=1, h=1):
		self.w, self.h = w * 16, h * 16
		self.im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))

	def px(self, x, y, c):
		if 0 <= x < self.w and 0 <= y < self.h and c:
			self.im.putpixel((x, y), _rgb(c))

	def rect(self, x0, y0, x1, y1, c):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				self.px(x, y, c)

	def box(self, x0, y0, x1, y1, fill, line="k"):
		self.rect(x0, y0, x1, y1, line)
		if x1 - x0 >= 2 and y1 - y0 >= 2:
			self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)

	def hline(self, x0, x1, y, c):
		self.rect(x0, y, x1, y, c)

	def vline(self, x, y0, y1, c):
		self.rect(x, y0, x, y1, c)

	def rows(self, x0, y0, art):
		"""Pixel art from strings; spaces and dots are see-through."""
		for dy, line in enumerate(art):
			for dx, ch in enumerate(line):
				if ch not in " .":
					self.px(x0 + dx, y0 + dy, ch)

	def disc(self, cx, cy, r, c):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y <= r * r + r * 0.6:
					self.px(cx + x, cy + y, c)


def _rgb(c):
	h = P.get(c, c).lstrip("#")
	return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def add(name, cv):
	w, h = cv.w // 16, cv.h // 16
	if _cursor[0] + w > COLS:
		_cursor[0] = 0
		_cursor[1] += _cursor[2]
		_cursor[2] = 1
	col, row = _cursor[0], _cursor[1]
	_cursor[2] = max(_cursor[2], h)
	for ty in range(h):
		for tx in range(w):
			tile = cv.im.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16))
			sheet.paste(tile, ((col + tx) * 17, (row + ty) * 17))
	tiles[name] = (col, row, w, h)
	_cursor[0] += w


def cabinet(cv, x0, x1, top="G", front="g", y_top=3, y_front=8, y_end=15):
	"""A steel kitchen unit: a light top surface and a front face below it."""
	cv.box(x0, y_top, x1, y_end, front)
	cv.rect(x0 + 1, y_top + 1, x1 - 1, y_front - 1, top)
	cv.hline(x0 + 1, x1 - 1, y_front, "h")
	cv.hline(x0 + 1, x1 - 1, y_top + 1, "H")
	cv.hline(x0 + 1, x1 - 1, y_end - 1, "h")


# ------------------------------------------------------------------ kitchen

def grill():
	cv = Canvas(2, 1)
	cabinet(cv, 0, 31)
	cv.rect(2, 5, 29, 7, "t")
	for x in range(3, 29, 2):
		cv.vline(x, 5, 7, "T")
	for x in (6, 13, 20, 26):
		cv.px(x, 6, "o")
		cv.px(x + 1, 7, "y")
	for x in (4, 12, 19, 27):
		cv.box(x - 1, 10, x + 1, 12, "T")
		cv.px(x, 11, "r")
	cv.hline(8, 23, 13, "G")
	return cv


def griddle():
	cv = Canvas(2, 1)
	cabinet(cv, 0, 31)
	cv.rect(2, 5, 29, 7, "T")
	cv.hline(2, 29, 5, "h")
	cv.rect(5, 6, 8, 6, "m")      # a pancake or two
	cv.rect(20, 6, 23, 7, "N")    # a patty
	for x in (5, 13, 21):
		cv.box(x - 1, 10, x + 1, 12, "T")
		cv.px(x, 11, "y")
	return cv


def fryer():
	cv = Canvas()
	cabinet(cv, 1, 14)
	cv.rect(3, 5, 7, 7, "Y")
	cv.rect(9, 5, 12, 7, "Y")
	cv.hline(3, 7, 5, "y")
	cv.hline(9, 12, 5, "y")
	cv.vline(5, 2, 5, "t")          # basket handles
	cv.vline(10, 2, 5, "t")
	cv.box(6, 10, 9, 12, "T")
	cv.px(7, 11, "r")
	return cv


def oven():
	cv = Canvas()
	cabinet(cv, 1, 14, y_front=6)
	for x in (4, 7, 10):
		cv.px(x, 4, "t")
		cv.px(x + 1, 4, "t")
	cv.box(3, 8, 12, 13, "t")
	cv.rect(4, 9, 11, 10, "o")
	cv.rect(4, 11, 11, 12, "O")
	cv.hline(5, 10, 7, "T")
	return cv


def fridge():
	cv = Canvas()
	cv.box(2, 0, 13, 15, "G")
	cv.rect(3, 1, 12, 2, "H")
	cv.vline(7, 3, 14, "h")
	cv.vline(8, 3, 14, "H")
	cv.vline(6, 6, 10, "h")
	cv.vline(9, 6, 10, "h")
	cv.hline(3, 12, 14, "g")
	cv.rect(3, 4, 5, 5, "b")      # a little temperature light
	return cv


def freezer():
	cv = Canvas()
	cv.box(1, 4, 14, 15, "w")
	cv.rect(2, 5, 13, 8, "c")
	cv.hline(2, 13, 5, "H")
	cv.hline(2, 13, 9, "W")
	cv.rect(6, 11, 9, 11, "g")
	cv.hline(2, 13, 14, "W")
	return cv


def ice():
	cv = Canvas()
	cv.box(2, 1, 13, 15, "G")
	cv.rect(3, 2, 12, 3, "H")
	cv.box(4, 5, 11, 9, "B")
	cv.rect(5, 6, 10, 8, "c")
	cv.px(6, 6, "w")
	cv.px(9, 7, "w")
	cv.hline(3, 12, 12, "h")
	return cv


def prep():
	cv = Canvas(2, 1)
	cabinet(cv, 0, 31)
	cv.box(3, 4, 12, 7, "m")      # cutting board
	cv.px(6, 5, "r")
	cv.px(8, 6, "e")
	cv.px(9, 5, "e")
	cv.rect(18, 4, 20, 6, "w")    # a bowl
	cv.hline(24, 28, 5, "h")      # a knife
	cv.px(29, 5, "N")
	for x in (8, 23):
		cv.hline(x - 2, x + 2, 11, "h")
	cv.vline(15, 9, 14, "h")
	return cv


def sink():
	cv = Canvas()
	cabinet(cv, 0, 15)
	cv.box(3, 4, 12, 7, "h")
	cv.rect(4, 5, 11, 6, "b")
	cv.vline(8, 1, 4, "g")
	cv.px(7, 1, "g")
	cv.hline(5, 10, 11, "h")
	return cv


def handsink():
	cv = Canvas()
	cv.box(3, 3, 12, 8, "w")
	cv.rect(5, 4, 10, 6, "c")
	cv.vline(8, 1, 3, "g")
	cv.vline(7, 9, 15, "G")
	cv.vline(8, 9, 15, "g")
	cv.px(12, 1, "e")             # the soap
	cv.px(12, 2, "e")
	return cv


def drinks():
	cv = Canvas()
	cv.box(2, 1, 13, 15, "r")
	cv.rect(3, 2, 12, 5, "R")
	cv.rows(4, 3, ["wwwwwwww"])
	cv.rect(3, 7, 12, 8, "G")
	for x in (4, 7, 10):
		cv.vline(x + 1, 8, 10, "h")
	cv.box(3, 11, 12, 14, "T")
	cv.px(5, 12, "c")
	cv.px(10, 12, "c")
	return cv


def pass_window():
	cv = Canvas(2, 1)
	cv.box(0, 5, 31, 11, "G")
	cv.hline(1, 30, 6, "H")
	cv.rect(1, 9, 30, 10, "g")
	cv.box(1, 0, 30, 3, "h")
	for x in (5, 15, 25):
		cv.rect(x, 3, x + 2, 4, "y")
		cv.px(x + 1, 4, "q")
	cv.rect(8, 7, 11, 8, "w")      # plates waiting
	cv.rect(19, 7, 22, 8, "w")
	return cv


def radio():
	cv = Canvas()
	cv.box(2, 6, 13, 13, "r")
	cv.rect(3, 7, 12, 8, "R")
	cv.box(3, 9, 7, 12, "T")
	for y in (10, 11):
		cv.hline(4, 6, y, "h")
	cv.disc(10, 10, 1, "y")
	cv.vline(12, 1, 6, "g")
	return cv


def bin_():
	cv = Canvas()
	cv.box(3, 3, 12, 15, "h")
	cv.rect(4, 4, 11, 5, "g")
	cv.box(2, 1, 13, 3, "g")
	for x in (5, 8, 11):
		cv.vline(x, 6, 13, "T")
	return cv


def trap():
	cv = Canvas()
	cv.box(4, 8, 11, 13, "m")
	cv.hline(5, 10, 10, "g")
	cv.vline(6, 9, 12, "g")
	cv.px(9, 11, "y")               # the cheese
	return cv


# ------------------------------------------------------------------ dining room

def booth(facing):
	"""A padded red booth seat. facing 2: sits facing down (back at the top)."""
	cv = Canvas()
	if facing == 2:
		cv.box(1, 1, 14, 6, "r")
		cv.hline(2, 13, 2, "p")
		cv.vline(5, 3, 5, "R")
		cv.vline(10, 3, 5, "R")
		cv.box(1, 6, 14, 12, "r")
		cv.hline(2, 13, 7, "p")
		cv.box(1, 12, 14, 15, "N")
	elif facing == 0:
		cv.box(1, 1, 14, 8, "r")
		cv.hline(2, 13, 2, "p")
		cv.box(1, 8, 14, 15, "r")
		cv.rect(2, 9, 13, 14, "R")
		cv.hline(2, 13, 9, "r")
		cv.vline(5, 10, 13, "k")
		cv.vline(10, 10, 13, "k")
	else:
		cv.box(1, 0, 6, 15, "r")
		cv.vline(2, 1, 14, "p")
		cv.box(6, 2, 14, 15, "r")
		cv.hline(7, 13, 3, "p")
		cv.box(6, 13, 14, 15, "N")
		cv.hline(2, 5, 7, "R")
	return cv


def stool():
	cv = Canvas()
	cv.vline(7, 7, 13, "g")
	cv.vline(8, 7, 13, "G")
	cv.hline(5, 10, 14, "h")
	cv.box(3, 2, 12, 7, "r")
	cv.hline(4, 11, 3, "p")
	cv.hline(4, 11, 6, "R")
	return cv


def counter():
	cv = Canvas()
	cv.box(0, 2, 15, 7, "w")
	cv.hline(1, 14, 3, "H")
	cv.hline(0, 15, 8, "G")
	cv.box(0, 8, 15, 15, "r")
	cv.hline(1, 14, 9, "H")
	cv.hline(1, 14, 12, "w")
	cv.hline(1, 14, 14, "R")
	return cv


def highchair():
	cv = Canvas()
	cv.vline(3, 7, 15, "N")
	cv.vline(12, 7, 15, "N")
	cv.box(3, 2, 12, 8, "m")
	cv.rect(4, 3, 11, 5, "y")
	cv.box(2, 7, 13, 9, "n")
	cv.hline(4, 11, 13, "N")
	return cv


def host():
	cv = Canvas()
	cv.box(3, 5, 12, 15, "N")
	cv.rect(4, 6, 11, 14, "n")
	cv.box(2, 2, 13, 5, "m")
	cv.rect(5, 3, 10, 4, "w")        # the seating chart
	cv.hline(5, 10, 9, "N")
	cv.hline(5, 10, 12, "N")
	return cv


def till():
	cv = Canvas()
	cv.box(2, 9, 13, 15, "N")
	cv.rect(3, 10, 12, 14, "n")
	cv.box(3, 3, 12, 9, "G")
	cv.rect(4, 4, 11, 5, "t")
	cv.rows(5, 4, ["y.y.y"])
	for y in (6, 7):
		for x in (4, 6, 8, 10):
			cv.px(x, y, "h")
	cv.box(4, 1, 8, 3, "h")
	cv.rect(5, 2, 7, 2, "l")
	return cv


def jukebox():
	cv = Canvas()
	cv.rows(0, 0, [
		"....kkkkkkkk....",
		"..kkoyyyyyyokk..",
		".koyqqqqqqqqyok.",
		".kyqbbbbbbbbqyk.",
		"kyqbcccccccbqyk.",
		"kyqbcwWwWwWcbqyk",
		"koqbcccccccbqok.",
		"korRRRRRRRRRrok.",
		"korRtTtTtTtRrok.",
		"korRTtTtTtTRrok.",
		"korRRRRRRRRRrok.",
		"korRyRyRyRyRrok.",
		"korRRRRRRRRRrok.",
		"kooRRRRRRRRRook.",
		"kNNNNNNNNNNNNNk.",
		".kkkkkkkkkkkkk..",
	])
	return cv


def gumball():
	cv = Canvas()
	cv.disc(8, 5, 4, "k")
	cv.disc(8, 5, 3, "c")
	for (x, y, c) in ((7, 4, "r"), (9, 5, "y"), (8, 6, "e"), (6, 6, "b"), (10, 3, "v"), (9, 7, "o")):
		cv.px(x, y, c)
	cv.px(7, 3, "w")
	cv.box(5, 9, 10, 12, "r")
	cv.px(7, 10, "G")
	cv.vline(8, 12, 14, "h")
	cv.hline(5, 10, 15, "h")
	return cv


def aquarium():
	cv = Canvas(2, 1)
	cv.box(1, 1, 30, 11, "b")
	cv.rect(2, 2, 29, 3, "c")
	cv.rect(2, 9, 29, 10, "m")
	for x in (5, 6, 24, 25):
		cv.vline(x, 5, 9, "e")
	cv.vline(7, 6, 9, "E")
	cv.rows(12, 5, ["oo.", ".ooo", "oo."])
	cv.rows(19, 6, ["y.", "yy", "y."])
	cv.px(10, 3, "w")
	cv.px(21, 4, "w")
	cv.box(1, 11, 30, 15, "N")
	cv.hline(2, 29, 12, "n")
	return cv


def rug():
	cv = Canvas(2, 1)
	cv.box(0, 3, 31, 13, "r")
	cv.box(2, 5, 29, 11, "y")
	cv.rect(3, 6, 28, 10, "r")
	for x in range(5, 28, 4):
		cv.px(x, 8, "y")
	return cv


# ------------------------------------------------------------------ walls

def neon():
	cv = Canvas()
	cv.box(0, 3, 15, 13, "t")
	cv.rows(2, 5, [
		"ppp.pp..ppp",
		"p...p.p..p.",
		"pp..ppp..p.",
		"p...p.p..p.",
		"ppp.p.p..p.",
	])
	cv.hline(2, 12, 11, "b")
	return cv


def records():
	cv = Canvas()
	cv.box(1, 2, 14, 13, "N")
	for (x, y, c) in ((5, 6, "r"), (10, 6, "y"), (7, 10, "b")):
		cv.disc(x, y, 2, "t")
		cv.px(x, y, c)
	return cv


def tin_sign():
	cv = Canvas()
	cv.box(1, 3, 14, 12, "y")
	cv.hline(2, 13, 4, "q")
	cv.box(3, 6, 12, 10, "r")
	cv.hline(5, 10, 8, "w")
	return cv


def trophy():
	cv = Canvas()
	cv.box(0, 11, 15, 13, "N")
	cv.rows(3, 2, [
		"kyyyyyyk.",
		"yyqyyyyy.",
		".yyyyyy..",
		"..yyyy...",
		"...yy....",
		"...YY....",
		"..YYYY...",
	])
	cv.rect(11, 7, 13, 10, "G")
	return cv


def clock():
	cv = Canvas()
	cv.disc(8, 8, 6, "G")
	cv.disc(8, 8, 5, "w")
	cv.vline(8, 4, 8, "t")
	cv.hline(8, 11, 8, "t")
	cv.px(8, 3, "r")
	cv.px(13, 8, "k")
	cv.px(3, 8, "k")
	return cv


def eotm():
	cv = Canvas()
	cv.box(2, 1, 13, 14, "y")
	cv.rect(4, 3, 11, 10, "c")
	cv.disc(7, 6, 2, "s")
	cv.rect(5, 9, 10, 10, "r")
	cv.hline(4, 11, 12, "Y")
	return cv


def whiteboard():
	cv = Canvas()
	cv.box(0, 2, 15, 13, "w")
	for y in (4, 6, 8, 10):
		cv.hline(2, 13, y, "W")
	cv.rows(2, 4, ["bb.rrr..bb"])
	cv.rows(3, 6, ["bbb..rr.e"])
	cv.rows(2, 8, ["e.bbbb.rr"])
	cv.hline(1, 14, 13, "g")
	return cv


def takeout():
	cv = Canvas()
	cv.box(1, 1, 14, 11, "G")
	cv.rect(2, 2, 13, 7, "c")
	cv.px(4, 3, "w")
	cv.box(0, 9, 15, 12, "g")
	cv.box(0, 13, 15, 15, "r")
	cv.hline(1, 14, 14, "p")
	return cv


def wall_art():
	cv = Canvas()
	cv.box(1, 2, 14, 13, "N")
	cv.rect(3, 4, 12, 11, "c")
	cv.rect(3, 9, 12, 11, "e")
	cv.disc(10, 6, 1, "y")
	return cv


# ------------------------------------------------------------------ staff room, restroom, outside

def coffee_maker():
	cv = Canvas()
	cv.box(3, 1, 12, 13, "t")
	cv.rect(4, 2, 11, 4, "T")
	cv.box(5, 8, 10, 12, "c")
	cv.rect(6, 10, 9, 11, "N")
	cv.px(10, 3, "r")
	cv.hline(2, 13, 14, "h")
	return cv


def tv():
	cv = Canvas()
	cv.box(1, 2, 14, 11, "t")
	cv.rect(2, 3, 13, 10, "B")
	cv.rect(3, 4, 7, 6, "b")
	cv.px(3, 4, "c")
	cv.vline(7, 12, 13, "h")
	cv.hline(4, 11, 14, "h")
	return cv


def lockers():
	cv = Canvas(2, 1)
	for i in range(4):
		x = i * 8
		cv.box(x, 0, x + 7, 15, "B")
		cv.hline(x + 1, x + 6, 1, "b")
		for y in (3, 4, 5):
			cv.hline(x + 2, x + 5, y, "t")
		cv.px(x + 5, 9, "G")
	return cv


def vending():
	cv = Canvas()
	cv.box(1, 0, 14, 15, "B")
	cv.rect(2, 1, 10, 12, "c")
	for y in (3, 6, 9):
		cv.hline(3, 9, y, "g")
		cv.rows(3, y - 1, ["r.y.o.e"])
	cv.rect(11, 3, 13, 8, "t")
	cv.px(12, 4, "y")
	cv.rect(3, 13, 9, 14, "t")
	return cv


def desk():
	cv = Canvas(2, 1)
	cv.box(0, 4, 31, 8, "m")
	cv.hline(1, 30, 5, "w")
	cv.box(0, 8, 31, 15, "n")
	cv.box(21, 9, 30, 14, "n")
	cv.hline(24, 27, 11, "N")
	cv.rows(4, 0, ["..tttt..", ".tbbbbt.", ".tbccbt.", ".tttttt."])   # a monitor
	cv.rect(14, 5, 18, 6, "w")                                        # papers
	return cv


def filing():
	cv = Canvas()
	cv.box(3, 1, 12, 15, "g")
	cv.hline(4, 11, 2, "G")
	for y in (5, 10):
		cv.hline(4, 11, y, "h")
		cv.hline(6, 9, y - 2, "G")
	return cv


def sofa():
	cv = Canvas(2, 1)
	cv.box(0, 1, 31, 8, "B")
	cv.hline(1, 30, 2, "b")
	cv.box(0, 7, 31, 14, "b")
	cv.vline(15, 8, 12, "B")
	cv.vline(16, 8, 12, "B")
	cv.box(0, 3, 3, 14, "B")
	cv.box(28, 3, 31, 14, "B")
	cv.hline(1, 30, 15, "k")
	return cv


def staff_table():
	cv = Canvas(2, 1)
	cv.box(1, 3, 30, 10, "W")
	cv.hline(2, 29, 4, "w")
	cv.vline(3, 11, 15, "h")
	cv.vline(28, 11, 15, "h")
	cv.hline(2, 29, 10, "g")
	cv.rect(8, 6, 10, 7, "r")       # a mug
	return cv


def toilet():
	cv = Canvas()
	cv.box(4, 0, 11, 5, "w")
	cv.hline(5, 10, 1, "H")
	cv.disc(8, 10, 4, "k")
	cv.disc(8, 10, 3, "w")
	cv.disc(8, 10, 1, "c")
	cv.rect(7, 5, 9, 6, "W")
	return cv


def dumpster():
	cv = Canvas(2, 1)
	cv.box(1, 2, 30, 15, "E")
	cv.box(0, 1, 31, 5, "e")
	cv.hline(1, 30, 2, "l")
	cv.rows(8, 8, ["wwwww..wwwww..www"])
	cv.hline(1, 30, 13, "k")
	cv.rect(3, 14, 5, 15, "t")
	cv.rect(26, 14, 28, 15, "t")
	return cv


def stall():
	"""A drive-in stall: a striped canopy post with a menu board and a speaker."""
	cv = Canvas(2, 2)
	cv.rect(0, 0, 31, 31, None)
	cv.box(2, 26, 29, 30, "g")          # the parking bay's kerb
	cv.hline(3, 28, 27, "G")
	cv.vline(15, 6, 26, "h")
	cv.vline(16, 6, 26, "G")
	cv.box(4, 1, 27, 7, "r")
	for x in range(6, 27, 4):
		cv.vline(x, 2, 6, "w")
	cv.box(8, 9, 23, 18, "t")
	cv.rows(10, 11, ["yyyy.yyy", "", "wwwwww.www", "", "wwww.wwwww"])
	cv.box(20, 19, 25, 23, "h")
	cv.px(22, 21, "r")
	return cv


def lamp():
	cv = Canvas()
	cv.rows(4, 0, [
		".kkkkkk.",
		"kyqqqqyk",
		"kyyyyyyk",
		".kkkkkk.",
	])
	cv.vline(7, 4, 13, "h")
	cv.vline(8, 4, 13, "g")
	cv.hline(5, 10, 14, "h")
	cv.hline(4, 11, 15, "k")
	return cv


def palm():
	cv = Canvas()
	cv.rows(0, 0, [
		"...e....e.......",
		"..eee..eee..e...",
		".eEeeeeeEee.ee..",
		"eE..eeeeeeEeeEe.",
		"e..eEeeeeEe..eEe",
		"..eE.eNNe.Ee...e",
		".eE...Nn...eE...",
		".e....Nn....e...",
		"......nN........",
		"......Nn........",
		"......nN........",
		".....kkkkk......",
		"....kOoooOk.....",
		"....kooooOk.....",
		".....kOOOk......",
		"......kkk.......",
	])
	return cv


def flowers():
	cv = Canvas()
	cv.rows(2, 3, [
		".r..y..p..r.",
		"rqr.yqy.pqp.",
		".r.e.ye.p.e.",
		"..eEe.eEe.e.",
		".eEeeEeEeEe.",
	])
	cv.box(1, 8, 14, 13, "N")
	cv.hline(2, 13, 9, "n")
	cv.hline(2, 13, 12, "O")
	return cv


def plant():
	cv = Canvas()
	cv.rows(3, 1, [
		"...e.e....",
		"..eEeEe.e.",
		".eEeeeEeE.",
		"eEe.eEeee.",
		".eeEeeEe..",
		"..eEeeE...",
		"...eEe....",
	])
	cv.box(4, 8, 11, 14, "O")
	cv.hline(5, 10, 9, "o")
	cv.hline(5, 10, 13, "O")
	cv.hline(5, 10, 15, "k")
	return cv


def car(body, dark, light):
	"""A car seen from the side, driving right."""
	cv = Canvas(2, 1)
	cv.rows(0, 2, [
		"..........kkkkkkkkkkk...........",
		".........kLccccLccccLk..........",
		"........kLcccccLcccccLk.........",
		".......kLLcccccLccccccLkk.......",
		"..kkkkkLLLLLLLLLLLLLLLLLLkkkkk..",
		".kLLLLLLLLLLLLLLLLLLLLLLLLLLLLk.",
		"kqBBBBBBBBBBBBBBBBBBBBBBBBBBBByk",
		"kBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBk",
		"kDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDk",
		".kDDkkkkDDDDDDDDDDDDDDDDkkkkDDk.",
		"...ktTTtk..............ktTTtk...",
		"...kTggTk..............kTggTk...",
		"....kkkk................kkkk....",
	])
	for (x, y) in [(xx, yy) for yy in range(16) for xx in range(32)]:
		p = cv.im.getpixel((x, y))
		if p[3] == 0:
			continue
		for key, col in (("L", light), ("B", body), ("D", dark)):
			if p[:3] == _rgb(key)[:3] and key in ("L", "B", "D"):
				pass
	return cv


P["L"] = "#ffffff"   # placeholders swapped per car below
P["B"] = "#000001"
P["D"] = "#000002"


def recolor(cv, mapping):
	for y in range(cv.h):
		for x in range(cv.w):
			p = cv.im.getpixel((x, y))
			for src, dst in mapping.items():
				if p[3] and p[:3] == _rgb(src)[:3]:
					cv.im.putpixel((x, y), _rgb(dst))
	return cv


def car_colored(body, dark, light):
	return recolor(car(body, dark, light), {"B": body, "D": dark, "L": light})


def bus():
	cv = Canvas(3, 1)
	cv.box(0, 1, 47, 13, "y")
	cv.hline(1, 46, 2, "q")
	for x in range(4, 42, 7):
		cv.box(x, 3, x + 5, 7, "c")
	cv.box(42, 3, 46, 10, "c")          # the driver's windscreen
	cv.hline(1, 46, 10, "Y")
	cv.hline(1, 46, 11, "k")
	for x in (7, 36):
		cv.box(x, 11, x + 5, 15, "t")
		cv.rect(x + 2, 13, x + 3, 13, "g")
	cv.px(47, 9, "q")
	cv.px(0, 9, "r")
	return cv


def van():
	"""The supplier's delivery van, white with a green stripe."""
	cv = Canvas(2, 1)
	cv.box(0, 1, 23, 12, "w")
	cv.box(23, 4, 31, 12, "w")
	cv.box(25, 5, 30, 8, "c")
	cv.hline(1, 22, 8, "e")
	cv.hline(1, 22, 9, "E")
	cv.hline(1, 30, 12, "k")
	for x in (4, 23):
		cv.box(x, 11, x + 5, 15, "t")
		cv.rect(x + 2, 13, x + 3, 13, "g")
	cv.px(31, 10, "q")
	return cv


def floor_kitchen():
	"""Quarry tiles: four to a tile, grey with pale grout."""
	cv = Canvas()
	cv.rect(0, 0, 15, 15, "#b9bfc6")
	for q in (0, 8):
		cv.hline(0, 15, q, "#d9dde1")
		cv.vline(q, 0, 15, "#d9dde1")
	for (x, y) in ((3, 4), (12, 2), (5, 13), (13, 11), (10, 6)):
		cv.px(x, y, "#a8aeb6")
	return cv


def floor_diner():
	"""Black and white diner checks, two by two to a tile, a little worn."""
	cv = Canvas()
	for qy in range(2):
		for qx in range(2):
			dark = (qx + qy) % 2 == 1
			x0, y0 = qx * 8, qy * 8
			cv.rect(x0, y0, x0 + 7, y0 + 7, "#44434d" if dark else "#ece5d6")
			cv.hline(x0, x0 + 7, y0 + 7, "#393841" if dark else "#d9d0bf")
			cv.px(x0 + 1, y0 + 1, "#55545f" if dark else "#f7f2e8")
	return cv


BUILD = [
	("grill", grill), ("griddle", griddle), ("fryer", fryer), ("oven", oven), ("fridge", fridge),
	("freezer", freezer), ("ice", ice), ("prep", prep), ("sink", sink), ("handsink", handsink),
	("drinks", drinks), ("pass", pass_window), ("radio", radio), ("bin", bin_), ("trap", trap),
	("booth_down", lambda: booth(2)), ("booth_up", lambda: booth(0)), ("booth_side", lambda: booth(1)),
	("stool", stool), ("counter", counter), ("highchair", highchair), ("host", host), ("till", till),
	("jukebox", jukebox), ("gumball", gumball), ("aquarium", aquarium), ("rug", rug),
	("neon", neon), ("records", records), ("tin_sign", tin_sign), ("trophy", trophy), ("clock", clock),
	("eotm", eotm), ("whiteboard", whiteboard), ("takeout", takeout), ("wall_art", wall_art),
	("coffee_maker", coffee_maker), ("tv", tv), ("lockers", lockers), ("vending", vending), ("desk", desk),
	("filing", filing), ("sofa", sofa), ("staff_table", staff_table), ("toilet", toilet),
	("dumpster", dumpster), ("lamp", lamp), ("palm", palm), ("flowers", flowers), ("plant", plant),
	("stall", stall), ("floor_diner", floor_diner), ("floor_kitchen", floor_kitchen),
	("car_red", lambda: car_colored("#d24b3e", "#9a3129", "#bfe6f5")),
	("car_blue", lambda: car_colored("#4a8fd0", "#2f5f94", "#bfe6f5")),
	("car_yellow", lambda: car_colored("#f2c14e", "#c28f2a", "#bfe6f5")),
	("car_green", lambda: car_colored("#4f9a6a", "#2f6d44", "#bfe6f5")),
	("car_white", lambda: car_colored("#e9e6df", "#b3ada2", "#9fc9dc")),
	("bus", bus), ("van", van),
]

if __name__ == "__main__":
	import os
	for name, fn in BUILD:
		add(name, fn())
	os.makedirs("art", exist_ok=True)
	sheet.save("art/diner.png")
	print("const DINER := {")
	for name, (c, r, w, h) in tiles.items():
		print('\t"%s": [%d, %d, %d, %d],' % (name, c, r, w, h))
	print("}")
