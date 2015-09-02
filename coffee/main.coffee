class Item
  
# A level, cutscene, or event. Basically a block of a full game run.

  
  @idLookup: {}
  @followingItemsLookup: {}
  
  
  constructor: (@name, details, messages) ->
    @constructor.idLookup[@name] = this
    
    @requirements = details.requirements
    @startLocation = details.start_location
    @endLocation = details.end_location
    
    for itemName in details.follows
      if itemName of @constructor.followingItemsLookup
        @constructor.followingItemsLookup[itemName].push(this)
      else
        @constructor.followingItemsLookup[itemName] = [this]
    
    @messages = []
    for message in messages
      @messages.push {
        id: message['id']
        case: message['case'] ? null
        skippable: message['skippable'] ? false
      }
    
      
  frames: (argSet) ->
    totalFrames = 0
    
    for message in @messages
      # Don't include skippable messages in our frame count.
      if message.skippable
        continue
      
      id = message.id
      if typeof id isnt 'string'
        # Object containing multiple cases. The only possible factor for
        # message id is character.
        id = id[argSet.character]
      
      m = Message.idLookup[id]
      
      messageFrames = m.frames(argSet, message.case)
        
      totalFrames += messageFrames
        
    return totalFrames
    
    
  showFrameDetails: (argSet) ->
    
    $itemDetails = $('#item-details')
    $itemDetails.empty()
    
    # Display item name
    $h3 = $('<h3>').text(@name)
    $itemDetails.append $h3
    
    # Make a box length explanations table
    $table = $('<table>')
    $tbody = $('<tbody>')
    $table.append $tbody
    $itemDetails.append $table
    
    for message in @messages
      
      if typeof message.id is 'string'
        messageId = message.id
      else
        # Only other possibility is a map from character to message id
        messageId = message.id[argSet.character]
      
      messageObj = Message.idLookup[messageId]
      data = messageObj.data[argSet.langCode]
      
      # Create a table row for the message.
      $tr = $('<tr>')
      $tbody.append $tr
      
      # When this row is clicked, display frame details for this row's message.
      $tr.addClass 'message-frames'
      f = (messageObj_, argSet_, messageCase_) ->
        messageObj_.showFrameDetails(argSet_, messageCase_)
      $tr.click(Util.curry(f, messageObj, argSet, message.case))
      
      # Display message id.
      $td = $('<td>')
      $td.text messageId
      $tr.append $td
      
      # Display message frames.
      framesText = messageObj.frames(argSet, message.case)
      $tr.append $('<td>').text(framesText)
      
      # Style skippable messages differently.
      if message.skippable
        $tr.addClass 'skippable'
  
    
class Action extends Item

# An Item that needs to be specified in a human readable route.
# It's not an automatically occurring cutscene or anything like that, it's
# something the player needs to know when to do.

  
  # Map/dict from human-readable strings to actions they represent.
  # Used when accepting a route as text.
  # e.g. either "Good Egg 4" or "Good Egg C" refers to Dino Piranha Speed Run.
  @aliases: {}
  
  
  constructor: (@name, details, messages) ->
    
    super(@name, details, messages)
    
    @nameCellClass = 'name-action'
    
    @addAlias(@name)
      
      
  addAlias: (alias) ->
    # Add to the class variable 'aliases'.
    # Map from alias to the standard name.
    @constructor.aliases[alias] = this
      
      
  text: () ->
    return "> " + @name
  
  
class Level extends Action
  
