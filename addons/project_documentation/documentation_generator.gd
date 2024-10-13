#@tool
class_name DocumentationGenerator

# Global variables to store collected data
var project_info := {}
var scenes_info := {}
var scripts_info := {}
var resources_info := {}
var shaders_info := {}
var autoload_scripts := {}

# Configuration options
var export_scene_tree := true
var export_signal_connections := true
var export_changed_properties := true
var export_node_groups := true
var export_scripts := true
var export_resources := true
var export_shaders := true

# Configuration options
var options = {}

func set_options(new_options):
	options = new_options
	# Update configuration options based on the passed options
	export_scene_tree = options.get("export_scene_tree", true)
	export_signal_connections = options.get("export_signal_connections", true)
	export_changed_properties = options.get("export_changed_properties", true)
	export_node_groups = options.get("export_node_groups", true)
	export_scripts = options.get("export_scripts", true)
	export_resources = options.get("export_resources", true)
	export_shaders = options.get("export_shaders", true)

func generate():
	# Phase 1: Data Collection
	collect_project_info()
	collect_scenes_info()
	collect_scripts_info()
	collect_resources_info()
	collect_shaders_info()
	collect_autoload_scripts()

	# Phase 2: Data Processing
	process_scene_data()
	process_script_data()
	process_resource_data()
	process_shader_data()

	# Phase 3: Output Formatting
	var output := "### %s\n\n" % project_info["godot_version"]
	output += format_project_info()
	output += "\n#### Scenes\n"
	output += format_scenes_info()
	output += "\n#### Scripts\n"
	output += format_scripts_info()
	output += "\n#### Resources\n"
	output += format_resources_info()
	output += "\n#### Shaders\n"
	output += format_shaders_info()

	# Write output to file
	write_output_to_file(output)

# Phase 1: Data Collection Functions

func collect_project_info():
	project_info["godot_version"] = get_detailed_godot_version()
	project_info["overridden_settings"] = get_overridden_project_settings_grouped()

func collect_scenes_info():
	var scene_paths = get_all_resource_paths("res://", true, ["tscn", "scn"])
	for scene_path in scene_paths:
		var scene = load(scene_path) as PackedScene
		if scene:
			var state = scene.get_state()
			scenes_info[scene_path] = {
				"state": state,
				"node_count": state.get_node_count(),
				"connection_count": state.get_connection_count()
			}

func collect_scripts_info():
	for scene_path in scenes_info:
		var state = scenes_info[scene_path]["state"]
		for i in range(scenes_info[scene_path]["node_count"]):
			var script = get_node_script(state, i)
			if script:
				var script_path = script.resource_path
				if script_path not in scripts_info:
					scripts_info[script_path] = {
						"content": get_script_content(script_path)
					}

func collect_resources_info():
	for scene_path in scenes_info:
		var state = scenes_info[scene_path]["state"]
		for i in range(scenes_info[scene_path]["node_count"]):
			collect_node_resources(state, i)

func collect_shaders_info():
	for resource_path in resources_info:
		var resource = resources_info[resource_path]
		if resource["instance"] is ShaderMaterial:
			var shader = resource["instance"].shader
			if shader:
				var shader_path = shader.resource_path
				if shader_path not in shaders_info:
					shaders_info[shader_path] = {
						"type": shader.get_class(),
						"code": shader.code
					}

func collect_autoload_scripts():
	var autoload_settings = project_info["overridden_settings"].get("autoload", [])
	for setting in autoload_settings:
		var script_path = setting["value"].strip_edges()
		var is_enabled = true
		if script_path.begins_with("*"):
			script_path = script_path.substr(1)
			is_enabled = false
		autoload_scripts[setting["key"]] = {
			"path": script_path,
			"enabled": is_enabled,
			"content": get_script_content(script_path)
		}

# Phase 2: Data Processing Functions

func process_scene_data():
	for scene_path in scenes_info:
		var scene_data = scenes_info[scene_path]
		scene_data["tree"] = build_scene_tree(scene_data["state"]) if export_scene_tree else ""
		scene_data["connections"] = get_signal_connections(scene_data["state"]) if export_signal_connections else ""
		scene_data["nodes"] = get_nodes_info(scene_data["state"]) if export_changed_properties else ""
		scene_data["groups"] = get_node_groups(scene_data["state"]) if export_node_groups else {}

