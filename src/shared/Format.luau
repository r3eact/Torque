-- Number / time formatting helpers shared by server (signs, billboards) and client (UI).
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn", "Sx" }

-- 1234 -> "1.23K", 1500000 -> "1.5M"
function Format.Short(n: number?): string
	local value = math.floor(n or 0)
	if math.abs(value) < 1000 then
		return tostring(value)
	end
	local v: number = value
	local i = 1
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local s: string
	if math.abs(v) >= 100 then
		s = string.format("%.0f", v)
	elseif math.abs(v) >= 10 then
		s = string.format("%.1f", v)
	else
		s = string.format("%.2f", v)
	end
	if string.find(s, "%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567"
function Format.Commas(n: number?): string
	local s = tostring(math.floor(n or 0))
	local negative = string.sub(s, 1, 1) == "-"
	if negative then
		s = string.sub(s, 2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (negative and "-" or "") .. out
end

-- 3725 -> "1h 02m", 125 -> "2m 05s", 9 -> "9s"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

return Format
