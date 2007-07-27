/* This is a bit of hacky code to pop up a debug window */
var _debug_window;
function debug_window() {
  if( _debug_window ) { return; }
  _debug_window=window.open('','__debug','height=400,width=600');
  D = _debug_window.document;
  h_3 = D.createElement( 'h3' );
  h_3.appendChild( D.createTextNode('HI!') );
  D.documentElement.appendChild(h_3);
  D.documentElement.style.fontSize = '0.7em';
  h_3.style.marginWidth = '0px';
  u_l = D.createElement( 'ul' );
  u_l.style.marginWidth = '0px';
  u_l.setAttribute('id','debug_list');
  D.documentElement.appendChild(u_l);
}

function debug( string ) {
  if( _debug_window ) {
    D = _debug_window.document;
    l_i = D.createElement( 'li' );
    l_i.documentElement.style.margin = '0px';
    l_i.appendChild(D.createTextNode( string ) );
    D.getElementById( 'debug_list' ).appendChild(l_i);
    _debug_window.focus();
  } else {
    alert( string );
  }
}

function debug_clear( ) {
  if( _debug_window ) {
    D = _debug_window.document;
    u_l = D.getElementById( 'debug_list' );
    while(u_l.hasChildNodes()) {
      u_l.removeChild(u_l.firstChild);
    }
  }
}

function toggle_settings_drawer() {
  if ($('settings').style.display == 'none') {
    $('settings_link').innerHTML = 'Hide account';
    new Effect.BlindDown('settings');
  } else {
    $('settings_link').innerHTML = 'Show account';
    new Effect.BlindUp('settings');
  }
}


function settings_drawer_change() {
  var display_id = $('group_select').value;
  set_style_for_class('all', 'none');
  set_style_for_class(display_id, '');
  save_drawer_change(display_id);
}

function getElementsByClass(searchClass,node,tag) {
  var classElements = new Array();
  if ( node == null )
    node = document;
  if ( tag == null )
    tag = '*';
  var els = node.getElementsByTagName(tag);
  var elsLen = els.length;
  var pattern = new RegExp('(^|\\s)'+searchClass+'(\\s|$)');
  for (i = 0, j = 0; i < elsLen; i++) {
    if ( pattern.test(els[i].className) ) {
      classElements[j] = els[i];
      j++;
    }
  }
  return classElements;
}

function save_drawer_change(ident) {
  var url = "/common/drawer";
  var data = "group=" + ident;
  var ajax_info = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: drawer_change_saved
                         });
}

function drawer_change_saved(response) {
}

function set_style_for_class(new_class,style) {
  var elements = getElementsByClass(new_class);
  for (var i = 0; i < elements.length; i++) {
    elements[i].style.display = style;
  }
}

// Return a link based on the current URL to the archive...

function addLoadEvent(func) {
  var oldonload = window.onload;
  if( typeof window.onload != 'function' ) {
    window.onload = func;
  } else {
    window.onload = function() {
      oldonload();
      func();
    }
  }
}

function cytoview_link() {
  URL = document.location.href;
  document.location = URL.replace(/(\w+view)/,'cytoview');
  return true; 
}

function archive( release ) {
  URL = document.location.href;
  document.location = URL.replace(/^https?:\/\/[^\/]+/,'http://'+release+'.archive.ensembl.org');
  return true; 
}

function login_link() {
  URL = escape(document.location.href);
  document.location = '/common/user/login?url=' + URL;
  return true;  
}

function logout_link() {
  URL = escape(document.location.href);
  document.location = '/common/user/logout?url=' + URL;
  return true;  
}

function das_link() {
  URL = escape(document.location.href);
  document.location = '/common/user/save_das?url=' + URL;
  return true;  
}

function add_config(ident) {
  URL = escape(document.location.href);
  var location = '/common/user/configuration?url=' + URL;
  if (ident) {
    location = location + ';id=' + ident;
  }
  document.location = location;
  return true;  
}

function change_config(ident) {
  URL = escape(document.location.href);
  var location = '/common/user/configuration?dataview=edit;url=' + URL;
  if (ident) {
    location = location + ';id=' + ident;
  }
  document.location = location;
  return true;  
}


function load_config(config_id) {
  URL = escape(document.location.href);
  document.location = '/common/user/load_config?id=' + config_id + ';url=' + URL;
  return true;  
}

function go_to_config(config_id) {
  document.location = '/common/user/load_config?id=' + config_id;
  return true;  
}

function bookmark_link() {
  URL = escape(document.location.href);

  var page_title;
  titles = document.getElementsByTagName("title");
  // assume first title tag is actual page title
  children = titles[0].childNodes;
  for (i=0; i<children.length; i++) {
    child = children[i];
    // look for text node
    if (child.nodeType == 3) {
      page_title = child.nodeValue;
    }
  }
  
  document.location = '/common/user/bookmark?name=' + page_title + ';url=' + URL;
  return true;  
}

function account_return() {
  var cookieKey = 'ENSEMBL_USER_REFERER';
  if (!readCookie(cookieKey)) {
    document.location = '/index.html';
  } else {
    document.location = unescape(readCookie(cookieKey));
  }
}

function ajaxCapability() {

//  window.onerror = errorSuppression;

  var cookieKey = 'ENSEMBL_AJAX';

  if (!readCookie(cookieKey)) {

  var useActiveX = false;
  var javaIsAvailable = false;
  var httpobj;
  var browserVersion = parseInt(window.navigator.appVersion);
  var browserName = window.navigator.appName;
  var ajaxCapability = "none";

  if (!(browserName.indexOf("Microsoft Internet Explorer"))) {
    if (typeof ScriptEngine != "undefined") {
      if (ScriptEngineMajorVersion() > 2) {
        httpobj = new ActiveXObject('Msxml2.XMLHTTP');
        if ((!httpobj) ||  (typeof httpobj == 'undefined')) httpobj = new ActiveXObject('Microsoft.XMLHTTP');
        if ((httpobj) ||  (typeof httpobj != 'undefined')) useActiveX = true;
      }
    }
  } else {
    useActiveX = false;
    if (window.navigator.javaEnabled() == true) javaIsAvailable = true;
    httpobj = new XMLHttpRequest();
  }

  if ((!httpobj) || (typeof httpobj == 'undefined')) {
    if (javaIsAvailable == true) {
      ajaxCapability = "java";
    } else {
      if ((browserVersion >= 3)  && (browserName.indexOf("Netscape"))) {
        ajaxCapability = "iframe";
      } else {
        ajaxCapability = "ilayer";
      }
      if (browserVersion < 3) {
        ajaxCapability = "none";
      }
    }
  } else {
    if (useActiveX == true) {
      ajaxCapability = "activex";
    } else {
      ajaxCapability = "builtin";
    }
  }

  createCookie(cookieKey, ajaxCapability, 30);
  }
}

function createCookie(name,value,days) {
  if (days) {
    var date = new Date();
    date.setTime(date.getTime()+(days*24*60*60*1000));
    var expires = "; expires="+date.toGMTString();
  } else {
    var expires = "";
  }
  document.cookie = name+"="+value+expires+"; path=/";
}

function readCookie(name) {
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	for(var i=0;i < ca.length;i++) {
		var c = ca[i];
		while (c.charAt(0)==' ') c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
}

ajaxCapability();