func process_script_data():
	# Add autoload scripts to scripts_info
	for autoload_name in autoload_scripts:
		var script_info = autoload_scripts[autoload_name]
		scripts_info[script_info["path"]] = {
			"content": script_info["content"],
			"autoload": autoload_name,
			"enabled": script_info["enabled"]
		}

func process_resource_data():
	# Remove scripts and shaders from resources_info
	var to_remove = []
	for resource_path in resources_info:
		var resource = resources_info[resource_path]
		if resource["instance"] is Script or resource["instance"] is Shader or resource["type"] == "Shader":
			to_remove.append(resource_path)
		else:
			resource["changed_properties"] = get_changed_resource_properties(resource["instance"])
	for path in to_remove:
		resources_info.erase(path)

	# Process sub-resources
	var sub_resources = {}
	for resource_path in resources_info:
		var resource = resources_info[resource_path]
		for prop_name in resource["changed_properties"]:
			var prop_value = resource["changed_properties"][prop_name]
			if prop_value is Resource:
				var sub_resource_path = prop_value.resource_path
				if sub_resource_path and sub_resource_path not in resources_info:
					# Check if the sub-resource is not a Shader
					if not (prop_value is Shader or prop_value.get_class() == "Shader"):
						sub_resources[sub_resource_path] = {
							"instance": prop_value,
							"type": prop_value.get_class(),
							"changed_properties": get_changed_resource_properties(prop_value)
						}
	
	# Add sub-resources to resources_info
	resources_info.merge(sub_resources)
	
func process_shader_data():
	pass # No additional processing needed for shaders in this implementation

# Phase 3: Output Formatting Functions

func format_project_info() -> String:
	var output = "[details=\"Project Settings\"]\n"
	for section in project_info["overridden_settings"]:
		output += "###### %s\n" % section
		output += "```plaintext\n"
		for setting in project_info["overridden_settings"][section]:
			if section == "autoload":
				var script_path = setting["value"].strip_edges()
				var is_enabled = true
				if script_path.begins_with("*"):
					script_path = script_path.substr(1)
					is_enabled = false
				output += "%s: %s (%s)\n" % [setting["key"], script_path, "enabled" if is_enabled else "disabled"]
			else:
				output += "%s: %s\n" % [setting["key"], setting["value"]]
		output += "```\n\n"
	output += "[/details]\n\n"
	return output

func format_scenes_info() -> String:
	var output = ""
	for scene_path in scenes_info:
		var scene_data = scenes_info[scene_path]
		output += "##### %s\n\n" % scene_path
		output += format_scene_tree(scene_data["tree"])
		output += format_signal_connections(scene_data["connections"])
		output += format_nodes_info(scene_data["nodes"])
		output += "\n"
	return output

func format_scene_tree(tree: Dictionary) -> String:
	var output = "[details=\"Scene Tree\"]\n```plaintext\n"
	for node in tree["nodes"]:
		var indent = "  ".repeat(node["indent"])
		output += "%s%s (%s%s)" % [indent, node["name"], node["type"], " %s" % node["instance_path"] if "instance_path" in node else ""]
		if "groups" in node and not node["groups"].is_empty():
			output += " [Groups: %s]" % ", ".join(node["groups"])
		output += "\n"
	output += "```\n[/details]\n\n"
	return output

func format_signal_connections(connections: String) -> String:
	var output = "[details=\"Signal Connections\"]\n```plaintext\n"
	output += connections if connections else "None\n"
	output += "```\n[/details]\n\n"
	return output

func format_nodes_info(nodes: Array) -> String:
	var output = "[details=\"Nodes\"]\n"
	for node in nodes:
		output += "###### %s (%s%s)\n" % [node["path"], node["type"], " %s" % node["instance_path"] if "instance_path" in node else ""]
		
		if "script" in node:
			output += "Script: %s\n" % node["script"]
		
		if not node["groups"].is_empty():
			output += "Groups: %s\n" % ", ".join(node["groups"])
		
		output += "Changed Properties:\n"
		if node["changed_properties"]:
			output += "```gdscript\n"
			for prop in node["changed_properties"]:
				output += "  %s = %s\n" % [prop["name"], prop["value"]]
			output += "```\n"
		else:
			output += "  None\n"
		output += "\n"
	output += "[/details]\n\n"
	return output
	
