# dmc-netstream

Receive data from an HTTP server as it arrives, in a Solar2D (formerly Corona SDK) app.

`network.request()` in Solar2D calls back once, when the whole response is in. dmc-netstream keeps the connection open and hands your listener each piece of the response body as the server sends it: a long poll, a server that pushes updates, a slow download you want to show progress for.

```lua
local NetStream = require 'dmc_corona.dmc_netstream'

NetStream.newStream{
	url='http://example.com/updates',
	listener=function( event ) print( event.data ) end
}
```

## Features

- Streams an HTTP or HTTPS response body to a listener, piece by piece, without blocking the app
- Decodes chunked responses, and ends the stream when the body is complete (`Content-Length`, the last chunk, or the server closing the connection)
- The response's status code and headers
- Events for connecting, connected, data, disconnected and errors
- Any method, request headers and a request body
- Built on [dmc-sockets](https://github.com/dmccuskey/dmc-sockets) (LuaSocket, polled once per frame); no plugins needed for HTTP
- MIT licensed

## Quick Start

The following code will get you up and running in about 10 minutes in the Solar2D Simulator on macOS or Windows. It streams ten bytes from the public test server httpbin.org, which sends them one at a time over a few seconds.

Prerequisites: the [Solar2D](https://solar2d.com/) Simulator, an Internet connection, and a copy of this repository (`git clone https://github.com/dmccuskey/dmc-netstream.git`, or download the ZIP from GitHub).

### 1. Copy the Library into Your Project

Copy these from this repository into the root of your project folder:

```text
dmc_corona_boot.lua     loader for the DMC libraries
dmc_corona.cfg          configuration
dmc_corona/             dmc-netstream and the libraries it uses
```

**Going further:** keep the libraries in a subfolder, or combine several DMC libraries ([dmc-corona-boot Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md)).

### 2. Open a Stream

Create `main.lua` in the project folder:

```lua
local NetStream = require 'dmc_corona.dmc_netstream'

local function onData( event )
	if event.data then
		print( "received '" .. event.data .. "'" )
	end
end

local stream = NetStream.newStream{
	url='http://httpbin.org/drip',
	listener=onData
}

stream:addEventListener( stream.EVENT, function( event )
	if event.type == stream.CONNECTED then
		print( 'connected', event.status )
	elseif event.type == stream.DISCONNECTED then
		print( 'disconnected' )
	elseif event.type == stream.ERROR then
		print( 'error:', event.emsg )
	end
end )
```

`httpbin.org/drip` sends ten `*` characters, one every 0.2 seconds. Its response has a `Content-Length` of 10, so the stream closes the connection after the tenth and sends `disconnected`.

### 3. Run It

Open the project in the Simulator. The screen stays black; the console shows, over about two seconds:

```text
connected	200
received '*'
received '*'
received '*'
received '*'
received '*'
received '*'
received '*'
received '*'
received '*'
disconnected
```

Now and then two characters arrive in the same network read and print together (`'**'`): the listener gets whatever has arrived since the last frame.

If `error: timeout` appears instead, the app couldn't reach httpbin.org: check the network connection, or try again later (it's a free public service). `module 'dmc_corona.dmc_netstream' not found` means `dmc_corona/` is missing from the root of the project folder.

**Going further:** the [example app](examples/) streams from a small server you run on your own computer, which sends a line every two seconds for as long as the app stays connected.

To update, copy `dmc_corona_boot.lua` and `dmc_corona/` again from the newer version. Keep your own `dmc_corona.cfg` if you have changed it.

## Reference

`require 'dmc_corona.dmc_netstream'` returns the module.

### `NetStream.newStream( params )`

Creates a stream and returns it. The stream connects by itself right after the current code finishes (on a 1 ms timer), so event listeners added right after `newStream()` get every event.

| param | default | effect |
|---|---|---|
| `url` | required | `http://` or `https://`, with an optional port (default 80 or 443) and query string |
| `method` | `'GET'` | the HTTP method |
| `listener` | none | a function called with each piece of data: `listener( { data=, emsg= } )` |
| `params` | `{}` | `headers`, a table of request headers, and `body`, a string sent after the headers |
| `auto_connect` | `true` | `false` to wait for `stream:connect()` |

The request is HTTP/1.1 with a `Host` header (with the port when it isn't the default), your headers (their names lower-cased), `user-agent: dmc-netstream 0.5.0` unless you set one, and `content-length` when there's a `body`, unless you set one.

The status code isn't checked: a `404` error page is streamed like any other body, so check `event.status` in the `CONNECTED` event. After the headers, every piece of data that arrives is passed on, as it comes, not split into lines or messages. A chunked response (`Transfer-Encoding: chunked`) is decoded: the listener gets the data without the chunk sizes.

The stream ends when the body is complete: after `Content-Length` bytes or the last chunk, the stream closes the connection; otherwise when the server closes it. A response to `HEAD`, and a `204` or `304`, has no body and ends right after the headers.

### `stream:connect()`

Starts a stream created with `auto_connect=false`. Calling it before the stream would have started on its own (the 1 ms timer) is fine: it starts then.

### `stream.status`, `stream.headers`

The response's status code (a number, e.g. `200`) and headers (a table, names lower-cased, e.g. `stream.headers['content-type']`; a header sent more than once is joined with `', '`), once `CONNECTED` has come; `nil` before.

### The Listener

`listener( event )` gets:

- `event.data`: the next piece of the response body, a string of any length
- when the stream ends: `event.data` is `nil` and `event.emsg` says why (`nil` when the body is complete or the server closed the connection, `'timeout'` when the connection failed, `'bad response'` when the response isn't HTTP)

### Events

`stream:addEventListener( stream.EVENT, handler )`. `event.target` is the stream, and `event.type` one of:

| `event.type` | when | also in the event |
|---|---|---|
| `stream.CONNECTING` | the connection starts | |
| `stream.CONNECTED` | the response headers are in | `event.status`, `event.headers` |
| `stream.DATA` | data arrived (the listener gets it too) | `event.data` |
| `stream.DISCONNECTED` | the body is complete, or the server closed the connection | `event.emsg` |
| `stream.ERROR` | the connection failed, or the response couldn't be read | `event.emsg` |

After `DISCONNECTED` or `ERROR`, the stream is finished: create a new one to connect again.

### `stream:removeSelf()`

Closes the connection and stops the stream, without further events.

### HTTPS

An `https://` URL uses a TLS socket. As with dmc-sockets, add Solar2D's OpenSSL plugin to `build.settings` ([dmc-sockets](https://github.com/dmccuskey/dmc-sockets#quick-start), "Going further"). Android apps also need the `INTERNET` permission, for HTTP too.

## In Solar2D

dmc-sockets reads the connection once per frame (LuaSocket has no callbacks), so data reaches the listener up to one frame after it arrives: 33 ms at 30 fps. Everything happens in the app's main thread, between frames.

## Configuration

dmc-netstream has no settings: the `dmc_corona.cfg` in this repository has only the `[DMC_CORONA]` section, which tells the loader where the libraries are ([dmc-corona-boot Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md)).

## Known Issues

- A failed connection reports `timeout`, after dmc-sockets' timeout, not `connection refused`. [#1](https://github.com/dmccuskey/dmc-netstream/issues/1)
- A redirect (`301`, `302`) isn't followed: its body is streamed like any other. [#2](https://github.com/dmccuskey/dmc-netstream/issues/2)

## Development

Only `dmc_corona/dmc_netstream.lua` is written in this repository. Everything else in `dmc_corona/`, and `dmc_corona_boot.lua`, are generated copies from the libraries it uses: [dmc-sockets](https://github.com/dmccuskey/dmc-sockets), [dmc-patch](https://github.com/dmccuskey/dmc-patch), [dmc-states-mixin](https://github.com/dmccuskey/dmc-states-mixin), [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library) (in `dmc_corona/lib/dmc_lua/`) and [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot). Fix them there, then rebuild. The copies, and the ones in the example app, are made by Snakemake from sibling checkouts (`../dmc-sockets` and so on, `../DMC-Corona-Library` for the shared rules). From this repository's root folder:

```sh
snakemake --cores 1 build_all
```

The unit tests (`tests/dmc_netstream_spec.lua`) run on macOS or Linux with plain Lua 5.1, LuaSocket and dkjson, against a stand-in for dmc-sockets and Solar2D's timer:

```sh
tests/run_unit.sh
```

It expects Lua at `../tools/lua51/bin/lua` (a [hererocks](https://github.com/luarocks/hererocks) build next to this checkout); set `LUA=` to use another. Expected output ends with `21 passed, 0 failed, 0 error(s), 0 skipped.` The Quick Start and the [example app](examples/) are the check that it works in Solar2D. Neither draws anything, so both also run outside Solar2D in [lua-corovel](https://github.com/dmccuskey/lua-corovel).

## License

dmc-netstream is released under the [MIT License](LICENSE).
