--====================================================================--
--== DMC Net Stream test server
--====================================================================--

--[[

very basic server to test dmc_netstream module
accepts multiple connections

usage: lua long_poll.lua [chunked]

plain: an HTTP/1.0 response, ended by closing the connection
chunked: an HTTP/1.1 response with Transfer-Encoding: chunked

--]]


--====================================================================--
--== Imports


local socket = require 'socket'



--====================================================================--
--== Setup, Constants


math.randomseed( os.time() )

local SLEEP_TIMEOUT = 2 -- seconds between process loops
local CHUNKED = arg[1] == 'chunked'

local Server = {
	port = 4411,
	clients = {},
	socket = nil
}



--====================================================================--
--== Support Functions


local function setupServerSocket( Server )
	-- print( "setupServerSocket", Server )
	local sock = assert( socket.bind('*', Server.port) )
	sock:settimeout( 0 )
	Server.socket = sock
	print( string.format( "Server: listening for connections on port %d (%s)",
		Server.port, CHUNKED and "chunked" or "plain" ) )
	return Server
end



local function addClient( Server, client )
	-- print( "addClient", Server, client )
	local clients = Server.clients
	local cid = tostring( client )
	clients[ cid ] = client

	return client
end

local function removeClient( Server, client )
	-- print( "removeClient", Server, client )
	local clients = Server.clients
	local cid = tostring( client )
	clients[ cid ] = nil
	client:close()
end



-- each piece of data goes out as is, or as a chunk
--
local function encode( data )
	if not CHUNKED then return data end
	return string.format( "%x\r\n%s\r\n", #data, data )
end


-- read the client's request (up to the empty line after its
-- headers) and print it
--
local function readRequest( client )
	-- print( "readRequest", client )
	client:settimeout( 2 )
	while true do
		local line, err = client:receive( '*l' )
		if not line or line == '' then break end
		print( "  " .. line )
	end
	client:settimeout( 0 )
end


local function createHttpHeader()
	-- print( "createHttpHeader" )
	local http_header = {
		CHUNKED and "HTTP/1.1 200 OK" or "HTTP/1.0 200 OK",
		os.date( "!Date: %a, %d %b %Y %H:%M:%S GMT" ),
		"Content-Type: text/plain",
	}
	if CHUNKED then
		table.insert( http_header, "Transfer-Encoding: chunked" )
	end
	table.insert( http_header, "" )
	table.insert( http_header, "" )
	return table.concat( http_header, "\r\n" )
end


local function sendHttpHeader( client )
	-- print( "sendHttpHeader", sendHttpHeader )

	local data = createHttpHeader()

	if math.random() < 0.25 then
		client:send( data )

	else
		-- add some data to header string
		data = data .. encode( "one two three four five six seven eight" )

		client:send( string.sub( data, 1, 10 ) )

		socket.sleep( 1 )

		client:send(  string.sub( data, 11 ) )

	end
end


local function checkNewClients( Server )
	-- print( "checkNewClients" )

	local sock = Server.socket
	local res, msg = sock:accept()

	if res then
		msg = string.format( "\n>> client connected: '%s'", tostring( res ) )
		print( msg )
		readRequest( res )
		print( "" )
		res = addClient( Server, res )
		sendHttpHeader( res )
	end

end


local function processClients( Server )
	-- print( "processClients" )

	for _, client in pairs( Server.clients ) do
		-- print(_, client)
		local data = string.format( "data @ %s", os.time() )

		local res, msg = client:send( encode( data ) )
		if msg == 'closed' then
			msg = string.format( "\n<< client disconnected: '%s'\n", _ )
			print( msg )
			removeClient( Server, client )
		else
			msg = string.format( "Sent: to client '%s'  '%s'", _, data )
			print( msg )
		end
	end

end


local function doServerProcessing( Server )
	-- print( "doServerProcessing" )
	while 1 do
		processClients( Server )
		checkNewClients( Server )
		socket.sleep( SLEEP_TIMEOUT )
	end
end


doServerProcessing( setupServerSocket( Server ) )
