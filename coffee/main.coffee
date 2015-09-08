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
    # Make all aliases lowercase, so we can do case insensitive recognition.
    @constructor.aliases[alias.toLowerCase()] = this
    
    
  @addAliases: () ->
      
    # The Level constructor added a basic alias for every level: the level
    # name itself.
    # Here we add more aliases for various actions (mostly levels).
    
    replaceLastChar = (s1, s2) -> s1.slice(0, s1.length - 1) + s2
    
    # Make a way to filter aliases based on a boolean test.
    getAliases = (boolFunc) ->
      if not boolFunc?
        return Action.aliases
      
      aliasSubset = {}
      for alias, action of Action.aliases
        if boolFunc(alias)
          aliasSubset[alias] = action
      return aliasSubset
      
    for alias, action of getAliases((a) -> a.startsWith("bowser's "))
      # Can omit this part
      action.addAlias alias.replace("bowser's ", "")
      
    for alias, action of getAliases((a) -> a.startsWith("bowser jr.'s "))
      # Can omit this part
      action.addAlias alias.replace("bowser jr.'s ", "")
        
    # Detect single-star galaxies - easier to do this before we've added
    # more star ending possibilities.
    starEndings = ['1','2','3','h','g','l','c','p']
    for alias, action of getAliases((a) -> not a.endsWith(starEndings))
      if action instanceof Level
        # This should be a galaxy with only one star.
        # Accept an alias ending in " 1".
        action.addAlias (alias + " 1")
      
    for alias, action of getAliases((a) -> a.endsWith(" c"))
      # Add alias that replaces c with 4, or comet
      action.addAlias replaceLastChar(alias, "4")
      action.addAlias replaceLastChar(alias, "comet")
        
    for alias, action of getAliases((a) -> a.endsWith(" p"))
      action.addAlias replaceLastChar(alias, "100")
      action.addAlias replaceLastChar(alias, "purples")
      action.addAlias replaceLastChar(alias, "purple coins")
      action.addAlias replaceLastChar(alias, "purple comet")
      if alias is "gateway p"
        action.addAlias replaceLastChar(alias, "2")
      else
        action.addAlias replaceLastChar(alias, "5")
        
    for alias, action of getAliases()
      if alias in ["good egg l", "honeyhive l", "buoy base g"]
        action.addAlias replaceLastChar(alias, "h")
          
      if alias in ["battlerock l", "dusty dune g"]
        action.addAlias replaceLastChar(alias, "h2")
        action.addAlias replaceLastChar(alias, "hidden 2")
        action.addAlias replaceLastChar(alias, "hidden star 2")
        action.addAlias replaceLastChar(alias, "s2")
        action.addAlias replaceLastChar(alias, "secret 2")
        action.addAlias replaceLastChar(alias, "secret star 2")
        action.addAlias replaceLastChar(alias, "7")
        
      if alias is "battlerock l"
        action.addAlias replaceLastChar(alias, "g")
    
    for alias, action of getAliases((a) -> a.endsWith(" h"))
      
      action.addAlias replaceLastChar(alias, "hidden")
      action.addAlias replaceLastChar(alias, "hidden star")
      action.addAlias replaceLastChar(alias, "s")
      action.addAlias replaceLastChar(alias, "secret")
      action.addAlias replaceLastChar(alias, "secret star")
        
      if alias is "buoy base h"
        action.addAlias replaceLastChar(alias, "2")
      else
        action.addAlias replaceLastChar(alias, "6")
        
    for alias, action of getAliases((a) -> a.endsWith(" l"))
      action.addAlias replaceLastChar(alias, "luigi")
      action.addAlias replaceLastChar(alias, "luigi star")
    
    for alias, action of getAliases((a) -> a.endsWith(" g"))
      action.addAlias replaceLastChar(alias, "green")
      action.addAlias replaceLastChar(alias, "green star")
      
      
  text: () ->
    return "> " + @name
  
  
class Level extends Action
  
