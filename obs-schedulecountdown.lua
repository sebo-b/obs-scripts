
--------------- config ---------------

schedule_data = {
-- Format:
--  table index = time as string
--        table of item names, 
--          the first item must be text item to be updated or empty string "" if none (useful for the after-event slide)
--          next items will be shown when the event is active
--  all items specified in the list and not part of the current event will be hidded
-- Example:
--	["10:00"] = { text_field, "field1_to_be_shown", "field2_to_be_shown"}
--	["11:00"] = { text_field, "field3_to_be_shown"}

	["timer"] = {
		["13:00"] = {"dyntext", "factoid","color"},
		["14:00"] = {"dyntext 2", "pres1" },
	 	["15:00"] = {"dyntext 2", "pres2" },
	 	["20:01"] = {"", "after"}
	 	},
	["Scene 2"] = {
		["10:00"] = {"text_green", "img1_a","img2"},
		["11:00"] = {"text_green", "Image" },
	 	["12:00"] = {"text_green", "img2" },
	 	["20:00"] = {"", "img1_a"}
	 	},
}

eventMargin = 5*60	-- margin in seconds to still show "soon" instead of switching to the next event

-- Format:
--   [ time to event in seconds ] = "message"
--   message can include:
 --    <EVENT_TIME> - time of the event, eg. "10:00 AM"
 --    <EVENT_TIME24> - time of the event, eg. "14:00"
 --    <TTE_HOURS> - number of hours to the event
 --    <TTE_MINUTES> - number of minutes to the event
 --    <TTE_SECONDS> - number of seconds to the event

schedule_messages = {
	[24*3600] = "Starting at\n<EVENT_TIME> CEST",
	[10*60] = "Starting in\n<TTE_MINUTES> minutes",
	[2*60] = "Starting soon",
}

--------------- globals ---------------

isError = true

always_switch_event = false
debugTime = nil

current_event = nil
current_scene = nil

--------------- utils ---------------

util = {}

function util.duplicate(t)

	if type(t) ~= 'table' then 
		return t
	end

	local dup = {}
	for k,v in pairs(t) do
		dup[ util.duplicate(k) ] = util.duplicate(v)
	end

	return dup
end

function util.mktime(hour,min,sec)

	return hour*3600 + min*60 + sec

end

function util.mktimeFromString(str)

	local hour, min, sec = string.match(str,"^(%d?%d):(%d%d):(%d%d)$")

	if hour == nil or min == nil or sec == nil then
		-- lua doesn't fully support regexp (no optional groups support), so we need to match again
		hour, min = string.match(str,"^(%d?%d):(%d%d)$")
		sec = 0
	end

	if hour == nil or min == nil then
		return nil
	end

	return util.mktime(hour,min,sec)

end

function util.formatTime(timestamp,expanded,clock24)

	local ts = timestamp

	local sec = timestamp % 60
	ts = ts - sec
	local min = (ts / 60) % 60
	ts = ts - min*60
	local hour = (ts / 3600) % 24

	if not expanded then

		local pm = ""

		if not clock24 then

			if hour < 12 then
				pm = " AM"
			else
				pm = " PM"
			end

			hour = hour % 12
		end

		return string.format("%02d:%02d", hour, min) .. pm

	else
		return string.format("%02d:%02d:%02d (ts=%d)", hour, min, sec, timestamp)
	end

end

function util.now()

	if debugTime ~= nil then
		return debugTime
	end

	local timeS = os.date('*t')
	return util.mktime( timeS.hour, timeS.min, timeS.sec)

end


--------------- script handlers ---------------

function script_load(settings)

	isError = checkErrors(schedule_data)

	if isError then
		current_event = nil
		current_scene = nil
		return
	end

	obslua.obs_frontend_add_event_callback(onFrontendEvent)
	obslua.timer_add(onTimer, 1000)

	onFrontendEvent(obslua.OBS_FRONTEND_EVENT_SCENE_CHANGED)

end

function script_unload()

end

function script_update(settings)

	local debugTimeEnabled = obslua.obs_data_get_bool(settings,"debug_time_enabled")

	if debugTimeEnabled then

		local debugTimeStr = obslua.obs_data_get_string(settings,"debug_time")
		debugTime = util.mktimeFromString(debugTimeStr)


		if debugTime == nil then
			obslua.script_log( obslua.LOG_INFO, "[WARN] Not valid format of time")
		else
			obslua.script_log( obslua.LOG_INFO, 
				"[INFO] Setting debug time to " .. util.formatTime(debugTime,true) )
		end

	else
		debugTime = nil
	end

	always_switch_event = obslua.obs_data_get_bool(settings,"always_switch_event")

end

function script_description()
	return "Show appropriate slide and countdown timer to the next scheduled event"
end

