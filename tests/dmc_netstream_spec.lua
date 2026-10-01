--====================================================================--
-- tests/dmc_netstream_spec.lua
--
-- Testing NetStream using Luna Test, against a stand-in for
-- dmc_sockets and Solar2D's timer and Runtime
--====================================================================--


module(..., package.seeall)




--====================================================================--
--== Test: DMC NetStream
--====================================================================--


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "0.1.0"



--====================================================================--
--== Stand-ins
--====================================================================--


--== Timers: run by hand with fireTimers()

local timers = {}

local function fireTimers()
	local due = timers
	timers = {}
	for _, t in ipairs( due ) do
		if not t.cancelled then t.f() end
	end
end


--== Sockets: records what's sent, feeds what the test gives it

local FakeSockets = {
	ATCP='atcp',
	last=nil
}

function FakeSockets:create( stype, params )
	local sock = {
		CONNECTED='socket_connected', NOT_CONNECTED='socket_not_connected',
		CLOSED='socket_closed',
		sent={}, pending={}, closed=false, removed=false, connects=0
	}
	function sock:connect( host, port, handlers )
		self.host, self.port, self.handlers = host, port, handlers
		self.connects = self.connects + 1
	end
	function sock:send( data, callback )
		table.insert( self.sent, data )
	end
	function sock:receive( pattern, callback )
		local data = table.concat( self.pending )
		self.pending = {}
		callback{ data=data }
	end
	function sock:close()
		if self.closed then return end
		self.closed = true
		self.handlers.onConnect{ status=self.CLOSED }
	end
	function sock:removeSelf()
		self.removed = true
	end
	FakeSockets.last = sock
	return sock
end


local NetStream



--====================================================================--
--== Helpers
--====================================================================--


-- a stream, its socket, and the events and listener calls it makes
--
local function newStream( params )
	params = params or {}
	params.url = params.url or 'http://example.com/feed'
	local calls = {}
	params.listener = function( event ) table.insert( calls, event ) end
	local ns = NetStream.newStream( params )
	local events = {}
	ns:addEventListener( ns.EVENT, function( event )
		table.insert( events, event )
	end )
	return ns, FakeSockets.last, events, calls
end

local function feed( sock, data )
	table.insert( sock.pending, data )
	sock.handlers.onData{}
end

-- start the stream and complete the TCP connection; returns the request
--
local function open( sock )
	fireTimers()
	sock.handlers.onConnect{ status=sock.CONNECTED }
	return sock.sent[1]
end

local function eventsOf( events, etype )
	local list = {}
	for _, e in ipairs( events ) do
		if e.type == etype then table.insert( list, e ) end
	end
	return list
end

-- the body as the listener got it
local function received( calls )
	local list = {}
	for _, c in ipairs( calls ) do
		if c.data then table.insert( list, c.data ) end
	end
	return table.concat( list, '|' )
end

local HEAD = 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n'



--====================================================================--
--== Testing Setup
--====================================================================--


function suite_setup()
	_G.timer = {
		performWithDelay=function( ms, f )
			local t = { ms=ms, f=f }
			table.insert( timers, t )
			return t
		end,
		cancel=function( t ) t.cancelled = true end
	}
	_G.Runtime = {
		addEventListener=function() end,
		removeEventListener=function() end
	}
	package.loaded[ 'dmc_sockets' ] = FakeSockets

	require 'dmc_corona_boot'
	NetStream = require 'dmc_netstream'
end

function setup()
	timers = {}
end



--====================================================================--
--== Tests
--====================================================================--


--== The request

function test_request()
	local ns, sock = newStream{ params={ headers={ ['X-Test']='yes' } } }
	local req = open( sock )
	assert_equal( 'example.com', sock.host )
	assert_equal( 80, sock.port )
	assert_match( '^GET /feed HTTP/1%.1\r\n', req )
	assert_match( '\r\nHost: example%.com\r\n', req )
	assert_match( '\r\nx%-test: yes\r\n', req )
	assert_match( '\r\nuser%-agent: dmc%-netstream ', req )
	assert_match( '\r\n\r\n$', req )
end

function test_queryString()
	local ns, sock = newStream{ url='http://example.com/feed?a=1&b=2' }
	assert_match( '^GET /feed%?a=1&b=2 HTTP', open( sock ) )
end

function test_hostWithPort()
	local ns, sock = newStream{ url='http://example.com:8080' }
	local req = open( sock )
	assert_equal( 8080, sock.port )
	assert_match( '^GET / HTTP', req )
	assert_match( '\r\nHost: example%.com:8080\r\n', req )

	ns, sock = newStream{ url='https://example.com/' }
	req = open( sock )
	assert_equal( 443, sock.port )
	assert_true( sock.secure )
	assert_match( '\r\nHost: example%.com\r\n', req )
end

function test_bodyAndLength()
	local ns, sock = newStream{ method='POST', params={ body='a=1' } }
	local req = open( sock )
	assert_match( '\r\ncontent%-length: 3\r\n', req )
	assert_match( '\r\n\r\na=1$', req )
end


--== Reading the response