# An action that yields a star.

  
  @starNameLookup: {}
  
  
  constructor: (@name, details, messages) ->
    
    super(@name, details, messages)
    
    @nameCellClass = 'name-level'
    
    @starNameId = details.star_name
      
    # The super call added @name as an alias. Here we add more aliases.
    
    replaceLastChar = (s1, s2) -> s1.slice(0, s1.length - 1) + s2
    
    # TODO: Organize this aliasing thing better so that you can apply an
    # alias to an alias. e.g. you can go like Good Egg L -> Good Egg H ->
    # Good Egg Hidden in a DRY way.
    
    if @name.endsWith(" C")
      # Add alias that replaces C with 4, or Comet
      @addAlias(replaceLastChar(@name, "4"))
      @addAlias(replaceLastChar(@name, "Comet"))
      @nameCellClass = 'name-level-comet'
      
    if @name.endsWith(" P")
      # Add alias that replaces P with 100, or Purple Coins
      @addAlias(replaceLastChar(@name, "100"))
      @addAlias(replaceLastChar(@name, "Purple Coins"))
      if @name is "Gateway P"
        @addAlias(replaceLastChar(@name, "2"))
      else
        @addAlias(replaceLastChar(@name, "5"))
        @nameCellClass = 'name-level-comet'
        
    if @name.endsWith(" H") or @name is "Good Egg L" \
     or @name is "Honeyhive L" or @name is "Buoy Base G"
      @addAlias(replaceLastChar(@name, "H"))
      @addAlias(replaceLastChar(@name, "Hidden"))
      @addAlias(replaceLastChar(@name, "S"))
      @addAlias(replaceLastChar(@name, "Secret"))
      
      if @name is "Buoy Base G"
        @addAlias(replaceLastChar(@name, "2"))
      else
        @addAlias(replaceLastChar(@name, "6"))
        
    if @name is "Battlerock L" or @name is "Dusty Dune G"
      @addAlias(replaceLastChar(@name, "H2"))
      @addAlias(replaceLastChar(@name, "7"))
      
    if @name is "Battlerock L"
      @addAlias(replaceLastChar(@name, "G"))
      
    if @name.endsWith(" L")
      @addAlias(replaceLastChar(@name, "Luigi"))
      
    if @name.slice(-1) not in (digit.toString() for digit in [0..9])
      # Does not end in a number, must be a galaxy with only one star.
      # Accept an alias ending in " 1".
      @addAlias(@name + " 1")
      
    if @name.startsWith("Bowser's ")
      # Can omit
      @addAlias(@name.replace("Bowser's ", ""))
      @addAlias(@name.replace("Bowser's ", "") + " 1")
    else if @name.startsWith("Bowser Jr.'s ")
      # Can omit
      @addAlias(@name.replace("Bowser Jr.'s ", ""))
      @addAlias(@name.replace("Bowser Jr.'s ", "") + " 1")
      
    # Add to starNameLookup.
    # Note: This requires messages to be initialized before levels.
    
    # We could accept star names in other languages besides usenglish, but
    # this would only make sense if galaxy names, event names, etc. were
    # also accepted in multiple languages...
    
    starName = @starName('usenglish', 'mario')
    @constructor.starNameLookup[starName.toLowerCase()] = this
    starName = @starName('usenglish', 'luigi')
    @constructor.starNameLookup[starName.toLowerCase()] = this
      
    
  starName: (langCode, character) ->
    # Assume a star name message only has 1 box.
    box = Message.idLookup[@starNameId].data[langCode].boxes[0]
    if 'text' of box
      return box.text
    else
      # box has multiple cases; for star names the only possibilities are
      # mario and luigi.
      return box[character].text
        
      
  text: (starCount, character) ->
    if not starCount
      # Duplicate star (e.g. Bowser's Galaxy Reactor)
      return "#{@name} - #{@starName('usenglish', character)}"
      
    return "#{starCount.toString()}. #{@name} - #{@starName('usenglish', character)}"
  
  
class Event extends Item
  
# An Item that doesn't need to be specified in a human readable route.
# For example, an automatically occurring cutscene.
  
  
  constructor: (@name, details, messages) ->
    
    super(@name, details, messages)
    
    @nameCellClass = 'name-event'
      
      
  text: () ->
    return "* #{@name} "
    

