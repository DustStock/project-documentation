@tool
extends Window

var excluded_directories = ["res://addons/"]

@onready var vbox_container = $VBoxContainer
@onready var excluded_directories_list = $VBoxContainer/ExcludedDirectoriesContainer/ExcludedDirectoriesList
@onready var add_directory_button = $VBoxContainer/ExcludedDirectoriesContainer/AddDirectoryContainer/AddDirectoryButton
@onready var directory_dialog = $DirectoryDialog

func _ready():
	show()
	add_directory_button.connect("pressed", _on_add_directory_button_pressed)
	directory_dialog.connect("dir_selected", _on_directory_selected)
	update_excluded_directories_list()
	call_deferred("adjust_window_size")

func _on_generate_pressed():
	print("generate pressed")
	var options = {
		"export_scene_tree": $VBoxContainer/ExportSceneTree.is_pressed(),
		"export_signal_connections": $VBoxContainer/ExportSignalConnections.is_pressed(),
		"export_changed_properties": $VBoxContainer/ExportChangedProperties.is_pressed(),
		"export_node_groups": $VBoxContainer/ExportNodeGroups.is_pressed(),
		"export_scripts": $VBoxContainer/ExportScripts.is_pressed(),
		"export_resources": $VBoxContainer/ExportResources.is_pressed(),
		"export_shaders": $VBoxContainer/ExportShaders.is_pressed(),
		"excluded_directories": excluded_directories
	}
	var doc_generator = preload("res://addons/project_documentation/documentation_generator.gd").new()
	doc_generator.set_options(options)
	doc_generator.generate()
	queue_free()

func _on_cancel_pressed():
	print("cancel/close pressed")
	hide()

func _on_add_directory_button_pressed():
	directory_dialog.popup_centered(Vector2(400, 300))

func _on_directory_selected(dir):
	if dir not in excluded_directories:
		excluded_directories.append(dir)
		update_excluded_directories_list()
		adjust_window_size()

func update_excluded_directories_list():
	for child in excluded_directories_list.get_children():
		child.queue_free()
	
	for dir in excluded_directories:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = dir
		var delete_button = Button.new()
		delete_button.text = "X"
		delete_button.connect("pressed", _on_delete_directory.bind(dir))
		
		hbox.add_child(label)
		hbox.add_child(delete_button)
		excluded_directories_list.add_child(hbox)

func _on_delete_directory(dir):
	excluded_directories.erase(dir)
	update_excluded_directories_list()
	adjust_window_size()

func adjust_window_size():
	# Wait for one frame to ensure all UI elements are updated
	await get_tree().process_frame
	
	# Calculate the required height
	var required_height = vbox_container.get_minimum_size().y + 20  # Add some padding
	
	# Get the current window size
	var current_size = size
	
	# Set the new window size
	size = Vector2(current_size.x, required_height)
