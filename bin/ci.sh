rojo build --output model.rbxmx
roblox-cli analyze default.project.json
roblox-cli run --load.model model.rbxmx --run bin/spec.lua --fastFlags.overrides EnableLoadModule=true --lua.globals=__DEV__=true
