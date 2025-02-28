/area
	luminosity           = TRUE
	var/dynamic_lighting = DYNAMIC_LIGHTING_ENABLED

/area/proc/set_dynamic_lighting(var/new_dynamic_lighting = DYNAMIC_LIGHTING_ENABLED)
	if (new_dynamic_lighting == dynamic_lighting)
		return FALSE

	dynamic_lighting = new_dynamic_lighting

	if (IS_DYNAMIC_LIGHTING(src))
		cut_overlay(GLOB.fullbright_overlay)
		blend_mode = BLEND_DEFAULT
		if(lighting_overlay)
			cut_overlay(lighting_overlay)
		if(lighting_overlay_opacity && lighting_overlay_colour)
			update_lighting_overlay()
			add_overlay(lighting_overlay)
		for(var/turf/T as anything in get_contained_turfs())
			if (IS_DYNAMIC_LIGHTING(T))
				T.lighting_build_overlay()
			T.update_above()

	else
		if(lighting_overlay)
			cut_overlay(lighting_overlay)
		add_overlay(GLOB.fullbright_overlay)
		blend_mode = BLEND_DEFAULT
		for(var/turf/T as anything in get_contained_turfs())
			if (T.lighting_object)
				T.lighting_clear_overlay()
			T.update_above()

	return TRUE

/area/vv_edit_var(var_name, var_value)
	switch(var_name)
		if(NAMEOF(src, dynamic_lighting))
			set_dynamic_lighting(var_value)
			return TRUE
		if("lighting_overlay_colour")
			..()
			if(lighting_overlay)
				cut_overlay(lighting_overlay)
				lighting_overlay.color = var_value
				add_overlay(lighting_overlay)
			return TRUE
		if("lighting_overlay_opacity")
			..()
			if(lighting_overlay)
				cut_overlay(lighting_overlay)
				lighting_overlay.alpha = var_value
				add_overlay(lighting_overlay)
			return TRUE
	return ..()
