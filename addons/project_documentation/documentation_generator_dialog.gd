# documentation_generator_dialog.gd
@tool

extends Window

func _ready():
	show()

func _on_generate_pressed():
	print("generate pressed")
	var options = {
		"export_scene_tree": $VBoxContainer/ExportSceneTree.is_pressed() ,
		"export_signal_connections": $VBoxContainer/ExportSignalConnections.is_pressed(),
		"export_changed_properties": $VBoxContainer/ExportChangedProperties.is_pressed(),
		"export_node_groups": $VBoxContainer/ExportNodeGroups.is_pressed(),
		"export_scripts": $VBoxContainer/ExportScripts.is_pressed(),
		"export_resources": $VBoxContainer/ExportResources.is_pressed(),
		"export_shaders": $VBoxContainer/ExportShaders.is_pressed()
	}
	var doc_generator = preload("res://addons/project_documentation/documentation_generator.gd").new()
	doc_generator.set_options(options)
	doc_generator.generate()
	queue_free()


func _on_cancel_pressed():
	print("cancel/close pressed")
	hide()
