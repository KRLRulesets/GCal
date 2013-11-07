ruleset a16_gcal {
  meta {
    name "GCal Util Module"
    description <<
      Utilities for Google Calendar. 
      Configure with the URL to the calendar in question, either using a public URL or a private URL.
 
      To get the URL, click the ICAL button on the "detail" page in GCal. Click on the "XML" button. 
      You'll get a calendar URL ends in "basic". 
      
      now() returns a structure that looks like this:
      
      {
         "guestsCanSeeGuests" : true,
         "creator" : {
            "displayName" : "Office Temperature"
         },
         "sequence" : 1,
         "status" : "confirmed",
         "alternateLink" : "https://www.google.com/calendar/event?eid=bWQ3OWM4Nzk4a3RiaDE5anEwYTk4cnZjcGsgbWY0b2I0MTE0dDBmNHNnampoZG1taXJmamNAZw",
         "kind" : "calendar#event",
         "selfLink" : "https://www.google.com/calendar/feeds/mf4ob4114t0f4sgjjhdmmirfjc%40group.calendar.google.com/public/full/md79c8798ktbh19jq0a98rvcpk",
         "updated" : "2012-08-16T17:31:41.000-06:00",
         "guestsCanInviteOthers" : true,
         "id" : "md79c8798ktbh19jq0a98rvcpk",
         "canEdit" : false,
         "when" : [
            {
               "start" : "2012-08-16T16:00:00.000-06:00",
               "end" : "2012-08-17T17:00:00.000-06:00"
            }
         ],
         "transparency" : "opaque",
         "attendees" : [
            {
               "rel" : "organizer",
               "email" : "mf4ob4114t0f4sgjjhdmmirfjc@group.calendar.google.com",
               "displayName" : "Office Temperature"
            }
         ],
         "location" : "",
         "details" : "",
         "created" : "2012-08-16T16:51:29.000-06:00",
         "anyoneCanAddSelf" : false,
         "title" : "Temperature - 78",
         "guestsCanModify" : false
      }
      
          
    >>
    author "Sam Curren"
    logging on
    
    configure using 
      url = "http://www.google.com/calendar/feeds/sk8bh034vvqfbgercq68rtspi4@group.calendar.google.com/public/basic"

    provides onnow, now, next, verbaldate
  }

  dispatch {
    domain "exampley.com"
  }

  global {
    //used for self reference
    thisappid = "a8x114";
    
    //default calendar options.
    caloptions = {
      "singleevents":"true",
      "alt":"jsonc",
      "ctz":"America/Denver",
      "orderby":"starttime",
      "sortorder":"a"
    };
    
    //this is needed for testing. 'configure' variables are not available when running as a ruleset
    rawurl = url => url | "http://www.google.com/calendar/feeds/sk8bh034vvqfbgercq68rtspi4@group.calendar.google.com/public/basic";
    calendarurl = rawurl.replace(re/basic$/i, "full"); //make it a 'full' feed if basic was specified
    
    // titles must look like regular expressions (i.e. "/Temperature/")
    //returns a boolean value, true if we are currently in an event with a matching title
    onnow = function(title){
      start = time:now({"tz":"Universal"});
      end = time:add(start, {"minutes":1});
      requestoptions = caloptions.put({"start-min": start,"start-max": end });
      onnow = http:get(calendarurl, requestoptions).pick("content").decode();
      alltitles = onnow.pick("$..items[*].title", true);
      relevanttitles = alltitles.filter(function(t){t.match(title.as("regexp"))});
      relevanttitles.length() > 0;
    };
    
    //returns the current event with matching title, or a 'falsy' value
    now = function(title){
      start = time:now({"tz":"Universal"});
      end = time:add(start, {"minutes":1});
      requestoptions = caloptions.put({"start-min": start,"start-max": end });
      onnow = http:get(calendarurl, requestoptions).pick("content").decode();
      allevents = onnow.pick("$..items[*]", true);
      relevantevents = allevents.filter(function(e){e.pick("$.title").match(title.as("regexp"))});
      nextevent = relevantevents.head();//first event is next, because of sort order
      nextevent;
    };    
    
    //returns either the next event with a matching title, or a 'falsy' value
    next = function(title){
      start = time:now();
      end = time:add(start, {"days":30});
      requestoptions = caloptions.put({
        "start-min": time:atom(start),
        "start-max": time:atom(end)
      });
      onnow = http:get(calendarurl, requestoptions).pick("content").decode();
      allevents = onnow.pick("$..items[*]", true);
      relevantevents = allevents.filter(function(e){e.pick("$.title").match(title.as("regexp"))});
      nextevent = relevantevents.head();//first event is next, because of sort order
      nextevent;
    };
    
    //formats a date for speaking. Should be moved to twilio module
    verbaldate = function(d){
      datestringA = time:strftime(d, "%A, %d of %B at %I, %M %p");
      datestringB = datestringA.replace(re/ 0/g, " ").replace(re/ 0/g, " ");
      datestringB;
    };
    
    //util functions
    eventbutton = function(event, label){
      b = " <input type=\"button\" value=\"#{label}\" onclick=\"KOBJ.get_application('#{thisappid}').raise_event('#{event}');\"/> <br/>";
      b;
    };
  }

  rule testrunner {
    select when pageview ".*" setting ()
    pre {   
      tests = <<
        #{eventbutton("onnow", "Test onnow")}
        #{eventbutton("next", "Test next")}
      >>;
    }
    notify("GCal Util Module Tests New!", tests) with sticky = true;
  }
  
  rule onnow {
    select when web onnow
    pre {
      message = onnow("Test") => "On Now!" | "Not on now.";
    }
    notify("onnow test", message);
  }
  
  rule testnext {
    select when web next
    pre {
      nextevent = next("Test");
      nexttime = nextevent => verbaldate(nextevent.pick("$.when[0].start")) | "No Event Scheduled";
    }
    notify("next test", nexttime);
  }
  
}
