--!strict
-- "Say howdy" is a greeting, not a private menu. Typing it in chat (TextChatService
-- or the older chat) and the King's proximity prompt both count. The word has to
-- stand on its own so "showdown" does not greet the yard.
local Howdy = {}

function Howdy.isGreeting(text: any): boolean
	if type(text) ~= "string" then
		return false
	end
	local cleaned = string.lower(text)
	cleaned = string.gsub(cleaned, "[^%a']", " ")
	for word in string.gmatch(cleaned, "%S+") do
		if word == "howdy" then
			return true
		end
	end
	return false
end

-- The King's bottle is the only reward, and only after dark in a cowboy hat,
-- once a day. A daytime howdy still waves. It just doesn't pay.
function Howdy.rewardDue(night: boolean, cowboy: boolean, already: boolean): boolean
	return night and cowboy and not already
end

return Howdy
