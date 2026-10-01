# Examples

Each folder is a complete Solar2D project with its own copy of the library: open its `main.lua` in the Solar2D Simulator. The example draws nothing; it prints to the Simulator's console.

## Basic

[dmc-netstream-basic](dmc-netstream-basic/): streams from a small HTTP server that runs on your computer, `server/long_poll.lua`. The server accepts any number of connections and sends each one a line every two seconds, for as long as it stays connected.

The server is plain Lua, the same language as the app, but it runs outside Solar2D: it needs Lua 5.1 (or newer) with [LuaSocket](https://github.com/lunarmodules/luasocket), installed on your computer once:

- **macOS** ([Homebrew](https://brew.sh/)): `brew install lua luarocks`, then `luarocks install luasocket`.
- **Windows:** [Lua for Windows](https://github.com/rjpcomputing/luaforwindows/releases) installs Lua 5.1 with LuaSocket included. With LuaRocks and a C compiler instead, `luarocks install luasocket`.
- **Linux:** your package manager's `lua` and `lua-socket` packages, or LuaRocks as above.

`lua -e "require 'socket'"` printing nothing means it's ready. Start the server first:

```sh
cd examples/dmc-netstream-basic/server
lua long_poll.lua
```

It listens on port 4411; it prints `Server: listening for connections on port 4411 (plain)` once it starts. Then open `dmc-netstream-basic/main.lua` in the Simulator. The console shows:

```text
NetStream: CONNECTING
NetStream: CONNECTED
>> In data callback: received 'one two three four five six seven eight'
>> In data callback: received 'data @ 1790656595'
>> In data callback: received 'data @ 1790656597'
>> In data callback: received 'data @ 1790656599'
```

The server prints each request it gets, so you can see what dmc-netstream sends:

```text
>> client connected: 'tcp{client}: 0x12d011028'
  GET / HTTP/1.1
  Host: 127.0.0.1:4411
  user-agent: dmc-netstream 0.5.0
  cache-control: no-cache

Sent: to client 'tcp{client}: 0x12d011028'  'data @ 1790656595'
```

The numbers are the server's clock (`os.time()`). Three times out of four, the server sends its response headers in two parts, a second apart, with `one two three ...` in the same piece as the end of the headers, to test a slow start; otherwise that line is missing.

**Chunked:** `lua long_poll.lua chunked` sends an HTTP/1.1 response with `Transfer-Encoding: chunked`, each line as a chunk. The app's console shows the same lines: dmc-netstream removes the chunk sizes.

The app connects to `127.0.0.1`, the same computer. To run it on a device, set `HOST` in `main.lua` to the computer's address on the local network. When the app is relaunched, the server notices the closed connection the next time it sends, and drops it.

Stop the server with Ctrl-C.
