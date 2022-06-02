tool
extends "../utility/input_field_resource/input_field_resource.gd"


#-------------------------------------------------------------------------------
# The manager of all plant types for a given Gardener
# Handles interfacing between Greenhouse_PlantState, UI and plant placement
#-------------------------------------------------------------------------------


const Greenhouse_PlantState = preload("greenhouse_plant_state.gd")
const ThemeAdapter = preload("../controls/theme_adapter.gd")

# All the plants (plant states) we have
var greenhouse_plant_states:Array = []
# Keep a reference to selected resource to easily display it
var selected_for_edit_resource:Resource = null

var select_container:UI_IF_ThumbnailArray = null
var settings_container:Control = null
var _base_control:Control = null
var _resource_previewer = null


signal prop_action_executed_on_plant_state(prop_action, final_val, plant_state)
signal prop_action_executed_on_plant_state_plant(prop_action, final_val, plant, plant_state)
signal prop_action_executed_on_LOD_variant(prop_action, final_val, LOD_variant, plant, plant_stat)
signal req_octree_reconfigure(plant, plant_state)
signal req_octree_recenter(plant, plant_state)




#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------


func _init().():
	set_meta("class", "Greenhouse")
	resource_name = "Greenhouse"
	
	_add_res_edit_source_array("plant_types/greenhouse_plant_states", "plant_types/selected_for_edit_resource")


# The UI is created here because we need to manage it afterwards 
# And I see no reason to get lost in a signal spaghetti of delegating it
func create_ui(__base_control:Control, __resource_previewer):
	_base_control = __base_control
	_resource_previewer = __resource_previewer
	
	var greenhouse_panel := PanelContainer.new()
	greenhouse_panel.name = "greenhouse_panel"
	greenhouse_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greenhouse_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var split := VSplitContainer.new()
	split.name = "split"
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var tab_select := TabContainer.new()
	tab_select.name = "tab_select"
	tab_select.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_select.tabs_visible = false
	tab_select.size_flags_stretch_ratio = 0.3
	
	var tab_settings := TabContainer.new()
	tab_settings.name = "tab_settings"
	tab_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_settings.tabs_visible = false
	
	var scroll_select := ScrollContainer.new()
	scroll_select.name = "scroll_select"
	
	var scroll_settings := ScrollContainer.new()
	scroll_settings.name = "scroll_settings"
	scroll_settings.scroll_horizontal_enabled = false
	
	var input_fields = create_input_fields(_base_control, _resource_previewer)
	
	select_container = input_fields[0]
	select_container.label.visible = false
	select_container.name = "select_container"
	select_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	select_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_container.connect("requested_check", self, "on_plant_state_check")
	
	settings_container = input_fields[1]
	ThemeAdapter.assign_node_type(settings_container, "ExternalMargin")
	
	greenhouse_panel.add_child(split)
	split.add_child(tab_select)
	split.add_child(tab_settings)
	tab_select.add_child(scroll_select)
	tab_settings.add_child(scroll_settings)
	scroll_select.add_child(select_container)
	scroll_settings.add_child(settings_container)
	ThemeAdapter.assign_node_type(greenhouse_panel, "GreenhousePanel")
	ThemeAdapter.assign_node_type(tab_select, "GreenhouseTabContainerTop")
	ThemeAdapter.assign_node_type(tab_settings, "GreenhouseTabContainerBottom")
	
	return greenhouse_panel


func _create_input_field(_base_control:Control, _resource_previewer, prop:String) -> UI_InputField:
	var input_field:UI_InputField = null
	match prop:
		"plant_types/greenhouse_plant_states":
			var settings := {
				"add_create_inst_button": true,
				"_base_control": _base_control, 
				"accepted_classes": ["Greenhouse_PlantState"], 
				"element_display_size": 100, 
				"element_interaction_flags": UI_IF_ThumbnailArray.PRESET_PLANT_STATE,
				"_resource_previewer": _resource_previewer,
				}
			input_field = UI_IF_ThumbnailArray.new(greenhouse_plant_states, "Plant Types", prop, settings)
		"plant_types/selected_for_edit_resource":
			var settings := {"_base_control": _base_control, "_resource_previewer": _resource_previewer, "label_visibility": false, "tab": 0}
			input_field = UI_IF_Object.new(selected_for_edit_resource, "Plant State", prop, settings)
	
	return input_field




#-------------------------------------------------------------------------------
# UI management
#-------------------------------------------------------------------------------


# Select a Greenhouse_PlantState for painting
func on_plant_state_check(index:int, state:bool):
	var plant_state = greenhouse_plant_states[index]
	var prop_action = PA_PropSet.new("plant/plant_brush_active", state)
	plant_state.request_prop_action(prop_action)


func select_plant_state_for_brush(index:int, state:bool):
	if is_instance_valid(select_container):
		select_container.set_thumb_interaction_feature_with_data(UI_ActionThumbnail_GD.InteractionFlags.CHECK, state, {"index": index})


func on_if_ready(input_field:UI_InputField):
	.on_if_ready(input_field)
	
	if input_field.prop_name == "plant_types/greenhouse_plant_states":
		for i in range(0, greenhouse_plant_states.size()):
			select_plant_state_for_brush(i, greenhouse_plant_states[i].plant_brush_active)