# An action that yields a star.

  
  @starNameLookup: {}
  
  
  constructor: (@name, details, messages) ->
    
    super(@name, details, messages)
    
    @nameCellClass = 'name-level'
    
    @starNameId = details.star_name
    
    if @name.endsWith(" C")
      @nameCellClass = 'name-level-comet'
    if @name.endsWith(" P") and @name isnt "Gateway P"
      @nameCellClass = 'name-level-comet'
      
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
    argSet = {character: character, langCode: langCode}
    # Assume a star name message only has 1 box.
    box = Message.idLookup[@starNameId].computeBoxes(argSet, null)[0]
    return box.text
        
      
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
    
    
class MessageUtil
    
  @hideMessageDetails: () ->
    
    $('#message-details').hide()
    $('#route-table-container').show()
    
    
  @decodeUTF16BigEndian: (byteArray) ->
    # Idea from http://stackoverflow.com/a/14601808
    numCodePoints = byteArray.length / 2
    codePoints = []
    for i in [0..(numCodePoints - 1)]
      codePoints.push(
        byteArray[i*2]
        + byteArray[i*2 + 1] << 8
      )
    return String.fromCharCode.apply(String, codePoints)
    
    
  @bytesStartWith: (bytes, arr2) ->
    # bytes is an array of integers. Return true if bytes
    # starts with a sub-array equal to arr2.
    
    # Get a byte array from the beginning of bytes, max
    # length equal to arr2's length
    arr1 = bytes.slice(0, arr2.length)
    
    # See if arr1 and arr2 are equal
    if arr1.length isnt arr2.length
      return false
    return arr1.every((element, index) ->
      return element is arr2[index] 
    )
    
    
  @processEscapeSequence: (
    escapeBytes, boxes, messageId, argSet, messageCase,
    displayColors=false, displayFurigana=false) ->
    # Add the escape sequence contents to the boxes structure.
    
    escapeBytesStartWith = Util.curry(@bytesStartWith, escapeBytes)
    lastBox = boxes[boxes.length-1]
    
    if escapeBytesStartWith [1,0,0,0]
      # Text pause - length is either 10, 15, 30, or 60.
      pauseLength = escapeBytes[4]
      text = "<Text pause, #{pauseLength.toString()}L>"
      
      if 'pauseLength' of lastBox
        lastBox.pauseLength += pauseLength
      else
        lastBox.pauseLength = pauseLength
        
    else if escapeBytesStartWith [1,0,1]
      # Message box break.
      text = ""
      boxes.push({chars: 0, text: ""})
      
    else if escapeBytesStartWith [1,0,2]
      text = '<Lower-baseline text>'
        
    else if escapeBytesStartWith [1,0,3]
      text = '<Center align>'
        
    else if escapeBytesStartWith [2,0,0,0,0x53]
      text = '<Play voice audio>'
        
    else if escapeBytesStartWith [3,0]
      # Icon.
      iconByte = escapeBytes[2]
      iconName = messageLookup.icons[iconByte]
      text = "<#{iconName} icon>"
      # Any icon counts as one character.
      lastBox.chars += 1
      
    else if escapeBytesStartWith [4,0,0]
      text = '<Small text>'
        
    else if escapeBytesStartWith [4,0,2]
      text = '<Large text>'
      
    else if escapeBytesStartWith [5,0,0,0,0]
      # Mario's name or Luigi's name.
      if messageCase is 'general'
        # TODO: Use this case
        text = '<Player name>'
      else
        if argSet.character is 'mario'
          textMessageId = 'System_PlayerName000'
        else if argSet.character is 'luigi'
          textMessageId = 'System_PlayerName100'
          
        textMessage = Message.idLookup[textMessageId]
        text = textMessage.computeBoxes(argSet, messageCase)[0].text
        lastBox.chars += text.length
        
    else if escapeBytesStartWith [5,0,0,1,0]
      # Mario's name or Luigi's name, drawn out excitedly.
      if messageCase is 'general'
        # TODO: Use this case
        text = '<Mr. Plaaayer naaame>'
      else
        if argSet.character is 'mario'
          textMessageId = 'System_PlayerName001'
        else if argSet.character is 'luigi'
          textMessageId = 'System_PlayerName101'
          
        textMessage = Message.idLookup[textMessageId]
        text = textMessage.computeBoxes(argSet, messageCase)[0].text
        lastBox.chars += text.length
        
    else if escapeBytesStartWith [6] or escapeBytesStartWith [7]
      # A number or name variable.
      # The actual text is message dependent, or even case dependent beyond
      # that (e.g. which level a Hungry Luma is in). But we have defined the
      # text for the cases that we care about.
      
      if messageId of messageLookup.numbersNames
        obj = messageLookup.numbersNames[messageId]
        numberNameType = obj._type
        
        if messageCase is 'general'
          # TODO: Use this case
          text = obj._placeholder
        
        else if numberNameType is 'text'
          if messageCase of obj
            text = obj[messageCase]
          else if argSet.character of obj
            text = obj[argSet.character]
          lastBox.chars += text.length
          
        else if numberNameType is 'message'
          if messageCase of obj
            textMessageId = obj[messageCase]
          else if argSet.character of obj
            textMessageId = obj[argSet.character]
      
          textMessage = Message.idLookup[textMessageId]
          text = textMessage.computeBoxes(argSet, messageCase)[0].text
          lastBox.chars += text.length
            
      else
        console.log(
          "Don't know how to handle number/name variable"
          + "for message: #{messageId}"
        )
        # TODO: Indicate an error somehow?
        
    else if escapeBytesStartWith [9,0,5]
      # Race time (Spooky Sprint, etc.)
      text = 'xx:xx:xx'
      lastBox.chars += text.length
      
    else if escapeBytesStartWith [0xFF,0,0]
      # Signify start or end of text color.
      colorByte = escapeBytes[3]
      colorType = messageLookup.colors[colorByte]
      if displayColors
        text = "<#{colorType} color>"
      else
        text = ""
        
    else if escapeBytesStartWith [0xFF,0,2]
      # Japanese furigana (kanji reading help).
      kanjiCount = escapeBytes[3]
      furiganaBytes = escapeBytes.slice(4)
      furiganaStr = @decodeUTF16BigEndian(furiganaBytes)
      if displayFurigana
        text = "<#{furiganaStr}>"
      else
        text = ""
        
    else
      console.log("Unknown escape sequence: #{escapeBytes}")
      # TODO: Indicate an error somehow?
      
    lastBox.text += text
    
    
  @boxTextDisplayHTML: ($el, box) ->
    
    # Append a display of a box's text to the jQuery element $el.
      
    boxTextLines = box.text.split('\n')
    
    for line, index in boxTextLines
      notLastLine = index < boxTextLines.length - 1
      
      # Since the webpage display sometimes has extra linebreaks,
      # make it clear where the actual message linebreaks are
      if notLastLine
        line += '↵'
        
      # Add box text
      $el.append document.createTextNode(line)
      
      if notLastLine
        # Put a br between text lines
        $el.append $('<br>')
        
    # TODO: Make a version of this function (or different argument?) for
    # box text display for CSV.
    
    
  @computeBoxLength: (box, langCode, $el=null) ->
    
    # Compute the length of the box and store the result in box.length.
    #
    # If a jQuery element $el is given, append an explanation of the
    # box length computation to that element.
    
    charAlphaReq = messageLookup.languageSpeeds[langCode].alphaReq
    fadeRate = messageLookup.languageSpeeds[langCode].fadeRate
    
    $ul = $('<ul>')
    if $el?
      $el.append $ul
      
    alphaReq = (box.chars * charAlphaReq) + 1
    line = "(#{box.chars} chars * #{charAlphaReq} alpha req per char)
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
        
    # Confine to float32 precision to see what the game actually computes
    f32 = Math.fround
    alphaReqF32 = f32(f32(box.chars) * f32(charAlphaReq)) + f32(1)
    lengthF32 = Math.floor(f32(f32(alphaReqF32) / f32(fadeRate)))
    
    if length isnt lengthF32
      
      length = lengthF32
      line = "Due to 32-bit float imprecision, it's actually "
      result = "#{length} length"
      $li = $('<li>')
      $li.append document.createTextNode(line)
      $li.append $('<span>').addClass('mid-result').text(result)
      $ul.append $li
    
    if 'pauseLength' of box
      
      # Add pause length if applicable.
      length += box.pauseLength
      line = "... + #{box.pauseLength} pause length = "
      result = "#{length} length"
      $li = $('<li>')
      $li.append document.createTextNode(line)
      $li.append $('<span>').addClass('mid-result').text(result)
      $ul.append $li
      
    # Set the computed length in the box object.
    box.length = length
        
    # Whatever the final result element was, style it as the final result.
    $finalResult = $li.find('span.mid-result')
    $finalResult.removeClass('mid-result').addClass('final-result')
    
    
  @messageFrames: (boxes, messageId, boxEndTimingError, $el=null) ->
    
    boxLengths = (b.length for b in boxes)
      
    # Append a message frames explanation to the jQuery element $el.
    $ul = $('<ul>')
    if $el?
      $el.append $ul
    
    if messageId in messageLookup.forcedSlow
      
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
      
    if messageId of messageLookup.animationTimes
      # There's a cutscene with animations that have to play out entirely before
      # advancing, even if the message is done.
      animationTime = messageLookup.animationTimes[messageId]
      
      frames = Math.max(frames, animationTime)
      line = "max(..., #{animationTime} cutscene animation frames) = "
      
      result = "#{frames} frames"
      $li = $('<li>')
      $li.append document.createTextNode(line)
      $li.append $('<span>').addClass('mid-result').text(result)
      $ul.append $li
        
    # Whatever the final result was, style it as the final result.
    $finalResult = $li.find('span.mid-result')
    $finalResult.removeClass('mid-result').addClass('final-result')
    
    # Return the computed frame count.
    return frames
    