func format_scripts_info() -> String:
	var output = ""
	for script_path in scripts_info:
		var script_info = scripts_info[script_path]
		output += "[details=\"%s\"]\n" % script_path
		if "autoload" in script_info:
			output += "Autoload: %s (%s)\n\n" % [script_info["autoload"], "enabled" if script_info["enabled"] else "disabled"]
		output += "```gdscript\n%s\n```\n[/details]\n\n" % script_info["content"]
	return output

func format_resources_info() -> String:
	var output = ""
	for resource_path in resources_info:
		var resource = resources_info[resource_path]
		output += "[details=\"%s\"]\n" % resource_path
		output += "Type: %s\n\n" % resource["type"]
		output += "Changed Properties:\n"
		if resource["changed_properties"].is_empty():
			output += "None\n"
		else:
			output += "```gdscript\n"
			for prop in resource["changed_properties"]:
				output += "  %s: %s\n" % [prop, format_resource_value(resource["changed_properties"][prop])]
			output += "```\n"
		output += "[/details]\n\n"
	return output

func format_shaders_info() -> String:
	var output = ""
	for shader_path in shaders_info:
		var shader_info = shaders_info[shader_path]
		output += "[details=\"%s\"]\n" % shader_path
		#output += "Type: %s\n\n" % shader_info["type"]
		output += "```glsl\n%s\n```\n[/details]\n\n" % shader_info["code"]
	return output

# Utility Functions

func write_output_to_file(output: String):
	var file_path = "res://project_documentation.txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()
		print("Documentation generated at: " + file_path)
	else:
		push_error("Failed to open file for writing.")

func get_detailed_godot_version() -> String:
	var version_info = Engine.get_version_info()
	return version_info["string"] + " " + version_info["hash"].substr(0, 9)

func get_overridden_project_settings_grouped() -> Dictionary:
	var overridden = {}
	var config = ConfigFile.new()
	var err = config.load("res://project.godot")
	if err != OK:
		push_error("Error loading project.godot: %s" % err)
		return overridden
	
	for section in config.get_sections():
		for key in config.get_section_keys(section):
			var full_path = section + "/" + key
			var value = ProjectSettings.get_setting(full_path)
			if not overridden.has(section):
				overridden[section] = []
			overridden[section].append({"key": key, "value": value})
	
	return overridden

func get_all_resource_paths(directory_path: String, include_subdirectories: bool = true, extensions_filter: Array[String] = []) -> Array[String]:
	var file_paths: Array[String] = []
	var dir = DirAccess.open(directory_path)
	if not dir:
		push_error("Failed to open directory: %s" % directory_path)
		return file_paths

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if include_subdirectories:
				var sub_dir = directory_path.path_join(file_name)
				file_paths.append_array(get_all_resource_paths(sub_dir, true, extensions_filter))
		else:
			var extension = file_name.get_extension().to_lower()
			if extensions_filter.is_empty() or extension in extensions_filter:
				file_paths.append(directory_path.path_join(file_name))
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return file_paths

func get_node_script(state: SceneState, node_idx: int) -> Script:
	var property_count = state.get_node_property_count(node_idx)
	for i in range(property_count):
		if state.get_node_property_name(node_idx, i) == "script":
			return state.get_node_property_value(node_idx, i) as Script
	return null

func get_script_content(script_path: String) -> String:
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	return "Failed to read script content"

func collect_node_resources(state: SceneState, node_idx: int):
	var property_count = state.get_node_property_count(node_idx)
	for i in range(property_count):
		var value = state.get_node_property_value(node_idx, i)
		collect_resource_recursive(value)

func collect_resource_recursive(value):
	if value is Resource:
		var resource_path = value.resource_path
		if resource_path not in resources_info:
			resources_info[resource_path] = {
				"instance": value,
				"type": value.get_class()
			}
			# Recursively collect sub-resources
			for property in value.get_property_list():
				if property["usage"] & PROPERTY_USAGE_STORAGE:
					var sub_value = value.get(property.name)
					collect_resource_recursive(sub_value)

