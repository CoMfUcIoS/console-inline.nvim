local r = require("console_inline.render")
local old = r.render_message
r.render_message = function(m)
	if m and m.file then
		print("[console-inline] file:", m.file)
	end
	return old(m)
end
return true