class Message
  
  @idLookup: {}
  
  constructor: (@id, @data) ->
    @constructor.idLookup[@id] = this
    
    
  frames: (argSet, messageCase) ->
    
    frames = @data[argSet.langCode].frames
    
    if not frames
      console.log(
        "Requesting frame count of a null or empty message, " + @id
      )
      
    if 'base' not of frames
      # Multiple cases. Can be by character or by something else (specified
      # in messageCase).
      if messageCase
        frames = frames[messageCase]
      else
        frames = frames[argSet.character]
      
    messageFrames = frames['base']
    
    messageFrames += frames['num_boxes'] * argSet.boxEndTimingError
      
    if 'animation_time' of frames
      messageFrames = Math.max(messageFrames, frames['animation_time'])
      
    return messageFrames
    
    
  showFrameDetails: (argSet, messageCase) ->
    
    data = @data[argSet.langCode]
    $messageDetails = $('#message-details')
    $messageDetails.empty()
    
    # Display a Back button to make the route table viewable again
    $backButton = $('<button>')
    $backButton.text "Back"
    $backButton.click hideMessageDetails
    $messageDetails.append $backButton
    
    # Display the message id
    $h3 = $('<h3>').text(@id)
    $messageDetails.append $h3
    
    # Make a box length explanations table
    $table = $('<table>')
    $tbody = $('<tbody>')
    $table.append $tbody
    
    $('#route-table-container').hide()
    $messageDetails.show()
    
    boxLengths = []
    
    # Display box level frame details
    for box in data.boxes
      
      if 'mario' of box
        
        # box has multiple cases, mario and luigi; pick the one who applies
        box = box[argSet.character]
      
      else if 'text' not of box
        
        # Another kind of multi-case box
        box = box[messageCase]
        
      boxLengths.push box.length
        
      $tr = $('<tr>')
      $tbody.append $tr
      
      # Box text
      $td = $('<td>')
      $td.addClass 'box-text'
      
      boxTextLines = box.text.split('\n')
      
      for line, index in boxTextLines
        notLastLine = index < boxTextLines.length - 1
        
        # Since the webpage display sometimes has extra linebreaks,
        # make it clear where the actual message linebreaks are
        if notLastLine
          line += '↵'
          
        # Add box text
        $td.append document.createTextNode(line)
        
        if notLastLine
          # Put a br between text lines
          $td.append $('<br>')
      $tr.append $td
      
      # Box length explanation
      $td = $('<td>')
      $td.addClass 'box-length-explanation'
      boxLengthExplanation(box, argSet.langCode, $td)
      $tr.append $td
      
    # Display message level frame details
    frames = data.frames
    if 'base' not of frames
      # Multiple cases. Can be by character or by something else (specified
      # in messageCase).
      if messageCase
        frames = frames[messageCase]
      else
        frames = frames[argSet.character]
    messageFramesExplanation(
      boxLengths, frames, argSet.boxEndTimingError, $messageDetails
    )
    
    # Append box length explanations
    $messageDetails.append $table
    
    
hideMessageDetails = () ->
  
  $('#message-details').hide()
  $('#route-table-container').show()
    
    
boxLengthExplanation = (box, langCode, $el) ->
  
  # Append a box length(s) explanation to the jQuery element $el.
  
  charAlphaReq = 0.9
  if langCode == 'usenglish'
      fadeRate = 0.4375
  else if langCode == 'jpjapanese'
      fadeRate = 0.35
  else
      raise ValueError("Unsupported language code: " + str(lang_code))
  
  $ul = $('<ul>')
  $el.append $ul
    
  alphaReq = (box['chars'] * charAlphaReq) + 1
  line = "(#{box['chars']} chars * #{charAlphaReq} alpha req per char)
    + 1 extra alpha req = "
  result = "#{alphaReq.toFixed(1)} alpha req"
  $li = $('<li>')
  $li.append document.createTextNode(line)
  $li.append $('<span>').addClass('mid-result').text(result)
  $ul.append $li
  
  length = Math.floor(alphaReq / fadeRate)
  line = "floor(... / #{fadeRate} fade rate) = "
  result = "#{length} length"
  $li = $('<li>')
  $li.append document.createTextNode(line)
  $li.append $('<span>').addClass('mid-result').text(result)
  $ul.append $li
  
  if length + box['pause_length'] == box['length'] + 1
    
    length -= 1
    line = "Due to 32-bit float imprecision, it's actually "
    result = "#{length} length"
    $li = $('<li>')
    $li.append document.createTextNode(line)
    $li.append $('<span>').addClass('mid-result').text(result)
    $ul.append $li
  
  if box['pause_length'] > 0
    
    length += box['pause_length']
    line = "... + #{box['pause_length']} pause length = "
    result = "#{length} length"
    $li = $('<li>')
    $li.append document.createTextNode(line)
    $li.append $('<span>').addClass('mid-result').text(result)
    $ul.append $li
      
  # Whatever the final result was, style it as the final result.
  $finalResult = $li.find('span.mid-result')
  $finalResult.removeClass('mid-result').addClass('final-result')
    
    
