# Utility functions.

class Util
  
  @curry: (orig_func) ->
    
    # Specify arguments of a function without actually calling that function yet.
    # Source:
    # http://benalman.com/news/2010/09/partial-application-in-javascript/
    ap = Array.prototype
    args = arguments
  
    fn = () ->
      ap.push.apply(fn.args, arguments)
  
      if fn.args.length < orig_func.length
        return fn
      else
        return orig_func.apply(this, fn.args)
  
    return () ->
      fn.args = ap.slice.call(args, 1)
      return fn.apply(this, arguments)
      
      
  @readServerTextFile: (filepath, callback) ->
    # Read a text file that's local to the server. Same as any
    # old Ajax call, but still nice to have a wrapper.
    #
    # To make this work with Chrome in development, be careful with your
    # server setup. Serving your directory with Python is one way that works.
    # http://stackoverflow.com/a/5869667
    
    $.ajax({
      url: filepath
      type: 'GET'
      dataType: 'text'
      success: callback
    })
    
    
  @splitlines: (s) ->
    # Split a string s by its newline characters. Return the
    # resulting multiple strings as an array.
    # This regex should handle \r\n, \r, and \n.
    return s.split(/\r\n|[\n\r]/)
      
      
window.Util = Util