class Message
  
  @idLookup: {}
  
  constructor: (@id, @data) ->
    @constructor.idLookup[@id] = this
    
    
  computeBoxes: (argSet, messageCase) ->
    
    content = @data[argSet.langCode]
    
    # TODO: Handle content == null
    # TODO: Handle content == []
    
    boxes = [{chars: 0, text: ""}]
    
    for item in content
      
      # An item could be a box break which changes the last box, so
      # re-set this after every item.
      lastBox = boxes[boxes.length-1]
      
      if typeof(item) is "string"
        # Text.
        
        # A message box break seems to always be followed by a
        # newline character, but in this situation the newline
        # doesn't affect the time the box text takes to scroll.
        # So we won't count such a newline as a character for our
        # purposes.
        #
        # Box break check: the latest box's text is empty.
        # Action: Chop off the leading newline.
        newlineAfterBoxBreak = \
          item.charAt(0) is '\n' and lastBox.text is ""
        if newlineAfterBoxBreak
          item = item.slice(1)
        
        lastBox.chars += item.length
        lastBox.text += item
      else
        # Escape sequence.
        # This function will add the escape sequence contents
        # to the boxes structure.
        MessageUtil.processEscapeSequence(
          item, boxes, @id, argSet, messageCase
        )
        
    # At this point we've got text and chars covered, and pauseLength
    # if applicable. Compute the box lengths.
    for box in boxes
      MessageUtil.computeBoxLength(box, argSet.langCode)
        
    return boxes
    
    
  frames: (argSet, messageCase) ->
    
    boxes = @computeBoxes(argSet, messageCase)
    frames = MessageUtil.messageFrames(boxes, @id, argSet.boxEndTimingError)
    return frames
    
    
  showFrameDetails: (argSet, messageCase) ->
    
    data = @data[argSet.langCode]
    $messageDetails = $('#message-details')
    $messageDetails.empty()
    
    # Display a Back button to make the route table viewable again
    $backButton = $('<button>')
    $backButton.text "Back"
    $backButton.click MessageUtil.hideMessageDetails
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
    
    boxes = @computeBoxes(argSet, messageCase)
    
    # Display box level frame details
    for box in boxes
        
      $tr = $('<tr>')
      $tbody.append $tr
      
      # Box text
      $td = $('<td>')
      $td.addClass 'box-text'
      MessageUtil.boxTextDisplayHTML($td, box)
      $tr.append $td
      
      # Box length explanation
      $td = $('<td>')
      $td.addClass 'box-length-explanation'
      MessageUtil.computeBoxLength(box, argSet.langCode, $td)
      $tr.append $td
      
    # Display message level frame details
    MessageUtil.messageFrames(
      boxes, @id, argSet.boxEndTimingError, $messageDetails
    )
    
    # Append box length explanations
    $messageDetails.append $table
    
    
    
    
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
    lines = Util.splitlines(text)
    
    $('#route-status').empty()
    
    for line in lines
      
      line = line.trim()
      if line is ""
        # Blank line
        continue
      
      action = @lineToAction(line)
      if not action
        @addRouteStatus("Could not recognize as a level/action: " + line)
        break
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
      
      
  addRouteStatus: (s) ->
    
    $('#route-status').append(document.createTextNode(s))
    $('#route-status').append(document.createElement('br'))
      
    
  lineToAction: (line) ->
    # Make item recognition non-case-sensitive
    line = line.toLowerCase()
    
    if line.startsWith '*'
      # Assumed to be just a comment, e.g. "* Back to start of observatory"
      return 'comment'
    if line.startsWith '>'
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
    if line of Level.starNameLookup
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
      reqStars = Number(match[1].trim())
      if starCount >= reqStars
        return true
        
    # Way 3: it's a < stars req and we've got it
    match = @constructor.lessThanStarsReqRegex.exec(req)
    if match
      reqLessThanStars = Number(match[1].trim())
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
          @addRouteStatus(s)
        expectedActionName = null
        
      # Check requirements for this item.
      for req in action.requirements
        if not @fulfilledRequirement(req, completedItemNames, starCount)
          s = "'" + action.name + "' has an unfulfilled requirement: " + req
          @addRouteStatus(s)
          return
        
      # Check special requirements for Luigi events.
      if action.name is "Luigi letter 2"
        if not (luigiStatus.luigiStars is 1 and luigiStatus.betweenStars >= 5)
          s = "'" + action.name \
            + "' has an unfulfilled requirement: Must have 1 Luigi star and
            5 in-between stars since that Luigi star. Current status: " \
            + luigiStatus.luigiStars.toString() + " Luigi star(s) and " \
            + luigiStatus.betweenStars.toString() + " in-between star(s)."
          @addRouteStatus(s)
          return
      else if action.name is "Luigi letter 3"
        if not (luigiStatus.luigiStars is 2 and luigiStatus.betweenStars >= 5)
          s = "'" + action.name \
            + "' has an unfulfilled requirement: Must have 2 Luigi stars and
            5 in-between stars since that Luigi star. Current status: " \
            + luigiStatus.luigiStars.toString() + " Luigi star(s) and " \
            + luigiStatus.betweenStars.toString() + " in-between star(s)."
          @addRouteStatus(s)
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
          
    @addRouteStatus("Route is incomplete!")
          
      
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
        frameDiff = Number(cellTexts[1]) - Number(cellTexts[2])
        
        # Frame difference
        $cell = $('<td>').text frameDiff
        $(row).append $cell
        # Second difference
        $cell = $('<td>').text (frameDiff/(60/1.001)).toFixed(2)
        $(row).append $cell
      )
      
      
