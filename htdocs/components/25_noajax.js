// Functions to pass the referer, in case user has no AJAX therefore no modal window

function control_panel(URL) {
  window.open(URL,'control_panel','width=950,height=500,resizable,scrollbars');
}

function logout_link() {
  URL = escape(document.location.href);
  document.location = '/Account/Logout?url=' + URL;
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
  
  document.location = '/Account/Bookmark?name=' + page_title + ';url=' + URL;
  return true;  
}

function load_config(config_id) {
  URL = escape(document.location.href);
  document.location = '/Account/load_config?id=' + config_id + ';url=' + URL;
  return true;  
}

function go_to_config(config_id) {
  document.location = '/Account/load_config?id=' + config_id;
  return true;  
}
