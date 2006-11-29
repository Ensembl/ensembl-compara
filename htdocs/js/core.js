/* A place to dump random javascript */

// Return a link based on the current URL to the archive...

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
