

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

The most important configuration parameter are `schedule_data` variable
```
schedule_data = {
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
```

and `schedule_messages` variable
```
schedule_messages = {
	[24*3600] = "Starting at\n<EVENT_TIME> CEST",
	[10*60] = "Starting in\n<TTE_MINUTES> minutes",
	[2*60] = "Starting soon",
}
```

You define a scene, then the time and list of scene items to be shown. Items defined for different times will be hidden. The first element should be a text element to which a countdown message is populated or empty string if the message should not be shown.

So the above configuration will show on `timer` scene:
- before 12:50 (10*60 sec) message: `Starting at 01:00 PM CEST`,
- from 12:50 to 12:58 (2*60 sec) message: `Starting in XXX minutes`,
- from 12:58 up until you don't switch the scene: `Starting soon`.

Then the same for the event at 14:00 and 15:00. The last event at 20:01 is a dummy event to show after the event slide.

For the first event, the text will be populated into `dyntext` source, then into `dyntext 2`, and no countdown will be shown for the last, dummy event.

Source `dyntext`, `factoid` and `color` will be shown before the first event (for example, it is a white text (dyntext) on top of a black box (color) and this is on top of factoid video), `dyntext 2`, `pres1`, `pres2` and `after` will be hidden. And the same schema for the following events, sources defined for the other events will be hidden, sources for the current event will be shown.

There is one more configuration parameter, `eventMargin`, which defines for how long after the event starts, the last message should still be shown. By default, it is defined for 5 minutes. The reason for that is the situation you are switching to live feed, but after that, you see that someone is not ready or is having technical difficulties. If you switch back to countdown scene within 5 minutes, it will still show the `Starting soon` message.

If you want to debug the script, you can set a dummy time in properties as well as you can force the event to be switched even without switching the scene. So you can simulate the whole thing.


