std = "lua54"

globals = {
	"vim",
	-- tests
	"describe",
	"it",
	"before_each",
	"after_each",
	"assert",
}

codes = true
allow_defined = true
max_line_length = 140
exclude_files = {
	"examples/**",
	"tests/**",
	"npm/**",
}