func plant_count_updated(plant_index, new_count):
	if select_container:
		select_container.flex_grid.get_child(plant_index).set_counter_val(new_count)



#-------------------------------------------------------------------------------
# Signal forwarding
#-------------------------------------------------------------------------------


func on_changed_plant_state():
	emit_changed()


func on_req_octree_reconfigure(plant, plant_state):
	emit_signal("req_octree_reconfigure", plant, plant_state)


func on_req_octree_recenter(plant, plant_state):
	emit_signal("req_octree_recenter", plant, plant_state)




#-------------------------------------------------------------------------------
# Prop Actions
#-------------------------------------------------------------------------------


func on_prop_action_executed(prop_action:PropAction, final_val):
	var prop_action_class = prop_action.get_meta("class")
	
	match prop_action.prop:
		"plant_types/greenhouse_plant_states":
			match prop_action_class:
				"PA_ArrayInsert":
					# This is deferred because the action thumbnail is not ready yet
					call_deferred("plant_count_updated", prop_action.index, 0)
					call_deferred("select_plant_state_for_brush", prop_action.index, final_val[prop_action.index].plant_brush_active)
	


func on_prop_action_executed_on_plant_state(prop_action, final_val, plant_state):
	if prop_action is PA_PropSet:
		var plant_index = greenhouse_plant_states.find(plant_state)
		match prop_action.prop:
			"plant/plant_brush_active":
				select_plant_state_for_brush(plant_index, final_val)
	
	emit_signal("prop_action_executed_on_plant_state", prop_action, final_val, plant_state)


func on_prop_action_executed_on_plant_state_plant(prop_action, final_val, plant, plant_state):
	var plant_index = greenhouse_plant_states.find(plant_state)
	
	# Any prop action on LOD variants - update thumbnail
	var update_thumbnail = prop_action.prop == "mesh/mesh_LOD_variants"
	if update_thumbnail && select_container:
		select_container._update_thumbnail(plant_state, plant_index)
	
	emit_signal("prop_action_executed_on_plant_state_plant", prop_action, final_val, plant, plant_state)


func on_prop_action_executed_on_LOD_variant(prop_action, final_val, LOD_variant, plant, plant_state):
	emit_signal("prop_action_executed_on_LOD_variant", prop_action, final_val, LOD_variant, plant, plant_state)




#-------------------------------------------------------------------------------
# Property export
#-------------------------------------------------------------------------------


func set_undo_redo(val:UndoRedo):
	.set_undo_redo(val)
	for plant_state in greenhouse_plant_states:
		plant_state.set_undo_redo(_undo_redo)


func _get(prop):
	match prop:
		"plant_types/greenhouse_plant_states":
			return greenhouse_plant_states
		"plant_types/selected_for_edit_resource":
			return selected_for_edit_resource
	
	return null


func _modify_prop(prop:String, val):
	match prop:
		"plant_types/greenhouse_plant_states":
#			val = val.duplicate()
			for i in range(0, val.size()):
				if !(val[i] is Greenhouse_PlantState):
					val[i] = Greenhouse_PlantState.new()
				
				FunLib.ensure_signal(val[i], "changed", self, "on_changed_plant_state")
				FunLib.ensure_signal(val[i], "prop_action_executed", self, "on_prop_action_executed_on_plant_state", [val[i]])
				FunLib.ensure_signal(val[i], "prop_action_executed_on_plant", self, "on_prop_action_executed_on_plant_state_plant", [val[i]])
				FunLib.ensure_signal(val[i], "prop_action_executed_on_LOD_variant", self, "on_prop_action_executed_on_LOD_variant", [val[i]])
				FunLib.ensure_signal(val[i], "req_octree_reconfigure", self, "on_req_octree_reconfigure", [val[i]])
				FunLib.ensure_signal(val[i], "req_octree_recenter", self, "on_req_octree_recenter", [val[i]])
				
				if val[i]._undo_redo != _undo_redo:
					val[i].set_undo_redo(_undo_redo)
	return val


func _set(prop, val):
	var return_val = true
	val = _modify_prop(prop, val)
	
	match prop:
		"plant_types/greenhouse_plant_states":
			greenhouse_plant_states = val
		"plant_types/selected_for_edit_resource":
			selected_for_edit_resource = val
		_:
			return_val = false
	
	if return_val:
		emit_changed()
	return return_val


func _get_property_list():
	var prop_dict:Dictionary = _get_prop_dictionary()
	var props := [
		prop_dict["plant_types/greenhouse_plant_states"],
		prop_dict["plant_types/selected_for_edit_resource"],
		]
	
	return props


func _get_prop_dictionary():
	return {
		"plant_types/greenhouse_plant_states":
		{
			"name": "plant_types/greenhouse_plant_states",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
		"plant_types/selected_for_edit_resource":
		{
			"name": "plant_types/selected_for_edit_resource",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE
		},
	}


func _fix_duplicate_signals(copy):
	copy._modify_prop("plant_types/greenhouse_plant_states", copy.greenhouse_plant_states)
	copy.selected_for_edit_resource = null


func get_prop_tooltip(prop:String) -> String:
	match prop:
		"plant_types/greenhouse_plant_states":
			return "All the plants in this Greenhouse"
		"plant_types/selected_for_edit_resource":
			return "The plant currently selected for edit"
	
	return ""
