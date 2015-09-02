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
      
      
window.Util = Util
