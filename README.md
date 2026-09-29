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
	listener=onData,
	params={ headers={ Connection='close' } }
}

stream:addEventListener( stream.EVENT, function( event )
	if event.type == stream.CONNECTED then
		print( 'connected' )
	elseif event.type == stream.DISCONNECTED then
		print( 'disconnected' )
	elseif event.type == stream.ERROR then
		print( 'error:', event.emsg )
	end
end )
```

`httpbin.org/drip` waits two seconds, then sends ten `*` characters over two seconds. The `Connection: close` header asks it to close the connection when it's done; without it, the server keeps the connection open and no `disconnected` comes.

### 3. Run It

Open the project in the Simulator. The screen stays black; the console shows, over about four seconds:

```text
connected
received '**'
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

The first two characters usually come together: the first one arrives with the response headers and is held until the next data comes in (see [Known Issues](#known-issues)).

If `error: timeout` appears instead, the app couldn't reach httpbin.org: check the network connection, or try again later (it's a free public service). `module 'dmc_corona.dmc_netstream' not found` means `dmc_corona/` is missing from the root of the project folder.

**Going further:** the [example app](examples/) streams from a small server you run on your own computer, which sends a line every two seconds for as long as the app stays connected.

To update, copy `dmc_corona_boot.lua` and `dmc_corona/` again from the newer version. Keep your own `dmc_corona.cfg` if you have changed it.

## Reference

`require 'dmc_corona.dmc_netstream'` returns the module.

### `NetStream.newStream( params )`

Creates a stream and returns it. The stream connects by itself right after the current code finishes (on a 1 ms timer), so event listeners added right after `newStream()` get every event.

| param | default | effect |
|---|---|---|
| `url` | required | `http://` or `https://`, with an optional port (default 80 or 443). Only the path is sent: a query string (`?a=1`) is dropped |
| `method` | `'GET'` | the HTTP method |
| `listener` | none | a function called with each piece of data: `listener( { data=, emsg= } )` |
| `params` | `{}` | `headers`, a table of request headers, and `body`, a string sent after the headers |

The request is HTTP/1.1 with a `Host` header (without the port), your headers (their names lower-cased) and `user-agent: dmc-netstream 0.4.0` unless you set one. A `body` is sent as is: set `Content-Length` yourself.

The response's status line and headers are read and dropped: a `404` error page is treated like any other body. After the headers, every piece of data that arrives is passed on, as it comes, not split into lines or messages.

### The Listener

`listener( event )` gets:

- `event.data`: the next piece of the response body, a string of any length
- when the connection ends: `event.data` is `nil` and `event.emsg` says why (`nil` when the server closed it, `'timeout'` when the connection failed)

### Events

`stream:addEventListener( stream.EVENT, handler )`. `event.target` is the stream, and `event.type` one of:

| `event.type` | when | also in the event |
|---|---|---|
| `stream.CONNECTING` | the connection starts | |
| `stream.CONNECTED` | the response headers are in | |
| `stream.DATA` | data arrived (the listener gets it too) | `event.data` |
| `stream.DISCONNECTED` | the server closed the connection | `event.emsg` |
| `stream.ERROR` | the connection failed | `event.emsg` |

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

- **Data that arrives together with the response headers is held back** until more data comes in, and is lost if the server then closes the connection: an ordinary response (a web page, a 404) often streams nothing at all. Streams where the server pauses after the headers, like the Quick Start's, work.
- **The URL's query string is dropped**: `http://host/path?a=1` requests `/path`.
- **Chunked responses aren't decoded**: with `Transfer-Encoding: chunked` (common for HTTP/1.1 streams), the chunk sizes arrive in the data (`'7\r\ntick 0\n\r\n'`). Send your request with a `Connection: close` header, or use a server that sends HTTP/1.0 or a `Content-Length`.
- The status code isn't checked, and the response headers can't be read.
- `stream:connect()` does nothing, and the stream always connects by itself: an `auto_connect` param isn't passed on by `newStream()`, and ignored even when it is.
- After an error, the stream sends a second `CONNECTING` event, then nothing: it's already been removed.
- A failed connection reports `timeout`, after dmc-sockets' timeout, not `connection refused`.
- The `Host` header leaves out a non-default port.
- A stream stopped with `removeSelf()` stays in the module's list of streams (a small leak).
- `dmc_netstream.lua` sets the globals `createHttpRequest` and `_extend`.

## Development

Only `dmc_corona/dmc_netstream.lua` is written in this repository. Everything else in `dmc_corona/`, and `dmc_corona_boot.lua`, are generated copies from the libraries it uses: [dmc-sockets](https://github.com/dmccuskey/dmc-sockets), [dmc-patch](https://github.com/dmccuskey/dmc-patch), [dmc-states-mixin](https://github.com/dmccuskey/dmc-states-mixin), [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library) (in `dmc_corona/lib/dmc_lua/`) and [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot). Fix them there, then rebuild. The copies, and the ones in the example app, are made by Snakemake from sibling checkouts (`../dmc-sockets` and so on, `../DMC-Corona-Library` for the shared rules). From this repository's root folder:

```sh
snakemake --cores 1 build_all
```

dmc-netstream has no tests. The Quick Start and the [example app](examples/) are the check that it works in Solar2D. Neither draws anything, so both also run outside Solar2D in [lua-corovel](https://github.com/dmccuskey/lua-corovel).

## License

dmc-netstream is released under the [MIT License](LICENSE).
