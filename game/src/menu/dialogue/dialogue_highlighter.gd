class_name DialogueHighlighter
extends SyntaxHighlighter
## Port addition: colours a dialogue line in the editor's text field (DialogueEditorPanel): [ACTIONS] blue, the ones
## an extension adds orange, *WILDCARDS* in the accent colour.

const GAME := Color("9fd3f3")
const EXT := Color("f0c27a")

var is_ext: Callable   # (raw action text without brackets) -> bool


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var t := get_text_edit().get_line(line)
	var out := {0: {"color": MenuTheme.TEXT}}
	var i := 0
	while i < t.length():
		var c := t[i]
		if c == "[":
			var e := t.find("]", i)
			if e == -1:
				e = t.length() - 1
			var inner := t.substr(i + 1, e - i - 1)
			out[i] = {"color": EXT if is_ext.is_valid() and is_ext.call(inner) else GAME}
			out[e + 1] = {"color": MenuTheme.TEXT}
			i = e + 1
		elif c == "*":
			var e := t.find("*", i + 1)
			if e == -1:
				break
			out[i] = {"color": MenuTheme.ACCENT}
			out[e + 1] = {"color": MenuTheme.TEXT}
			i = e + 1
		else:
			i += 1
	return out
