hubot-script-ical
=================

google calendar integration, allows hubot to notify roommembers when ical events (are about) to happen 

# What 

Manage notifications for some room using a Google Calendar and notifies
room members when events are about to happen.

The calendar is provided using URL in iCalendar or XML format
For more info on how to get the calendar feed URLs see
http://support.google.com/calendar/bin/answer.py?hl=en&answer=37648

It automatically retrieves the URL looking for changes and new events

# Environment Variables:

All environment variables are optional. The script will default to the preset variables in no environment variables are set
- `CALENDAR_MESSAGE_POOLING_TIME`
- `CALENDAR_CHANGES_POOLING_TIME`
- `CALENDAR_MESSAGE_DELAY`
- `CALENDAR_ROOM_MESSAGE`

# Commands:

- `hubot calendar <room> <calendar-url>` - Set calendar for some room using events from some feed
- `hubot calendar <room>` - Clear calendar from some room
- `hubot calendar` - List current calendars and upcoming events

# Credits

credits go to igui since I extracted this functionality from [his repo](https://github.com/igui/cubot-hipchat) and turned it into a module.
