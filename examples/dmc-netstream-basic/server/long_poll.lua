--====================================================================--
--== DMC Net Stream test server
--====================================================================--

--[[

very basic server to test dmc_netstream module
accepts multple connections

--]]


--====================================================================--
--== Imports


local socket = require 'socket'



--====================================================================--
--== Setup, Constants


math.randomseed( os.time() )

local SLEEP_TIMEOUT = 2 -- seconds between process loops

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
	print( "Server: listening for connections" )
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



local function createHttpHeader()
	-- print( "createHttpHeader" )
	local http_header = {
		"HTTP/1.0 200 OK",
		os.date( "Date: %a %d %b %Y %H:%M:%S" ),
		"",
		""
	}
	return table.concat( http_header, "\r\n" )
end


local function sendHttpHeader( client )
	-- print( "sendHttpHeader", sendHttpHeader )

	local data = createHttpHeader()

	if math.random() < 0.25 then
		client:send( data )

	else
		-- add some data to header string
		data = data .. "one two three four five six seven eight"

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
		msg = string.format( "\n>> client connected: '%s'\n", tostring( res ) )
		print( msg )
		res = addClient( Server, res )
		sendHttpHeader( res )
	end

end


local function processClients( Server )
	-- print( "processClients" )

	for _, client in pairs( Server.clients ) do
		-- print(_, client)
		local data = string.format( "data @ %s", os.time() )

		local res, msg = client:send( data )
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