function script_properties()
		
	local props = obslua.obs_properties_create()

	local function dtEnabPropCallback(props, property, settings)
		local dtEnabled = obslua.obs_data_get_bool(settings,"debug_time_enabled")
		local dtProp = obslua.obs_properties_get(props,"debug_time")
		obslua.obs_property_set_enabled(dtProp, dtEnabled)
		return true
	end

	local dtEnabProp = obslua.obs_properties_add_bool(props, "debug_time_enabled", "Enable debug time")
	obslua.obs_property_set_modified_callback(dtEnabProp,dtEnabPropCallback)

	local dtProp = obslua.obs_properties_add_text(props, "debug_time", "", obslua.OBS_TEXT_DEFAULT)
	obslua.obs_property_set_enabled(dtProp, debugTime ~= nil)

	obslua.obs_properties_add_bool(props, "always_switch_event", "Switch event without scene switch")

	return props

end


function script_defaults(settings)

	obslua.obs_data_set_bool(settings,"debug_time_enabled", debugTime ~= nil)
	obslua.obs_data_set_string(settings,"debug_time", "09:57:12")
	obslua.obs_data_set_bool(settings,"always_switch_event", always_switch_event)

end

--------------- script functions ---------------
function onTimer()

	if isError then
		return
	end

	local function updateText(currentSceneName,currentEvent)

		local now = util.now()
		local currentEventTime = util.mktimeFromString(currentEvent)

		local tte = currentEventTime - now

		local smKey = 2^31	-- max
		for i,v in pairs(schedule_messages) do
			if tte < i and i < smKey then
				smKey = i
			end
		end

		if schedule_messages[smKey] == nil then
			obslua.script_log( obslua.LOG_ERROR, "[ERR] Cannot find appropriate message")
			return
		end

		local tteStr = schedule_messages[smKey]
		local tteH, tteM, tteS = math.floor(tte / 3600), math.floor(tte/60) % 60, tte%60
		tteStr = string.gsub (tteStr, "<EVENT_TIME>", util.formatTime(currentEventTime,false,false) )
		tteStr = string.gsub (tteStr, "<EVENT_TIME24>", util.formatTime(currentEventTime,false,true) )
		tteStr = string.gsub (tteStr, "<TTE_HOURS>", tteH )
		tteStr = string.gsub (tteStr, "<TTE_MINUTES>", tteM )
		tteStr = string.gsub (tteStr, "<TTE_SECONDS>", tteS )

		local textItem = schedule_data[currentSceneName][currentEvent][1]
		local textSrc = obslua.obs_get_source_by_name( textItem )
		if textSrc == nil then
			obslua.script_log( obslua.LOG_ERROR, "[ERR] Cannot find text item '" .. textItem .. "'.")
			return
		end

		local settings = obslua.obs_data_create()
		obslua.obs_data_set_string(settings, "text", tteStr)
		obslua.obs_source_update(textSrc, settings)
		obslua.obs_data_release(settings)
		obslua.obs_source_release(textSrc)
	end

	-- update preview scene (if any)
	local currentPreviewSceneSrc = obslua.obs_frontend_get_current_preview_scene()
	if currentPreviewSceneSrc ~= nil then
		local currentPreviewSceneName = obslua.obs_source_get_name(currentPreviewSceneSrc)
		obslua.obs_source_release(currentPreviewSceneSrc)

		local currentPreviewEvent = getCurrentEvent(currentPreviewSceneName, schedule_data)
		if currentPreviewEvent ~= nil then			
			updateVisibility(currentPreviewSceneName, currentPreviewEvent, schedule_data)
			updateText(currentPreviewSceneName,currentPreviewEvent)
		end
	end

	-- in studio mode visibility of items in active scene cannot be changed 
	-- so always_switch_event is only confusing as it can switch text item to be updated
	-- however visibility will stay intact
	if always_switch_event and currentPreviewSceneSrc == nil then
		onFrontendEvent(obslua.OBS_FRONTEND_EVENT_SCENE_CHANGED)
	end

	local currentSceneSrc = obslua.obs_frontend_get_current_scene()
	local currentSceneName = obslua.obs_source_get_name(currentSceneSrc)
	obslua.obs_source_release(currentSceneSrc)


	if current_event == nil or schedule_data[currentSceneName][current_event][1] == "" then
		return
	end

	updateText(currentSceneName,current_event)

end

function onFrontendEvent(event)

	if isError then
		return
	end

	if event == obslua.OBS_FRONTEND_EVENT_SCENE_CHANGED then

		local currentSceneSrc = obslua.obs_frontend_get_current_scene()
		current_scene = obslua.obs_source_get_name(currentSceneSrc)
		obslua.obs_source_release(currentSceneSrc)

		current_event = getCurrentEvent(current_scene, schedule_data)

		if current_event == nil then
			current_scene = nil
		else
			updateVisibility(current_scene, current_event, schedule_data)
		end

	end
end


--------------- global independent functions ---------------

