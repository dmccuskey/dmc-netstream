# Examples

Each folder is a complete Solar2D project with its own copy of the library: open its `main.lua` in the Solar2D Simulator. The example draws nothing; it prints to the Simulator's console.

## Basic

[dmc-netstream-basic](dmc-netstream-basic/): streams from a small HTTP server that runs on your computer, `server/long_poll.lua`. The server accepts any number of connections and sends each one a line every two seconds, for as long as it stays connected.

The server is plain Lua and needs Lua 5.1 (or newer) with [LuaSocket](https://github.com/lunarmodules/luasocket) (`luarocks install luasocket`). Start it first:

```sh
cd examples/dmc-netstream-basic/server
lua long_poll.lua
```

It listens on port 4411; it prints `Server: listening for connections` once it starts. Then open `dmc-netstream-basic/main.lua` in the Simulator. The console shows:

```text
NetStream: CONNECTING
NetStream: CONNECTED
>> In data callback: received 'one two three four five six seven eight'
>> In data callback: received 'data @ 1790656595'
>> In data callback: received 'data @ 1790656597'
>> In data callback: received 'data @ 1790656599'
```

The numbers are the server's clock (`os.time()`). Three times out of four, the server sends its response headers in two parts, with `one two three ...` after them, to test a slow start; otherwise that line is missing.

The app connects to `127.0.0.1`, the same computer. To run it on a device, set `HOST` in `main.lua` to the computer's address on the local network. When the app is relaunched, the server notices the closed connection the next time it sends, and drops it.

Stop the server with Ctrl-C.
