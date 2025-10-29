local state = require("console_inline.state")

describe("server module", function()
	local original_loop
	local uv_stub
	local render_stub
	local relay_stub
	local server
	local original_render
	local original_relay
	local original_server
	local original_schedule

	local function reset_state()
		state.server = nil
		state.running = false
		state.sockets = {}
		state.opts.host = "127.0.0.1"
		state.opts.port = 36123
	end

	before_each(function()
		reset_state()
		uv_stub = {
			created = {},
		}
		function uv_stub.new_tcp()
			local tcp = {
				accepts = {},
				read_start_cb = nil,
				closed = false,
			}
			function tcp:bind(host, port)
				self.bound_host = host
				self.bound_port = port
			end
			function tcp:listen(_, cb)
				self.listen_cb = cb
			end
			function tcp:accept(sock)
				self.accepts[#self.accepts + 1] = sock
			end
			function tcp:close()
				self.closed = true
			end
			function tcp:read_start(cb)
				self.read_start_cb = cb
			end
			uv_stub.created[#uv_stub.created + 1] = tcp
			return tcp
		end

		original_loop = vim.loop
		vim.loop = uv_stub

		render_stub = {
			messages = {},
		}
		function render_stub.render_message(msg)
			render_stub.messages[#render_stub.messages + 1] = msg
		end
		relay_stub = {
			ensures = 0,
			stops = 0,
		}
		function relay_stub.ensure()
			relay_stub.ensures = relay_stub.ensures + 1
		end
		function relay_stub.stop()
			relay_stub.stops = relay_stub.stops + 1
		end
		original_render = package.loaded["console_inline.render"]
		package.loaded["console_inline.render"] = render_stub
		original_relay = package.loaded["console_inline.relay"]
		package.loaded["console_inline.relay"] = relay_stub
		original_server = package.loaded["console_inline.server"]
		package.loaded["console_inline.server"] = nil

		original_schedule = vim.schedule
		vim.schedule = function(fn)
			fn()
		end

		server = require("console_inline.server")
	end)

	after_each(function()
		if state.running then
			server.stop()
		end
		package.loaded["console_inline.render"] = original_render
		package.loaded["console_inline.relay"] = original_relay
		package.loaded["console_inline.server"] = original_server
		vim.loop = original_loop
		vim.schedule = original_schedule
	end)

	it("starts tcp listener and relay", function()
		server.start()
		assert.is_true(state.running)
		assert.are.equal(1, #uv_stub.created)
		local listener = uv_stub.created[1]
		assert.are.equal("127.0.0.1", listener.bound_host)
		assert.are.equal(36123, listener.bound_port)
		assert.are.equal(1, relay_stub.ensures)
	end)

	it("stops listener and sockets", function()
		server.start()
		local listener = uv_stub.created[1]
		listener.listen_cb(nil)
		local sock = uv_stub.created[2]
		sock.read_start_cb(nil, "{}\n")
		server.stop()
		assert.is_false(state.running)
		assert.is_true(listener.closed)
		assert.are.equal(1, relay_stub.stops)
	end)

	it("renders messages from sockets", function()
		server.start()
		local listener = uv_stub.created[1]
		listener.listen_cb(nil)
		local sock = uv_stub.created[2]
		sock.read_start_cb(nil, '{"file":"a.js","line":1,"kind":"log","args":["x"]}\n')
		assert.are.equal(1, #render_stub.messages)
		assert.are.equal("a.js", render_stub.messages[1].file)
	end)

	it("toggles running state", function()
		server.toggle()
		assert.is_true(state.running)
		server.toggle()
		assert.is_false(state.running)
	end)
end)
