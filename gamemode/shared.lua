GM.Name = "BaseWars"
GM.Author = "Brov3r"

BW = BW or {}

DeriveGamemode("SandBox")

function GM:GetFallDamage(ply, speed)
	return math.max( 0, math.ceil( 0.2418 * speed - 141.75 ) )
end