function menu(caller) {
  json = eval( '(' + caller + ')' );
  add_zmenu(json);
  retrieve_menu_items(json);
}

function retrieve_menu_items(zmenu) {
  var url = "/common/populate_zmenu";

  var data;
  data = "type=" + zmenu.menu.type;
  data = data + "&ident=" + zmenu.menu.ident;

  var panelContent = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: response_received,
                           onLoading: loading
                         });
}

function response_received(response) {
  json = eval( "(" + response.responseText + ")" );
  if (json.menu.error) {
    json.menu.title = json.menu.error;
  }
  menu_id = 'ajax_zmenu_' + json.menu.ident;
  nz = ego(menu_id);
  nz.innerHTML = json.menu.title;
  add_menu_items(json, nz);
}

function loading(response) {
}

function add_zmenu(json) {
  ZM = ego('zmenus');
  menu_id = 'ajax_zmenu_' + json.menu.ident;
  child = ego(menu_id);
  if (child) {
    ZM.removeChild(child);
  }
  nz = dce('div');
  nz.className = 'zmenu';
  nz.innerHTML = json.menu.title;
  nz.style.borderColor = '#ff0000';
  nz.style.padding = '3px';
  nz.style.background = '#efefef';
  add_menu_items(json, nz);
  sa (nz, 'id', menu_id);
  ac(ZM, nz);
  show(nz);
  m2(nz, e_x, e_y);
}

function add_menu_items(json, nz) {
  for (i = 0; i < json.menu.items.length; i++) {
    add_row(json.menu.items[i].text, i, nz);
  }
}

function add_row(text, ident,  nz) {
  update = dce('div'); 
  sa(update, 'id', 'update_' + ident); 
  update.innerHTML = text;
  ac(nz, update);
}
