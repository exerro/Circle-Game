
local world = {}
local timers = { spawnCounter = 0 }
local running = true
local score = 0
local font = love.graphics.newFont( 40 )

local ENDGAMETEXT = "You died, press space to try again"

local FORM_CIRCLE = 0
local FORM_RECTANGLE = 1

local POINTER_MAX_SPEED = 400
local CIRC_SPEED = 150
local SIZE_RANGE = 20

local SPAWNRATE = 4

local INITIAL_PLAYER_SIZE = 30
local SIZE_LOSS = 0.075
local SIZE_GAIN = 0.15

local circResolution = 256
local imageData1 = love.image.newImageData( circResolution, circResolution )

local player, endgame

for x = 0, circResolution - 1 do
	for y = 0, circResolution - 1 do
		local dist = math.sqrt( ( x - circResolution / 2 - 0.5 ) ^ 2 + ( y - circResolution / 2 - 0.5 ) ^ 2 )
		local c = math.min( 1.2 - ( 2 * dist / circResolution ), 1 )
		local col = dist < circResolution / 2 and { 255, 255, 255, 255 * c } or { 0, 0, 0, 0 }

		imageData1:setPixel( x, y, col )
	end
end

local image1 = love.graphics.newImage( imageData1 )

local function windowWidth()
	local w, h = love.window.getMode()
	return w
end

local function windowHeight()
	local w, h = love.window.getMode()
	return h
end

local function randomSideLocation()
	local size = math.max( 10, math.random( player.size - SIZE_RANGE, player.size + SIZE_RANGE ) )
	local side = math.random( 0, 3 )
	if side == 0 then
		return -size, math.random() * windowHeight(), math.random() * CIRC_SPEED, (math.random() - 0.5) * CIRC_SPEED, size
	elseif side == 1 then
		return math.random() * windowWidth(), -size, (math.random() - 0.5) * CIRC_SPEED, math.random() * CIRC_SPEED, size
	elseif side == 2 then
		return windowWidth() + size, math.random() * windowHeight(), -math.random() * CIRC_SPEED, (math.random() - 0.5) * CIRC_SPEED, size
	elseif side == 3 then
		return math.random() * windowWidth(), windowHeight() + size, (math.random() - 0.5) * CIRC_SPEED, -math.random() * CIRC_SPEED, size
	end
end

local function sigmoid( n )
	return 2 / ( 1 + math.exp( -n ) ) - 1
end