messageFramesExplanation = (boxLengths, framesObj, boxEndTimingError, $el) ->
    
  # Append a message frames explanation to the jQuery element $el.
  $ul = $('<ul>')
  $el.append $ul
  
  if framesObj.forced_slow
    
    line = "Forced slow text, so 1 frame per length unit"
    $ul.append $('<li>').text(line)
    frames = 0
    
    for boxLength, index in boxLengths
      
      if index > 0
        line = "... + "
      else
        line = ""
      frames += boxLength + 2
      line += "(#{boxLength} box length / 1) + 2 box end delay frames = "
    
      result = "#{frames} frames"
      $li = $('<li>')
      $li.append document.createTextNode(line)
      $li.append $('<span>').addClass('mid-result').text(result)
      $ul.append $li
  
  else
    
    line = "When holding A, 1 frame per 3 length units"
    $ul.append $('<li>').text(line)
    
    if boxLengths.length > 1
      line = "When pressing A to end a box, the next box starts with up to
        10 frames of slow text because A was re-pressed"
      $ul.append $('<li>').text(line)
      
    frames = 0
    
    for boxLength, index in boxLengths
      
      if index == 0
        # First box
        frames += Math.ceil(boxLength / 3)
        line = "ceiling(#{boxLength} box length / 3) "
      else
        # Second box or later
        line = "... "
        if boxLength <= 10
          # Box is within 10 length
          frames += boxLength
          line += "+ (#{boxLength} length / 1) "
        else
          # Longer length
          frames += 10 + Math.ceil((boxLength-10) / 3)
          line += "+ (10 length / 1) "
          line += "+ ceiling((#{boxLength} length - 10) / 3) "
          
      frames += 2
      if index == 0
        line += "+ 2 box-end delay frames = "
      else
        line += "+ 2 delay frames = "
    
      result = "#{frames} frames"
      $li = $('<li>')
      $li.append document.createTextNode(line)
      $li.append $('<span>').addClass('mid-result').text(result)
      $ul.append $li
      
  if boxEndTimingError > 0
    # We've specified an average box end timing error of more than 0 frames.
    
    numBoxes = boxLengths.length
    frames += (numBoxes * boxEndTimingError)
    line = "... + (#{numBoxes} box endings 
      * #{boxEndTimingError} frames of human timing error) = "
      
    result = "#{frames} frames"
    $li = $('<li>')
    $li.append document.createTextNode(line)
    $li.append $('<span>').addClass('mid-result').text(result)
    $ul.append $li
    
  if framesObj.animation_time
    # There's a cutscene with animations that have to play out entirely before
    # advancing, even if the message is done.
    
    frames = Math.max(frames, framesObj.animation_time)
    line = "max(..., #{framesObj.animation_time} cutscene animation frames) = "
    
    result = "#{frames} frames"
    $li = $('<li>')
    $li.append document.createTextNode(line)
    $li.append $('<span>').addClass('mid-result').text(result)
    $ul.append $li
      
  # Whatever the final result was, style it as the final result.
  $finalResult = $li.find('span.mid-result')
  $finalResult.removeClass('mid-result').addClass('final-result')
      
  if framesObj.additional_factors
    # Any additional message factors (<Name>, <Number>) we haven't covered
    # should only be in messages we don't care about for routing. So if we
    # find something here, then that's a mistake...
    
    for factor in framesObj.additional_factors
      $li = $('<li>').text(
        "Additional factor that hasn't been measured: #{factor}"
      )
      $ul.append $li
    
    
    
    
