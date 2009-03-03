// Add the addLoadEvent function first so that is always ready to fire...
// note the first onload event should be the debug_list code!!

function _time_diff(x) {
  var d = new Date();
  return ((d.getTime()-x.getTime())/1000).toFixed(3);
}

function addLoadEvent(func) {
  var oldonload = window.onload;
  if( typeof window.onload != 'function' ) {
    window.onload = function() {
      var t = new Date();
      func();
      if( $('debug_list') ) {
        var x = func.toString().split(/\(/);
	if(!x) x = func;
	__info(x[0]+' ('+ _time_diff(t)+'s)');
      }
    }
  } else {
    window.onload = function() {
      oldonload();
      var t = new Date();
      func();
      if( $('debug_list') ) {
        var x = func.toString().split(/\(/);
	if(!x) x = func;
	__info(x[0]+' ('+_time_diff(t)+'s)');
      }
    };
  }
}

function _name_window() {
  if(!window.name) {
    var d = new Date();
    window.name = 'ensembl_'+d.getTime()+'_'+Math.floor(Math.random()*10000);
  }
}

addLoadEvent(_name_window);
