--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local MANIFESTS = { "ember.toml" }
local SKIP = { [".lest"] = true, ["Packages"] = true, ["roblox_packages"] = true }

local function fail(message: string): never
	stdio.ewrite(`✗ {message}\n`)
	process.exit(1)
	error("unreachable")
end

local function libDir(lib: string?): string
	if not lib or lib == "" then
		fail("missing library name")
	end
	local dir = if lib == "template" then "template" else `libraries/{lib}`
	if not fs.isDir(dir) then
		fail(`no directory {dir}`)
	end
	return dir
end

local function parseVersion(version: string): (number, number, number)
	local major, minor, patch = string.match(version, "^(%d+)%.(%d+)%.(%d+)$")
	if not major then
		fail(`invalid version '{version}', expected x.y.z`)
	end
	return tonumber(major) :: number, tonumber(minor) :: number, tonumber(patch) :: number
end

local function readVersion(path: string): string?
	return string.match("\n" .. fs.readFile(path), '\nversion%s*=%s*"([^"]*)"')
end

local function writeVersion(path: string, version: string)
	local content, count = string.gsub("\n" .. fs.readFile(path), '\nversion%s*=%s*"[^"]*"', `\nversion = "{version}"`, 1)
	if count == 0 then
		fail(`no version field in {path}`)
	end
	fs.writeFile(path, string.sub(content, 2))
end

local function manifestsOf(dir: string): { string }
	local paths = {}
	for _, name in MANIFESTS do
		local path = `{dir}/{name}`
		if fs.isFile(path) then
			table.insert(paths, path)
		end
	end
	if #paths == 0 then
		fail(`no manifest in {dir}`)
	end
	return paths
end

local function currentVersion(dir: string): string
	local version: string? = nil
	for _, path in manifestsOf(dir) do
		local found = readVersion(path)
		if version and found ~= version then
			fail(`versions differ between manifests in {dir}, run \`just version <lib> x.y.z\` to realign them`)
		end
		version = found
	end
	return version :: string
end

local function setVersion(dir: string, version: string)
	parseVersion(version)
	for _, path in manifestsOf(dir) do
		writeVersion(path, version)
		print(`{path} -> {version}`)
	end
end

local function libraries(): { string }
	local dirs = {}
	for _, name in fs.readDir("libraries") do
		if fs.isFile(`libraries/{name}/ember.toml`) then
			table.insert(dirs, `libraries/{name}`)
		end
	end
	table.sort(dirs)
	return dirs
end

local function run(dir: string, command: { string })
	print(`\n> {dir}: {table.concat(command, " ")}`)
	local result = process.exec(command[1], { table.unpack(command, 2) }, { cwd = dir, shell = true, stdio = "inherit" })
	if not result.ok then
		fail(`'{table.concat(command, " ")}' failed in {dir} (exit {result.code})`)
	end
end

local function copyTemplate(from: string, to: string, replace: (content: string) -> string)
	if not fs.isDir(to) then
		fs.writeDir(to)
	end
	for _, name in fs.readDir(from) do
		if SKIP[name] then
			continue
		end
		local source, target = `{from}/{name}`, `{to}/{name}`
		if fs.isDir(source) then
			copyTemplate(source, target, replace)
		elseif not fs.isFile(target) or fs.readFile(target) == "" then
			fs.writeFile(target, replace(fs.readFile(source)))
		end
	end
end

local commands = {}

function commands.version(lib: string?, version: string?)
	local dir = libDir(lib)
	if version and version ~= "" then
		setVersion(dir, version)
	else
		for _, path in manifestsOf(dir) do
			print(`{path}: {readVersion(path) or "?"}`)
		end
	end
end

function commands.bump(lib: string?, kind: string?)
	local dir = libDir(lib)
	local major, minor, patch = parseVersion(currentVersion(dir))
	if kind == "major" then
		major, minor, patch = major + 1, 0, 0
	elseif kind == "minor" then
		minor, patch = minor + 1, 0
	elseif kind == "patch" or kind == nil then
		patch += 1
	else
		fail(`unknown bump '{kind}', expected major, minor or patch`)
	end
	setVersion(dir, `{major}.{minor}.{patch}`)
end

function commands.versions()
	for _, dir in libraries() do
		print(`{dir}: {currentVersion(dir)}`)
	end
end

function commands.new(name: string?)
	if not name or not string.match(name, "^%a[%w]*$") then
		fail("expected a PascalCase library name, e.g. `just new Signal`")
	end
	local kebab = string.lower((string.gsub(name :: string, "(%l)(%u)", "%1-%2")))
	local dir = `libraries/{name}`
	copyTemplate("template", dir, function(content)
		-- Keeps whatever scope the template uses, only the package name changes (every
		-- library shares the monorepo's repository).
		content = string.gsub(content, '/template"', `/{kebab}"`)
		content = string.gsub(content, "/docs/template", `/docs/{kebab}`)
		content = string.gsub(content, '"name": "template"', `"name": "{name}"`)
		content = string.gsub(content, "Template", name :: string)
		return content
	end)
	print(`created {dir} (package name: {kebab})`)
end

function commands.run(lib: string?, ...: string)
	local command = { ... }
	if #command == 0 then
		fail("missing command")
	end
	run(libDir(lib), command)
end

function commands.each(...: string)
	local command = { ... }
	if #command == 0 then
		fail("missing command")
	end
	for _, dir in libraries() do
		run(dir, command)
	end
end

type SourcemapNode = {
	name: string,
	className: string,
	filePaths: { string }?,
	children: { SourcemapNode }?,
}

local function moduleNode(name: string, path: string): SourcemapNode?
	if fs.isFile(path) then
		return { name = name, className = "ModuleScript", filePaths = { path } }
	end

	local init = `{path}/init.luau`
	if not fs.isFile(init) then
		return nil
	end

	local children = {}
	for _, child in fs.readDir(path) do
		local childName = string.match(child, "^(.+)%.luau$") or child
		if child ~= "init.luau" then
			local node = moduleNode(childName, `{path}/{child}`)
			if node then
				table.insert(children, node)
			end
		end
	end
	table.sort(children, function(a: SourcemapNode, b: SourcemapNode)
		return a.name < b.name
	end)

	-- serde writes an empty table as `{}`, which isn't a valid children array
	return { name = name, className = "ModuleScript", filePaths = { init }, children = if #children > 0 then children else nil }
end

-- Every library sits next to the others, the same way package managers install
-- dependencies, so luau-lsp resolves requires like `script.Parent.Thread`.
-- Packages installed in a library's `Packages` folder, like Weight's Cryptography,
-- sit next to them too.
function commands.sourcemap()
	local children = {}
	local names = {}
	for _, dir in libraries() do
		local name = string.match(dir, "[^/]+$") :: string
		local node = moduleNode(name, `{dir}/src`)
		if node then
			table.insert(children, node)
			names[name] = true
		end
	end

	for _, dir in libraries() do
		local packages = `{dir}/Packages`
		if fs.isDir(packages) then
			for _, entry in fs.readDir(packages) do
				local name = string.match(entry, "^(.+)%.luau?$") or entry
				local node = if names[name] then nil else moduleNode(name, `{packages}/{entry}`)
				if node then
					table.insert(children, node)
					names[name] = true
				end
			end
		end
	end

	local sourcemap: SourcemapNode = { name = "libraries", className = "Folder", children = children }
	fs.writeFile("sourcemap.json", serde.encode("json", sourcemap))
end

local name = process.args[1]
local command = commands[name]
if not command then
	fail(`unknown command '{name}'`)
end
command(table.unpack(process.args, 2))
