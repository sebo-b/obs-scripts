

# obs-schedulecountdown.lua

This script shows a countdown timer to the next event. The difference between this script and other available countdown scripts is:
- it allows to define the whole schedule, so it shows a countdown to the next event
- it allows defining a different schedule for different scenes
- it allows defining custom countdown messages, f.e. countdown in minutes or seconds
- countdown messages can be different depending on the time left, f.e. you can show countdown in minutes if there is more than 1 minute left and switch to seconds for the last minute
- it allows to show/hide scene elements depending on the scheduled event, f.e. you can show a background appropriate to the next scheduled event
- the whole configuration is inside the script itself - this was decided to minimize potential configuration errors or mistakes
- it has an extensive error check, so if a scene or scene item doesn't exist, it should report that
for debugging / simulation purposes, time can be overridden by UI settings

## Configuration:

The most important configuration parameter is `schedule_data` variable
```
schedule_data = {
	["timer"] = {
		["13:00"] = {"dyntext", "faktoid","color"},
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
```
You define a scene, then the time and list of scene items to be shown. Items defined for different times will be hidden. The first element should be a text element to which a countdown message is populated or empty string if the message should not be shown.

Other parameters are explained in the script itself.