func build_scene_tree(state: SceneState) -> Dictionary:
	var tree = {"nodes": []}
	var node_count = state.get_node_count()
	for i in range(node_count):
		var node_name = state.get_node_name(i)
		var node_type = state.get_node_type(i)
		var node_path = state.get_node_path(i)
		
		var node_info = {
			"name": node_name,
			"type": node_type,
			"path": node_path,
			"indent": node_path.get_name_count() - 1
		}
		
		# Check if the node is an instance of a scene
		var instance = state.get_node_instance(i)
		if instance:
			node_info["instance_path"] = instance.resource_path
		
		# Add script information
		var script = get_node_script(state, i)
		if script:
			node_info["script"] = script.resource_path
		
		if export_node_groups:
			var groups = state.get_node_groups(i)
			if groups:
				node_info["groups"] = groups
		
		tree["nodes"].append(node_info)
	
	return tree


func get_node_connections(state: SceneState, node_path: NodePath) -> Array:
	var connections = []
	var connection_count = state.get_connection_count()
	for i in range(connection_count):
		var source = state.get_connection_source(i)
		if source == node_path:
			connections.append("(%d)" % (i + 1))
	return connections


func get_signal_connections(state: SceneState) -> String:
	var output = "  Signal Connections:\n"
	var connection_count = state.get_connection_count()
	for i in range(connection_count):
		var source = state.get_connection_source(i)
		var signal_name = state.get_connection_signal(i)
		var target = state.get_connection_target(i)
		var method = state.get_connection_method(i)
		var flags = state.get_connection_flags(i)
		output += "    %s.%s -> %s.%s (Flags: %s)\n" % [source, signal_name, target, method, get_connection_flags_string(flags)]
	return output if connection_count > 0 else "  Signal Connections:\n    None\n"


func get_connection_flags_string(flags: int) -> String:
	var flag_strings = []
	if flags & CONNECT_DEFERRED:
		flag_strings.append("DEFERRED")
	if flags & CONNECT_PERSIST:
		flag_strings.append("PERSIST")
	if flags & CONNECT_ONE_SHOT:
		flag_strings.append("ONE_SHOT")
	return ", ".join(flag_strings) if flag_strings else "NONE"

func get_nodes_info(state: SceneState) -> Array:
	var nodes_info = []
	var node_count = state.get_node_count()
	for i in range(node_count):
		var node_name = state.get_node_name(i)
		var node_type = state.get_node_type(i)
		var node_path = state.get_node_path(i)
		var script = get_node_script(state, i)
		var property_count = state.get_node_property_count(i)
		var changed_props = []
		
		var node_info = {
			"name": node_name,
			"type": node_type,
			"path": node_path,
			"groups": state.get_node_groups(i)
		}
		
		# Check if the node is an instance of a scene
		var instance = state.get_node_instance(i)
		if instance:
			node_info["instance_path"] = instance.resource_path
		
		if script:
			node_info["script"] = script.resource_path
		
		for j in range(property_count):
			var prop_name = state.get_node_property_name(i, j)
			if prop_name == "script":
				continue
			var prop_value = state.get_node_property_value(i, j)
			var default_value = ClassDB.class_get_property_default_value(node_type, prop_name)
			if prop_value != default_value:
				changed_props.append({"name": prop_name, "value": format_resource_value(prop_value)})
		
		node_info["changed_properties"] = changed_props
		
		nodes_info.append(node_info)
	
	return nodes_info
	
func get_node_groups(state: SceneState) -> Dictionary:
	var groups = {}
	var node_count = state.get_node_count()
	for i in range(node_count):
		var node_groups = state.get_node_groups(i)
		if not node_groups.is_empty():
			var node_path = state.get_node_path(i)
			groups[node_path] = node_groups
	return groups

func get_changed_resource_properties(resource: Resource) -> Dictionary:
	var changed_properties = {}
	var property_list = resource.get_property_list()
	for property in property_list:
		if property["usage"] & PROPERTY_USAGE_STORAGE:
			var prop_name = property["name"]
			var value = resource.get(prop_name)
			var default_value = ClassDB.class_get_property_default_value(resource.get_class(), prop_name)
			if value != default_value:
				changed_properties[prop_name] = value
	return changed_properties

func format_resource_value(value) -> String:
	if value is Resource:
		return value.resource_path if value.resource_path else "<Embedded Resource>"
	return str(value)
