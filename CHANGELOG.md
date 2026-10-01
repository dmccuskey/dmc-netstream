# Changelog

## 0.5.0 (unreleased)

### Fixed

- Data that arrived in the same network read as the response headers was held back, and lost when the server then closed the connection, so an ordinary response (a web page, a file) often streamed nothing.
- The URL's query string was dropped: `http://host/path?a=1` requested `/path`.
- Chunked responses (`Transfer-Encoding: chunked`) weren't decoded: the chunk sizes arrived in the data.
- `stream:connect()` did nothing, and `auto_connect=false` was ignored (and not passed on by `newStream()`).
- After an error, the stream sent a second `CONNECTING` event and started connecting again while being removed.
- The `Host` header left out a non-default port.
- A request `body` was followed by an extra empty line, which a server reads as the start of another request.
- A stream stopped with `removeSelf()` stayed in the module's list of streams, and one stopped before it started still tried to connect.
- The globals `createHttpRequest` and `_extend` are no longer created, and the module uses `Objects.newClass` instead of the global.
- Rebuilt with dmc-corona-boot 1.6.0 and the current dmc-sockets, dmc-patch, dmc-states-mixin and DMC-Lua-Library. lua-objects 1.4 raises an error for an `__init__()` that skips `superCall()`, as dmc-netstream's did: it now calls its parents with `superCall()`.

### Added

- The response's status code and headers: `event.status` and `event.headers` in the `CONNECTED` event, and `stream.status` and `stream.headers`.
- The stream ends by itself when the body is complete: after `Content-Length` bytes or the last chunk it closes the connection and sends `DISCONNECTED`. A response to `HEAD`, a `204` and a `304` end right after the headers. An interim `100 Continue` response is skipped.
- A response that isn't HTTP, or a bad chunk size, gives `ERROR` with `'bad response'`.
- `content-length` is set for a request `body` unless given.
- Unit tests, and `tests/run_unit.sh` to run them with plain Lua 5.1.
- The example server prints each request it receives, and `lua long_poll.lua chunked` sends a chunked response.

### Changed

- The `user-agent` header is `dmc-netstream 0.5.0` (also `stream.USER_AGENT`).
- The example app's README has install steps for Lua and LuaSocket on macOS, Windows and Linux.
