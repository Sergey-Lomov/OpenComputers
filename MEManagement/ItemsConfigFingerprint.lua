ItemsConfigFingerprint = {}

function ItemsConfigFingerprint:new(id, damage, nbtHash, title)
	local fingerprint = {}
	fingerprint.id = id
	fingerprint.damage = damage
	fingerprint.nbtHash = nbtHash
	fingerprint.title = title

	setmetatable(fingerprint, self)

	return fingerprint
end

function ItemsConfigFingerprint:toMEFormat()
	return {
		id = self.id,
		dmg = self.damage,
		nbt_hash = self.nbtHash
	}
end

function ItemsConfigFingerprint.fromRaw(raw)
	local fingerprint = {}
	fingerprint.id = raw.id
	fingerprint.damage = raw.damage
	fingerprint.nbtHash = raw.nbtHash
	fingerprint.title = raw.title

	setmetatable(fingerprint, ItemsConfigFingerprint)

	return fingerprint
end

ItemsConfigFingerprint.__eq = function (f1, f2)
	return f1.id == f2.id and f1.damage == f2.damage and f1.nbtHash == f2.nbtHash and f1.title == f2.title
end

ItemsConfigFingerprint.__index = ItemsConfigFingerprint