determineArgSets = (languageLookup) -> 
      
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
    
  return argSets
    

class Main
  
    
  init: (itemDetails, itemMessages, messages) ->
      
    # Initialize messages.
    for own messageId, data of messages
      new Message(messageId, data)
    
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
      
    # Add text aliases for possible route items.
    Action.addAliases()
        
    # Get info on the available languages.
    languages = []
    languageLookup = {}
    for own langCode, _ of messageLookup.languageSpeeds
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
        
      # Initialize the value.
      $select.val("10")
    
    # Initialize the route processing button
    document.getElementById('route-button').onclick = (event) =>
      $('#route-status').empty()
      
      routeText = document.getElementById('route-textarea').value
      
      category = $('#route-category').val()
      route = new Route(routeText, category)
      
      route.checkAndAddEvents()
      
      argSets = determineArgSets(languageLookup)
      route.makeTable argSets
        
    # Initialize help button(s)
    $('.help-button').each( () ->
      buttonIdRegex = /^(.+)-button$/
      result = buttonIdRegex.exec(this.id)
      helpTextId = result[1]
      
      # When this help button is clicked, open the corresponding
      # help text in a modal window.
      clickCallback = (helpTextId_, helpButtonE) ->
        
        $helpText = $('#'+helpTextId_)
        
        $helpText.dialog({
          modal: true
          width: 500
          height: 600
          position: {
            my: "center top"
            at: "center bottom"
            of: helpButtonE
          }
        })
        
        # NOTE: The below only applies to the route textarea help, so if
        # there's another help button at some point, then this code needs
        # to be moved somewhere else.
        
        # Part of the help text involves listing all the non-level actions.
        # The first time this help text is opened, fill the list.
        $actionList = $('#action-list')
        if $actionList.is(':empty')
          for id, item of Item.idLookup
            # Ensure we're listing non-level actions.
            if (item instanceof Action) and not (item instanceof Level)
              $actionList.append(
                $('<li>').append $('<code>').text('> '+item.name)
              )
        
        # Make the dialog's scroll position start at the top. If we don't do
        # this, then it starts where the in-dialog button is, for some reason.
        $helpText.scrollTop(0)
        
      $(this).click(
        Util.curry(clickCallback, helpTextId, this)
      )
    )
    
    # Initialize fill-with-sample-route button
    $('#sample-route-button').click( () ->
      callback = (text) ->
        document.getElementById('route-textarea').value = text
      Util.readServerTextFile("sampleroute.txt", callback)
    )
      
      
window.main = new Main