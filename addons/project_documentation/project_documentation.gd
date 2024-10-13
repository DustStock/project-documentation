@tool
extends EditorPlugin

func _enter_tree():
	add_tool_menu_item("Documentation Generator", Callable(self, "_on_menu_item_pressed"))

func _exit_tree():
	remove_tool_menu_item("Documentation Generator")

func _on_menu_item_pressed():
	var dialog = preload("res://addons/project_documentation/documetation_generator_dialog.tscn").instantiate()
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