function updateVisibility(sceneName,eventTime,scheduleData)

	if eventTime == nil then
		return
	end

	local currentSchedule = scheduleData[sceneName]
	if currentSchedule == nil then
		return
	end

	local map = {}

	for time, items in pairs(currentSchedule) do
		for _, item in ipairs(items) do
			if item ~= "" then
				if not map[item] then
					map[item] = (time == eventTime)
				end
			end
		end
	end

	local sceneSrc = obslua.obs_get_source_by_name(sceneName)
	if sceneSrc == nil then
		obslua.script_log( obslua.LOG_ERROR, "[ERR] Cannot find scene '" .. sceneName .. "'.")
		return
	end

	local scene = obslua.obs_scene_from_source(sceneSrc)

	local sceneItems = obslua.obs_scene_enum_items(scene)
	if sceneItems == nil then		
		obslua.script_log( obslua.LOG_ERROR, "[ERR] Empty scene  '" .. sceneName .. "'.")
		obslua.source_list_release(sceneSrc)
		return
	end

	for _, item in ipairs(sceneItems) do

		local itemSrc = obslua.obs_sceneitem_get_source(item)
		local itemName = obslua.obs_source_get_name(itemSrc)

		if map[itemName] ~= nil then
			obslua.obs_sceneitem_set_visible(item, map[itemName])
		end

	end

	obslua.obs_source_release(sceneSrc)

end

function getCurrentEvent(currentScene,scheduleData)

	if scheduleData == nil or scheduleData[currentScene] == nil then
		return nil
	end

	local now = util.now()
	local timeToEvent = 24*3600	--max

	local currentEvent = nil

	for k, _ in pairs(scheduleData[currentScene]) do

		local tte = util.mktimeFromString(k) + eventMargin - now
		if tte > 0 and tte < timeToEvent then
			currentEvent = k
			timeToEvent = tte
		end
	end

	return currentEvent

end

function checkErrors(scheduleData)

	-- check if all scenes exists
	local tmpScenes = {}
	for sceneName,_ in pairs(scheduleData) do
		tmpScenes[sceneName] = true
	end

	local sceneSources = obslua.obs_frontend_get_scenes()
	if sceneSources ~= nil then
    	for _, sceneSource in ipairs(sceneSources) do
    		local sceneName = obslua.obs_source_get_name(sceneSource)
    		tmpScenes[sceneName] = nil
    	end

    	local leftScenes = 0
		for sceneName, _ in pairs(tmpScenes) do
			obslua.script_log( obslua.LOG_ERROR, "[ERR] Scene '" .. sceneName .. "' not found.")
			leftScenes = leftScenes + 1	
		end

		if leftScenes > 0 then 
			obslua.source_list_release(sceneSources)
			return true
		 end    	
    else
		obslua.script_log( obslua.LOG_ERROR, "[ERR] No scenes defined.")
		return true	
	end


	-- check if all items exists in sceneSources (and if time is correct)
	for _, sceneSource in ipairs(sceneSources) do

		local sceneName = obslua.obs_source_get_name(sceneSource)

			if scheduleData[sceneName] ~= nil then

			for i, v in pairs(scheduleData[sceneName]) do

				-- check time
				if util.mktimeFromString(i) == nil then
					obslua.script_log( obslua.LOG_ERROR, "[ERR] String '" .. i .. "' is not a valid time.")
					obslua.source_list_release(sceneSources)
					return true
				end

				local tmpItems = {}
				for i, v in ipairs(v) do
					if tmpItems[v] ~= nil then
						obslua.script_log( obslua.LOG_ERROR, "[ERR] In scene '" .. sceneName .. "' at " .. i .. " the element '" .. v .. "' specified more than once.")
						obslua.source_list_release(sceneSources)
						return true
					elseif not (i == 1 and v == "") then
						tmpItems[v] = i
					end
				end

				local scene = obslua.obs_scene_from_source(sceneSource)
				local sceneItems = obslua.obs_scene_enum_items(scene)
				for _, sceneItem in ipairs(sceneItems) do
					
					local sceneItemSrc = obslua.obs_sceneitem_get_source(sceneItem)
					local sceneItemName = obslua.obs_source_get_name(sceneItemSrc)

					if tmpItems[sceneItemName] ~= nil then

						if tmpItems[sceneItemName] == 1 then
							-- check if first element is a text element
							local sceneItemId = obslua.obs_source_get_id(sceneItemSrc)
							if sceneItemId ~= "text_gdiplus" and sceneItemId ~= "text_ft2_source" and sceneItemId ~= "text_ft2_source_v2"then
								
								obslua.script_log( obslua.LOG_ERROR, "[ERR] In scene '" .. sceneName .. "' at " .. i .. " the first element ('" .. sceneItemName .. "') is not a text element.")
								
								obslua.sceneitem_list_release(sceneItems)
								obslua.source_list_release(sceneSources)
								return true
							end

						end

						tmpItems[sceneItemName] = nil
					end
				end

				obslua.sceneitem_list_release(sceneItems)

				local leftItems = 0
				for sceneItem, _ in pairs(tmpItems) do
					leftItems = leftItems + 1
					obslua.script_log( obslua.LOG_ERROR, "[ERR] Element '" .. sceneItem .. "' doesn't exist in the scene '" .. sceneName .. "'")
				end

				if leftItems > 0 then
					obslua.source_list_release(sceneSources)
					return true
				end	
			end
		end
	end

	obslua.source_list_release(sceneSources)

	obslua.script_log( obslua.LOG_INFO, "All seems ok!")

	return false

end







