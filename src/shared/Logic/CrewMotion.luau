--!strict
-- Shared walk math. The server and every client use the same clock and the same points,
-- so a hire can leave from the pose players already see.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")

local CrewMotion = {}

export type Vec = { number }

local function v(x: number, y: number, z: number): Vec
	return { x, y, z }
end

function CrewMotion.decode(text: any): { Vec }
	local points = {}
	if type(text) ~= "string" then
		return points
	end
	for chunk in string.gmatch(text, "[^|]+") do
		local xs, ys, zs = string.match(chunk, "([^,]+),([^,]+),([^,]+)")
		local x, y, z = tonumber(xs), tonumber(ys), tonumber(zs)
		if x and y and z then
			table.insert(points, v(x, y, z))
		end
	end
	return points
end

function CrewMotion.encode(points: { Vec }): string
	local bits = {}
	for _, p in ipairs(points) do
		table.insert(bits, string.format("%.2f,%.2f,%.2f", p[1], p[2], p[3]))
	end
	return table.concat(bits, "|")
end

function CrewMotion.length(points: { Vec }): number
	local total = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		total += math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	return total
end

local function along(points: { Vec }, distance: number): (Vec, Vec)
	local remain = distance
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local span = math.sqrt(dx * dx + dy * dy + dz * dz)
		if remain <= span or i == #points - 1 then
			local alpha = if span > 0.05 then math.clamp(remain / span, 0, 1) else 0
			return v(a[1] + dx * alpha, a[2] + dy * alpha, a[3] + dz * alpha), v(dx, dy, dz)
		end
		remain -= span
	end
	local last = points[#points]
	return v(last[1], last[2], last[3]), v(0, 0, -1)
end

-- Where the client is drawing this critter at `now` (server time), bob included.
function CrewMotion.pose(points: { Vec }, now: number, speed: number, phase: number, kind: string, startAt: number?): (number, number, number)
	if #points < 2 then
		local p = points[1] or v(0, 0, 0)
		return p[1], p[2], p[3]
	end
	local pace = if speed > 0 then speed else 4
	local span = math.max(CrewMotion.length(points), 0.05)
	local distance
	if kind == "once" then
		local began = startAt or now
		distance = math.clamp((now - began) * pace, 0, span)
	else
		distance = (now * pace + phase * 1.7) % span
	end
	local pos = along(points, distance)
	local bob = math.abs(math.sin(now * 8 + phase)) * 0.22
	return pos[1], pos[2] + bob, pos[3]
end

-- full, cheap (a few times a second, no bob), or freeze.
function CrewMotion.detail(distance: number, near: number?, far: number?): string
	local close = near or Config.CrewLod.near
	local away = far or Config.CrewLod.far
	if distance >= away then
		return "freeze"
	elseif distance >= close then
		return "cheap"
	end
	return "full"
end

local function flatDist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	return math.sqrt(dx * dx + dz * dz)
end

-- From the line to a ranch: skirt the middle of the square (Big Bertha sits there),
-- then follow the road out, then the gate. Speed stays a walk.
function CrewMotion.homePath(fromX: number, fromY: number, fromZ: number, plotX: number, plotZ: number, greetX: number, greetZ: number): { Vec }
	local dx, dz = plotX, plotZ
	local mag = math.sqrt(dx * dx + dz * dz)
	if mag < 1 then
		dx, dz, mag = 0, -1, 1
	end
	local ux, uz = dx / mag, dz / mag
	-- Perpendicular, picked so the skirt stays off the smoker in the middle.
	local sx, sz = -uz, ux
	if sx * fromX + sz * fromZ < 0 then
		sx, sz = -sx, -sz
	end
	local skirt = v(sx * 36, fromY, sz * 36 - 8)
	local road = v(ux * 78, fromY, uz * 78)
	local gate = v(greetX, fromY, greetZ)
	local start = v(fromX, fromY, fromZ)
	-- Drop a point that would sit on top of the previous one.
	local path = { start }
	for _, p in ipairs({ skirt, road, gate }) do
		local prev = path[#path]
		if flatDist(prev[1], prev[3], p[1], p[3]) > 6 then
			table.insert(path, p)
		end
	end
	if #path < 2 then
		table.insert(path, gate)
	end
	return path
end

function CrewMotion.walkSeconds(points: { Vec }, speed: number?): number
	local pace = if speed and speed > 0 then speed else Config.Hiring.walkSpeed
	return CrewMotion.length(points) / pace
end

return CrewMotion