class Route
  
  @numAndLevelRegex = /// ^
    \d+       # Number
    [\.|\)]   # . or )
    (.+)      # 1 or more chars of anything
  $ ///
  @actionAndParensNoteRegex = /// ^
    (.+)      # 1 or more chars of anything
    \(        # Left parens
    .+        # 1 or more chars of anything
    \)        # Right parens
  $ ///
  
  # 70 stars, 1 star, etc.
  @starsReqRegex = /^(\d+) stars?$/
  # Less than 70 stars, Less than 1 star, etc.
  @lessThanStarsReqRegex = /^Less than (\d+) stars?$/
  # 400 star bits, etc.
  @starBitReqRegex = /^(\d+) star bits$/
  
  
  constructor: (text, category) ->
    @actions = []
    
    # Split text into lines
    lines = text.split("\n")
    
    $('#route-status').empty()
    
    for line in lines
      
      line = line.trim()
      if line is ""
        # Blank line
        continue
      
      action = @lineToAction(line)
      if not action
        @setRouteStatus("Could not parse as a level/action: " + line)
        return
      else if action is 'comment'
        # Just a comment line in the text route; ignore it.
        continue
        
      @actions.push(action)
      
    if category is "Any%"
      @endItemName = "Bowser's Galaxy Reactor"
      @endRequirements = []
    else if category is "120 star"
      @endItemName = "Bowser's Galaxy Reactor"
      @endRequirements = ["120 stars"]
    else
      setRouteStatus("Unsupported category: #{category}")
      
  setRouteStatus: (s) ->
    $('#route-status').text(s)
      
    
  lineToAction: (line) ->
    if line.startsWith "*"
      # Assumed to be just a comment, e.g. "* Back to start of observatory"
      return 'comment'
    if line.startsWith ">"
      # Assumed to be an action with an exact name, e.g. "> Luigi letter 2".
      line = line.slice(1).trim()
      
    
    # Check if line begins with a star number like "5." or "17)"
    # If so, remove it
    match = @constructor.numAndLevelRegex.exec(line)
    if match
      line = match[1].trim()
    
    # Check if we have an alias match
    if line of Action.aliases
      return Action.aliases[line]
      
    # Check if line ends with a parenthesized thing like "(skip cutscenes)"
    # If so, remove it
    match = @constructor.actionAndParensNoteRegex.exec(line)
    if match
      line = match[1].trim()
    
    # Check again if we have an alias match
    if line of Action.aliases
      return Action.aliases[line]
      
    # Check for just the star name
    if line.toLowerCase() of Level.starNameLookup
      return Level.starNameLookup[line.toLowerCase()]
      
    # Check if there's a dash, and if so, see if we can find a
    # galaxy+number - starname match like "Good Egg 1 - Dino Piranha".
    # Either one will do, don't need both correct.
    # (e.g. "Good Egg - Dino Piranha" should work fine too.)
    # Try all the dashes if there's more than one.
    indexOfDash = line.indexOf('-')
    
    while indexOfDash isnt -1
      
      possibleGalaxyAndNum = line.slice(0, indexOfDash).trim()
      if possibleGalaxyAndNum of Action.aliases
        return Action.aliases[possibleGalaxyAndNum]
      
      possibleStarName = line.slice(indexOfDash+1).trim().toLowerCase()
      if possibleStarName of Level.starNameLookup
        return Level.starNameLookup[possibleStarName]
      
      indexOfDash = line.indexOf('-', indexOfDash+1)
    
    # Tried everything we could think of
    return null
    
  
  fulfilledRequirement: (req, completedItemNames, starCount) ->
    # Way 1 to satisfy requirement: req matches name of a completed action 
    if req in completedItemNames
      return true
      
    # Way 2: it's a >= stars req and we've got it
    match = @constructor.starsReqRegex.exec(req)
    if match
      reqStars = parseInt(match[1].trim())
      if starCount >= reqStars
        return true
        
    # Way 3: it's a < stars req and we've got it
    match = @constructor.lessThanStarsReqRegex.exec(req)
    if match
      reqLessThanStars = parseInt(match[1].trim())
      if starCount < reqLessThanStars
        return true
        
    # Way 4: it's a star bits req
    # TODO: Actually check this. For now we have no way of checking possible
    # or probable star bit count, so we skip the check.
    match = @constructor.starBitReqRegex.exec(req)
    if match
      return true
        
    return false
    
    
  isEndOfRoute: (item, completedItemNames, starCount) ->
    # If the run only ends on a particular route item, check for that
    # route item
    if @endItemName
      if item.name isnt @endItemName
        return false
    
    # Check that other end requirements are met
    for req in @endRequirements
      if not @fulfilledRequirement(req, completedItemNames, starCount)
        return false
        
    return true
    
    
  checkAndAddEvents: () ->
    # Add between-level events to the route.
    
    @items = []
    starCount = 0
    greenStarCount = 0
    expectedActionName = null
    completedItemNames = []
    # luigiStars goes up to 3: Good Egg L, Battlerock L, Honeyhive L
    luigiStatus = {talkedAtGarage: false, luigiStars: 0, betweenStars: 0}
    
    for action in @actions
      
      # Check if we are expecting a specific action here at this point in
      # the route.
      if expectedActionName
        if action.name isnt expectedActionName
          s = "At this point the route must have: '" \
            + expectedActionName + "' but instead it has: '" \
            + action.name + "'"
          @setRouteStatus(s)
        expectedActionName = null
        
      # Check requirements for this item.
      for req in action.requirements
        if not @fulfilledRequirement(req, completedItemNames, starCount)
          s = "'" + action.name + "' has an unfulfilled requirement: " + req
          @setRouteStatus(s)
          return
        
      # Check special requirements for Luigi events.
      if action.name is "Luigi letter 2"
        if not (luigiStatus.luigiStars is 1 and luigiStatus.betweenStars >= 5)
          s = "'" + action.name \
            + "' has an unfulfilled requirement: Must have 1 Luigi star and
            5 in-between stars since that Luigi star. Current status: " \
            + luigiStatus.luigiStars.toString() + " Luigi star(s) and " \
            + luigiStatus.betweenStars.toString() + " in-between star(s)."
          @setRouteStatus(s)
          return
      else if action.name is "Luigi letter 3"
        if not (luigiStatus.luigiStars is 2 and luigiStatus.betweenStars >= 5)
          s = "'" + action.name \
            + "' has an unfulfilled requirement: Must have 2 Luigi stars and
            5 in-between stars since that Luigi star. Current status: " \
            + luigiStatus.luigiStars.toString() + " Luigi star(s) and " \
            + luigiStatus.betweenStars.toString() + " in-between star(s)."
          @setRouteStatus(s)
          return
      
      # Add the action to the route.
      followingItems = []
      
      if action instanceof Level
        if action.name in completedItemNames
          # Duplicate star
          @items.push {
            item: action
            starCount: null
          }
        else
          starCount += 1
          @items.push {
            item: action
            starCount: starCount
          }
          
          # Check for "x star(s)" triggers
          if starCount is 1
            starCountStr = "1 star"
          else
            starCountStr = "#{starCount} stars"
          
          if starCountStr of Item.followingItemsLookup
            followingItems.push(Item.followingItemsLookup[starCountStr]...)
      else
        @items.push {
          item: action
        }
      completedItemNames.push action.name
      if @isEndOfRoute(action, completedItemNames, starCount)
        return
      
      # Update Green Star count if applicable
      if action.name in ["Battlerock L", "Buoy Base G", "Dusty Dune G"]
        greenStarCount += 1
        
        # Check for "x green star(s)" triggers
        if greenStarCount is 1
          starCountStr = "1 green star"
        else
          starCountStr = "#{greenStarCount} green stars"
        
        if starCountStr of Item.followingItemsLookup
          followingItems.push(Item.followingItemsLookup[starCountStr]...)
        
      # Update Luigi status if applicable
      if action.name is "Talk to Luigi at Garage"
        luigiStatus.talkedAtGarage = true
      else if luigiStatus.talkedAtGarage and action instanceof Level
        if action.name in ["Good Egg L", "Battlerock L", "Honeyhive L"]
          luigiStatus.luigiStars += 1
          luigiStatus.betweenStars = 0
        else
          luigiStatus.betweenStars += 1
          # Check for Luigi letter 1 event
          if luigiStatus.luigiStars is 0 and luigiStatus.betweenStars is 1
            followingItems.push(Item.idLookup["Luigi letter 1"])
      
      # Items triggered by this action specifically
      if action.name of Item.followingItemsLookup
        followingItems.push(Item.followingItemsLookup[action.name]...)
        
      while followingItems.length > 0
        followingItem = followingItems.shift()
        
        if followingItem instanceof Action
          # By some special case, this following "event" is also considered
          # an action of some sort. We'll go to the next iteration to process
          # this action, and we'll make a note to check that this action is
          # indeed the next item in the route.
          expectedActionName = followingItem.name
          continue
          
        # Ensure all of this item's trigger requirements are met before
        # adding the item. If the requirements aren't met, the item is not
        # triggered.
        reqFailed = false
        for req in followingItem.requirements
          if not @fulfilledRequirement(req, completedItemNames, starCount)
            reqFailed = true
        if reqFailed
          continue
          
        # Add the item to the route.
        @items.push {
          item: followingItem
        }
        completedItemNames.push followingItem.name
        if @isEndOfRoute(followingItem, completedItemNames, starCount)
          return
        
        # Check if other items are triggered by this item
        if followingItem.name of Item.followingItemsLookup
          followingItems.push(Item.followingItemsLookup[followingItem.name]...)
          
    @setRouteStatus("Route is incomplete!")
          
      
  makeTable: (argSets) ->
    $tableContainer = $('#route-table-container')
    $table = $('<table>')
    $tableContainer.empty().append($table)
    $thead = $('<thead>')
    $tbody = $('<tbody>')
    $table.append $thead
    $table.append $tbody
    
    $row = $('<tr>')
    $thead.append $row
    $row.append $('<th>').text("Level/Action/Event")
    
    for argSet in argSets
      $row.append $('<th>').text(argSet.display)
      
    # Determine whether to use Mario or Luigi in star names by seeing if
    # Mario or Luigi has more argSets. (If tied, it goes to Mario.)
    
    characterCounts = {mario: 0, luigi: 0}
    argSetCharacters = (argSet.character for argSet in argSets)
    for character in argSetCharacters
      characterCounts[character] += 1
      
    if characterCounts['mario'] >= characterCounts['luigi']
      preferredCharacter = 'mario'
    else
      preferredCharacter = 'luigi'
      
    # Add route items to the table as rows.
    
    textFrameTotals = (0 for argSet in argSets)
    
    for itemObj in @items
      item = itemObj.item
      
      if itemObj.starCount
        itemText = item.text(itemObj.starCount, preferredCharacter)
      else
        itemText = item.text()
      
      $row = $('<tr>')
      $tbody.append $row
      
      $cell = $('<td>')
      $cell.text itemText
      $cell.addClass item.nameCellClass
      $row.append $cell
      
      for argSet, index in argSets
        frames = item.frames argSet
        
        $cell = $('<td>')
        $cell.text frames
        $cell.addClass 'item-frames'
        
        # Currying a class function directly doesn't work,
        # so we use an intermediate function.
        f = (item_, argSet_) -> item_.showFrameDetails(argSet_)
        $cell.click(Util.curry(f, item, argSet))
        
        $row.append $cell
        
        textFrameTotals[index] += frames
        
    # Add frame-totals row.
    
    $row = $('<tr>')
    $tbody.append $row
      
    $cell = $('<td>').text "Total of relative text times"
    $row.append $cell
    
    for total in textFrameTotals
      $cell = $('<td>').text total
      $row.append $cell
      
    # Add differences column(s) if there are exactly two argSets.
    if argSets.length is 2
      
      # Header cells
      $headerRow = $thead.find('tr')
      $cell = $('<th>').text("Diff (f)")
      $headerRow.append $cell
      $cell = $('<th>').text("Diff (s)")
      $headerRow.append $cell
      
      # Data cells
      $rows = $tbody.find('tr')
      $rows.each( (_, row) =>
        cellTexts = ($(cell).text() for cell in $(row).find('td'))
        frameDiff = parseInt(cellTexts[1]) - parseInt(cellTexts[2])
        
        # Frame difference
        $cell = $('<td>').text frameDiff
        $(row).append $cell
        # Second difference
        $cell = $('<td>').text (frameDiff/(60/1.001)).toFixed(2)
        $(row).append $cell
      )
    