local function circIntersectCirc( a, b )
	return a.size + b.size >= math.sqrt( (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 )
end

local function rectIntersectRect( a, b )
	return not (a.x > b.x + b.width or b.x > a.x + a.width or a.y > b.y + b.height or b.y > a.y + a.height)
end

local function circIntersectRect( a, b )
	if a.x >= b.x and a.x < b.x + b.width then
		if a.y >= b.y and a.y < b.y + b.height then
			return true
		end
		return math.abs( math.min( a.y - b.y, a.y - b.y - b.height ) ) <= a.size
	elseif a.y >= b.y and a.y < b.y + b.height then
		return math.abs( math.min( a.x - b.x, a.x - b.x - b.width ) ) <= a.size
	else
		local corners = { {b.x, b.y}, {b.x + b.width, b.y}, {b.x + b.width, b.y + b.height}, {b.x, b.y + b.height} }
		local cs2 = a.size * a.size
		for i = 1, #corners do
			if (a.x - corners[i][1]) ^ 2 + (a.y - corners[i][2]) ^ 2 <= cs2 then
				return true
			end
		end
	end
end

local function newObject( x, y, form )
	local t = { x = x, y = y, form = form }
	world[#world + 1] = t

	function t:update( dt ) end
	function t:draw() end
	function t:onCollision( object ) end

	function t:remove()
		for i = #world, 1, -1 do
			if world[i] == self then
				table.remove( world, i )
				break
			end
		end
	end

	return t
end

local function newRectangleObject( x, y, width, height )
	local t = newObject( x, y, FORM_RECTANGLE )
	t.width = width
	t.height = height

	function t:draw()
		love.graphics.rectangle( "fill", self.x, self.y, self.width, self.height )
	end

	return t
end

local function newCircleObject( x, y, radius )
	local t = newObject( x, y, FORM_CIRCLE )
	t.size = radius

	function t:draw()
		love.graphics.circle( "fill", self.x, self.y, self.size )
	end

	return t
end

local function newEnemyObject()
	local x, y, xv, yv, size = randomSideLocation()
	local object = newCircleObject( x, y, size )

	object.xv = xv
	object.yv = yv
	object.colour = { math.random() * 200, math.random() * 200, math.random() * 200 }

	function object:draw()
		love.graphics.setColor( self.colour )
		love.graphics.draw( image1, self.x - self.size, self.y - self.size, 0, 2 * self.size / circResolution, 2 * self.size / circResolution )
	end

	function object:update( dt )
		self.x = self.x + self.xv * dt
		self.y = self.y + self.yv * dt

		if self.x + self.size < 0 or self.x - self.size > windowWidth() or self.y + self.size < 0 or self.y - self.size > windowHeight() then
			self:remove()
		end
	end

	function object:onCollision( other )
		if other == player then
			if player.size >= self.size then
				player.size = player.size + SIZE_GAIN * self.size
				self:remove()
				score = score + 1
			else
				endgame()
			end
		end
	end
end

love.graphics.setBackgroundColor( 240, 240, 240 )

function love.update( dt )
	local collisions = {}

	if running then
		for i = #world, 1, -1 do
			world[i]:update( dt )
		end

		for i = 1, #world do
			for n = i + 1, #world do
				local a, b = world[i], world[n]
				if a.form == FORM_CIRCLE and b.form == FORM_CIRCLE then
					if circIntersectCirc( a, b ) then
						collisions[#collisions + 1] = { a, b }
					end
				elseif a.form == FORM_RECTANGLE and b.form == FORM_RECTANGLE then
					if rectIntersectRect( a, b ) then
						collisions[#collisions + 1] = { a, b }
					end
				elseif a.form == FORM_CIRCLE and b.form == FORM_RECTANGLE then
					if circIntersectRect( a, b ) then
						collisions[#collisions + 1] = { a, b }
					end
				elseif a.form == FORM_RECTANGLE and b.form == FORM_CIRCLE then
					if circIntersectRect( b, a ) then
						collisions[#collisions + 1] = { a, b }
					end
				end
			end
		end

		for i = 1, #collisions do
			collisions[i][1]:onCollision( collisions[i][2] )
			collisions[i][2]:onCollision( collisions[i][1] )
		end

		while timers.spawnCounter >= 1 / SPAWNRATE do
			timers.spawnCounter = timers.spawnCounter - 1 / SPAWNRATE
			newEnemyObject()
		end
	end

	for k, v in pairs( timers ) do
		timers[k] = v + dt
	end
end

function love.draw()
	for i = 1, #world do
		world[i]:draw()
	end

	love.graphics.setColor( 0, 0, 0, 240 )
	love.graphics.setFont( font )
	love.graphics.print( score, 0, 0 )

	if not running then
		love.graphics.print( ENDGAMETEXT, windowWidth() / 2 - font:getWidth( ENDGAMETEXT ) / 2, windowHeight() / 2 - font:getHeight() / 2 )
	end
end

function love.keypressed( key )
	if not running and key == "space" then
		running = true
		score = 0
		timers.spawnCounter = 0
		player.size = INITIAL_PLAYER_SIZE

		while world[2] do
			world[#world] = nil
		end
	end
end

function love.mousepressed()
	if not running then
		running = true
		score = 0
		timers.spawnCounter = 0
		player.size = INITIAL_PLAYER_SIZE

		while world[2] do
			world[#world] = nil
		end
	end
end

function endgame()
	running = false
end

player = newCircleObject( 0, 0, INITIAL_PLAYER_SIZE )

function player:draw()
	love.graphics.setColor( 40, 80, 240 )
	love.graphics.draw( image1, self.x - self.size, self.y - self.size, 0, 2 * self.size / circResolution, 2 * self.size / circResolution )
end

function player:update( dt )
	local mx, my = love.mouse.getPosition()
	local dx, dy = mx - self.x, my - self.y
	local l = math.sqrt( dx * dx + dy * dy )
	local nx, ny = l == 0 and 0 or dx / l, l == 0 and 0 or dy / l
	local cx, cy = nx * sigmoid( l / 20 ) * POINTER_MAX_SPEED * dt, ny * sigmoid( l / 20 ) * POINTER_MAX_SPEED * dt

	if math.abs( cx ) > math.abs( dx ) then
		cx = dx
	end

	if math.abs( cy ) > math.abs( dy ) then
		cy = dy
	end

	self.x = self.x + cx
	self.y = self.y + cy

	self.size = self.size - dt * SIZE_LOSS * self.size

	if self.size < 10 then
		endgame()
	end
end
