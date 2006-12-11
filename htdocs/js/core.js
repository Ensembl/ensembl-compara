/* A place to dump random javascript */


function toggle_settings_drawer() {
  if ($('settings').style.display == 'none') {
    new Effect.BlindDown('settings');
  } else {
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
  document.location = '/login.html?url=' + URL;
  return true;  
}

function config_link() {
  URL = escape(document.location.href);
  document.location = '/common/save_config?url=' + URL;
  return true;  
}

function load_config(config_id) {
  URL = escape(document.location.href);
  document.location = '/common/load_config?id=' + config_id + '&url=' + URL;
  return true;  
}

function logout_link() {
  URL = escape(document.location.href);
  // return to home page if logging out from account management
  if (URL.indexOf('logout') > -1 || URL.indexOf('account') > -1) {
    URL = '/';
  }
  document.location = '/common/user_logout?url=' + URL;
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
  
  document.location = '/common/bookmark?node=name_bookmark;bm_name=' + page_title + ';bm_url=' + URL;
  return true;  
}