class Main
  
    
  init: (itemDetails, itemMessages, messages) ->
      
    # Initialize messages.
    for own messageId, message of messages
      new Message(messageId, message)
    
    # Initialize possible route items.
    for own itemKey, details of itemDetails
      args = [itemKey, details, itemMessages[itemKey] ? []]
      if details.type is 'Level'
        new Level(args...)
      else if details.type is 'Action'
        new Action(args...)
      else if details.type is 'Event'
        new Event(args...)
      else
        console.log(
          "Invalid item type: " + details.type
        )
        
    # Look at any message to get the available languages.
    for own messageId, message of messages
      anyMessage = message
      break
    languages = []
    languageLookup = {}
    for own langCode, data of anyMessage
      # The first 2 chars should be the region, rest should be language.
      obj = {
        code: langCode
        region: langCode.slice(0,2).toUpperCase()
        language: langCode.slice(2,3).toUpperCase() + langCode.slice(3)
      }
      obj.display = "#{obj.language} (#{obj.region})"
      languages.push obj
      languageLookup[langCode] = obj
      
    # The languages array will serve as a way to sort the languages.
    sortFunc = (a,b) ->
      if a.display < b.display
        return -1
      else if a.display > b.display
        return 1
      else
        return 0
    languages.sort(sortFunc)
      
    # Initialize the language dropdowns
    for set in ['set1', 'set2']
      $select = $("##{set}-langCode")
      
      # Fill with the ordered languages.
      for lang in languages
        $select.append(
          $('<option>').attr('value', lang.code).text(lang.display)
        )
        # Initialize with US English for the first, JP Japanese for the second.
        if set is 'set1'
          $select.val('usenglish')
        else
          $select.val('jpjapanese')
          
    # Initialize the boxEndTimingError dropdowns
    for set in ['set1', 'set2']
      $select = $("##{set}-boxEndTimingError")
      
      for num in [0..15]
        value = num.toString()
        text = num.toString()
        if text is "0"
          text = "0 (TAS)"
        $select.append $('<option>').attr('value', value).text(text)
        
      # Initialize with the value 5.
      $select.val("5")
    
    # Initialize the route processing button
    document.getElementById('route-button').onclick = (event) =>
      routeText = document.getElementById('route-textarea').value
      
      category = $('#route-category').val()
      route = new Route(routeText, category)
      
      route.checkAndAddEvents()
      
      # Build sets of text-frame-counting params/arguments from the fields
      argSets = []
      
      for set in ['set1', 'set2']
        argSet = {}
        
        for fieldName in ['langCode', 'character', 'boxEndTimingError']
          $field = $("##{set}-#{fieldName}")
          argSet[fieldName] = $field.val()
        
        argSet.boxEndTimingError = Number(argSet.boxEndTimingError)
          
        argSets.push argSet
        
      # Figure out suitable display names based on the argSets' differences
      if argSets[0].langCode isnt argSets[1].langCode
        lang1 = languageLookup[argSets[0].langCode]
        lang2 = languageLookup[argSets[1].langCode]
        if lang1.region isnt lang2.region
          # Language / region
          argSets[0].display = lang1.region
          argSets[1].display = lang2.region
        else
          # Language / language name
          argSets[0].display = lang1.language
          argSets[1].display = lang2.language
      else if argSets[0].character isnt argSets[1].character
        # Character
        char = argSets[0].character
        argSets[0].display = char.slice(0,1).toUpperCase() + char.slice(1)
        char = argSets[1].character
        argSets[1].display = char.slice(0,1).toUpperCase() + char.slice(1)
      else
        # Box end timing error
        argSets[0].display = argSets[0].boxEndTimingError.toString() + " BTE"
        argSets[1].display = argSets[1].boxEndTimingError.toString() + " BTE"
      
      route.makeTable argSets
      
      
window.main = new Main