function test_bodyWithHeaders()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, HEAD .. 'first' )
	assert_equal( 1, #eventsOf( events, ns.CONNECTED ) )
	assert_equal( 'first', received( calls ) )
	feed( sock, 'second' )
	assert_equal( 'first|second', received( calls ) )
	local data = eventsOf( events, ns.DATA )
	assert_equal( 2, #data )
	assert_equal( 'second', data[2].data )
end

function test_headersInPieces()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, 'HTTP/1.1 200 OK\r\nCont' )
	feed( sock, 'ent-Type: text/plain\r' )
	assert_equal( 0, #eventsOf( events, ns.CONNECTED ) )
	feed( sock, '\n\r\nbody' )
	assert_equal( 1, #eventsOf( events, ns.CONNECTED ) )
	assert_equal( 'body', received( calls ) )
end

function test_statusAndHeaders()
	local ns, sock, events = newStream()
	open( sock )
	feed( sock, 'HTTP/1.1 404 Not Found\r\nX-One: a\r\nx-one: b\r\nContent-Type:text/html\r\n\r\n' )
	local e = eventsOf( events, ns.CONNECTED )[1]
	assert_equal( 404, e.status )
	assert_equal( 'text/html', e.headers['content-type'] )
	assert_equal( 'a, b', e.headers['x-one'] )
	assert_equal( 404, ns.status )
	assert_equal( 'text/html', ns.headers['content-type'] )
end

function test_interimResponseSkipped()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, 'HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\n\r\nok' )
	assert_equal( 200, ns.status )
	assert_equal( 'ok', received( calls ) )
end

function test_badResponseIsError()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, 'garbage\r\n\r\n' )
	local errs = eventsOf( events, ns.ERROR )
	assert_equal( 1, #errs )
	assert_equal( 'bad response', errs[1].emsg )
	assert_true( sock.removed )
end

function test_contentLengthEndsStream()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, 'HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\nabc' )
	feed( sock, 'defghEXTRA' )
	assert_equal( 'abc|defgh', received( calls ) )
	assert_false( sock.closed )
	fireTimers()
	assert_true( sock.closed )
	assert_equal( 1, #eventsOf( events, ns.DISCONNECTED ) )
	local last = calls[ #calls ]
	assert_nil( last.data )
	assert_nil( last.emsg )
end

function test_noBodyEndsStream()
	local ns, sock, events, calls = newStream{ method='HEAD' }
	open( sock )
	feed( sock, 'HTTP/1.1 200 OK\r\nContent-Length: 500\r\n\r\n' )
	fireTimers()
	assert_true( sock.closed )
	assert_equal( '', received( calls ) )

	ns, sock, events = newStream()
	open( sock )
	feed( sock, 'HTTP/1.1 204 No Content\r\n\r\n' )
	fireTimers()
	assert_true( sock.closed )
end

function test_closeDelimitedBody()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, 'HTTP/1.0 200 OK\r\n\r\none' )
	feed( sock, 'two' )
	sock:close()
	assert_equal( 'one|two', received( calls ) )
	assert_equal( 1, #eventsOf( events, ns.DISCONNECTED ) )
	assert_true( sock.removed )
end


--== Chunked transfer encoding

local CHUNKED = 'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n'

function test_chunked()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, CHUNKED .. '5\r\nhello\r\n7;ext=1\r\n, world\r\n' )
	assert_equal( 'hello, world', received( calls ) )
	feed( sock, '0\r\n\r\n' )
	fireTimers()
	assert_true( sock.closed )
	assert_equal( 1, #eventsOf( events, ns.DISCONNECTED ) )
end

function test_chunkedInPieces()
	local ns, sock, events, calls = newStream()
	open( sock )
	feed( sock, CHUNKED .. 'a' )
	feed( sock, '\r\n01234' )
	feed( sock, '56789\r' )
	feed( sock, '\n3\r\nabc' )
	feed( sock, '\r\n0\r\nTrailer: x\r\n\r\n' )
	assert_equal( '01234|56789|abc', received( calls ) )
	fireTimers()
	assert_true( sock.closed )
end

function test_chunkedBadSizeIsError()
	local ns, sock, events = newStream()
	open( sock )
	feed( sock, CHUNKED .. 'zz\r\nhello\r\n' )
	assert_equal( 1, #eventsOf( events, ns.ERROR ) )
	assert_true( sock.removed )
end


--== Connecting

function test_autoConnect()
	local ns, sock, events = newStream()
	assert_equal( 0, sock.connects )
	fireTimers()
	assert_equal( 1, sock.connects )
	assert_equal( 1, #eventsOf( events, ns.CONNECTING ) )
end

function test_autoConnectOff()
	local ns, sock, events = newStream{ auto_connect=false }
	fireTimers()
	assert_equal( 0, sock.connects )
	ns:connect()
	assert_equal( 1, sock.connects )
	assert_equal( 1, #eventsOf( events, ns.CONNECTING ) )
end

function test_connectBeforeStart()
	local ns, sock = newStream{ auto_connect=false }
	ns:connect()
	assert_equal( 0, sock.connects )
	fireTimers()
	assert_equal( 1, sock.connects )
end

function test_errorEndsStream()
	local ns, sock, events, calls = newStream()
	fireTimers()
	sock.handlers.onConnect{ status=sock.NOT_CONNECTED, emsg='timeout' }
	assert_equal( 1, #eventsOf( events, ns.CONNECTING ) )
	local errs = eventsOf( events, ns.ERROR )
	assert_equal( 1, #errs )
	assert_equal( 'timeout', errs[1].emsg )
	assert_equal( 1, sock.connects )
	assert_equal( 'timeout', calls[1].emsg )
	assert_true( sock.removed )
	ns:connect()
	assert_equal( 1, sock.connects )
end

function test_removeSelf()
	local ns, sock, events = newStream()
	ns:removeSelf()
	fireTimers()
	assert_equal( 0, sock.connects )
	assert_true( sock.removed )
	assert_equal( 0, #events )
end

-- newClass comes from lua-class, which makes it global by default
function test_noGlobals()
	assert_nil( rawget( _G, 'createHttpRequest' ) )
	assert_nil( rawget( _G, '_extend' ) )
end
