# Manage notifications for some room using a Google Calendar and notifies
# room members when events are about to happen.
#
# The calendar is provided using URL in iCalendar or XML format
# For more info on how to get the calendar feed URLs see
# http://support.google.com/calendar/bin/answer.py?hl=en&answer=37648
#
# It automatically retrieves the URL looking for changes and new events
#
#
# Commands:
#   hubot calendar <room> <calendar-url> - Set calendar for some room using events from some feed
#   hubot calendar <room> - Clear calendar from some room
#   hubot calendar - List current calendars and upcoming events
#
ical = require 'ical'
request = require 'request'
MAXEVENTS = 10

class Calendar
  constructor: (@robot) ->
    self = this

    # Set a room info from an URL and ICS data
    @setRoomFromIcs = (room, url, data) ->
      ics = ical.parseICS(data)
      events = []
      for _, event of ics
        if event.type == 'VEVENT'
          starts = new Date(event.start).getTime()
          events.push {
            title: event.summary, starts: starts
          }

      self.calendars[room] = { url: url, events: events }

    # Notify events who are about to happen
    @notifyEvents = ->
      calendar_list = self.get()
      for cal, item of calendar_list
        for ev in item.events
          from_now =  ev.starts - new Date().getTime() -
            self.options.about_to_happen_delay * 60 * 1000

          if Math.abs(from_now) <= self.options.messaging_pooling_time / 2
            message = self.options.about_to_happen_message.
                replace('$0', ev.title).
                replace('$1', self.options.about_to_happen_delay)
            self.robot.messageRoom item.room, message

    @refreshCalendar = ->
      calendar_list = self.get()
      for cal, item of calendar_list
        request({uri: item.url}, (err, resp, data) ->
          if !err && resp.statusCode == 200
            self.setRoomFromIcs(item.room, item.url, data)
        )

    # Map room_name -> { url, events }
    @calendars = {}

    @options = {
      # pooling time between checks (milliseconds)
      messaging_pooling_time: process.env.node.CALENDAR_MESSAGE_POOLING_TIME or 1 * 1000
      # pooling time between refreshes (milliseconds)
      calchanges_pooling_time: process.env.node.CALENDAR_CHANGES_POOLING_TIME or 1 * 1000
      # advice time for events about to happen (minutes)
      about_to_happen_delay: process.env.node.CALENDAR_MESSAGE_DELAY or 10
      # about to happen message
      about_to_happen_message: process.env.node.CALENDAR_ROOM_MESSAGE or "@all Event '$0' is about to begin in $1 minutes"
    }

    # load previously loaded calendars from brain (removes current calendars :p)
    @robot.brain.on 'loaded', =>
      if @robot.brain.data.calendars
        @calendars = @robot.brain.data.calendars
      else
        @robot.brain.data.calendars = @calendars

    # checks events and messages members of room
    setInterval(@notifyEvents, @options.messaging_pooling_time)

    # checks for changes for each assigned calendar
    setInterval(@refreshCalendar, @options.calchanges_pooling_time)

  # Sets new iCalendar URL for some room and notifies new events in the room
  set: (room, url) ->
    cals = @calendars
    self = this
    request({uri:url}, (err, resp, data) ->
      if err
        throw err;
      if resp.statusCode != 200
        throw "Error retrieving url with code #{resp.statusCode}"
      self.setRoomFromIcs(room, url, data)
    )

  clear: (room) ->
    delete @calendars[room]

  get: ->
    res = []
    for room, room_info of @calendars
      res.push { room: room, url: room_info.url, events: room_info.events }
    return res



module.exports = (robot) ->
  calendar = new Calendar robot

  # set (or clear) calendar URL for some room
  robot.respond /calendar\s+(\w+)(\s+(.+))?$/i, (msg) ->
    room = msg.match[1]
    url = msg.match[2]

    if !url
      calendar.clear(room)
      msg.send "Removed calendar for room '#{room}'"
    else
      try
        calendar.set(room, url)
      catch error
        msg.send "Error retrieving iCalendar for room '#{room}': #{error}"
        return

      msg.send "Set calendar for room '#{room}' on #{url}"

  # list calendar URLs for all rooms
  robot.respond /calendar$/i, (msg) ->
    calendar_list = calendar.get()
    if calendar_list.length == 0
      msg.send "No calendars set"
      return
    verbiage = []
    for cal, item of calendar_list
      verbiage.push "#{item.room}: #{item.url}"
      for ev in item.events
        verbiage.push "  #{new Date(ev.starts)}: #{ev.title}"
    msg.send verbiage.slice(0,MAXEVENTS).join("\n")
