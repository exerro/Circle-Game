
love.graphics.setBackgroundColor( 255, 255, 255 )

 -- Circles

function circle( x, y, r, xv, yv )
	local c = { }
	c.x = x
	c.y = y
	c.r = r
	c.xv = xv
	c.yv = yv
	c.colour = {
		math.random( 0, 255 );
		math.random( 0, 255 );
		math.random( 0, 255 );
	}
	-- like:
	-- c.colour = array of 3 random colours
	function c:draw( )
		love.graphics.setColor( unpack( self.colour ) )
		love.graphics.circle( "fill", self.x, self.y, self.r )
	end
	function c:update( dt )
		self.x = self.x + self.xv * dt
		self.y = self.y + self.yv * dt
	end
	function c:near( c )
		local dx, dy = self.x - c.x, self.y - c.y
		local dist = math.sqrt( dx ^ 2 + dy ^ 2 )
		if dist < self.r + c.r then
			return true
		end
		return false
	end
	return c
end

function generate( )
	local side = math.random( 1, 4 )
	local x, y, dir
	if side == 1 then
		x, y = 0, math.random( 0, love.window.getHeight( ) )
		dir = math.random( 0, 180 )
	elseif side == 2 then
		x, y = math.random( 0, love.window.getWidth( ) ), 0
		dir = math.random( 0, 180 ) - 90
	elseif side == 3 then
		x, y = love.window.getWidth( ), math.random( 0, love.window.getHeight( ) )
		dir = math.random( 180, 360 )
	elseif side == 4 then
		x, y = math.random( 0, love.window.getWidth( ) ), love.window.getHeight( )
		dir = math.random( 0, 180 ) - 90
		dir = math.random( 90, 270 )
	end
	dir = dir * math.pi / 180
	local speed = math.random( 100, 320 )
	local size = math.random( 2, 50 )
	local xv, yv = math.sin( dir ) * speed, math.cos( dir ) * speed
	return circle( x, y, size, xv, yv )
end

local circles = { }
local last = 0
local main = circle( 0, 0, 5, 0, 0 )

function love.update( dt )
	main.x, main.y = love.mouse.getPosition( )
	for i = #circles, 1, -1 do
		circles[i]:update( dt )
		if circles[i]:near( main ) then
			if circles[i].r <= main.r then
				main.r = main.r + 1
				table.remove( circles, i )
			else
				love.event.quit( )
			end
		end
	end
	if love.timer.getTime( ) - last > 0.1 then
		last = love.timer.getTime( )
		table.insert( circles, generate( ) )
	end
end

function love.draw( )
	for i = 1,#circles do
		circles[i]:draw( )
	end
	main:draw( )
end
