function menu(caller) {
  json = eval( '(' + caller + ')' );
  add_zmenu(json);
  retrieve_menu_items(json);
}

function retrieve_menu_items(zmenu) {
  var url = "/" + zmenu.menu.species + "/populate_zmenu";

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

  title = ego('title_' + json.menu.ident);
  title.innerHTML = json.menu.title;

  body = ego('table_' + json.menu.ident);
  body.innerHTML = "";
  add_menu_items(json, body);
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
//  nz.innerHTML = json.menu.title;
//  nz.style.borderColor = '#ff0000';
//  nz.style.padding = '3px';
//  nz.style.background = '#efefef';

  t = dce( 'table' );
  t.style.backgroundColor = '#ffffff'
  t.style.borderCollapse  = 'collapse';
  t.style.borderWidth     = '0px';
  t.style.width           = '200px';
  t_h=dce('thead');t_r=dce('tr');
  t_h1=dce('th');t_h2=dce('th');t_h3=dce('th');
  t_h1.onmousedown = drag_start;
  t_h1.style.width = '170px';
  t_h2.style.width = '15px';
  t_h3.style.width = '15px';

  sa (t_h1, 'id', 'title_' + json.menu.ident);
  ac( t_h1, dtn( json.menu.title ) );

  cl = dce( 'a' );var mn = dce( 'a' );
  mn.onclick = function() {
    var N = this.parentNode.parentNode.parentNode.parentNode.getElementsByTagName('tbody')[0];
    var I = this.getElementsByTagName('img')[0];
    if(N.style.display=='none') {
      N.style.display=''
      I.src = '/img/dd_menus/up.gif';
    } else {
      N.style.display='none'
      I.src = '/img/dd_menus/down.gif';
    }
  }
  sa( cl, 'href', 'javascript:void(hide_zmenu("'+ menu_id +'"))' );
  im2 = dce( 'img' );
  im2.style.borderWidth = 0;
  im2.height = 12
  im2.width  = 12
  im2.src = '/img/dd_menus/up.gif';
  im2.className = 'right';

  im = dce( 'img' );
  im.style.borderWidth = 0;
  im.height = 12
  im.width  = 12
  im.src = '/img/dd_menus/close.gif';
  im.className = 'right';

  sa( im, 'alt',   'X' );
  sa( im, 'title', 'Close zmenu' );

  sa( im2, 'alt', 'v' );
  sa( im2, 'title', 'Min zmenu' );
  ac(mn,im2);
  ac(cl,im);
  ac(t_h2,mn);
  ac(t_h3,cl);
  ac(t_r,t_h1);
  ac(t_r,t_h2);
  ac(t_r,t_h3);
  ac(t_h,t_r);
  ac(t,t_h);

  t_b=dce('tbody');
  sa (t_b, 'id', 'table_' + json.menu.ident);
  ac(t,t_b);
  ac(nz,t);

  add_menu_items(json, t_b);

  sa (nz, 'id', menu_id);
  ac(ZM, nz);
  show(nz);
  m2(nz, e_x, e_y);
}

function add_menu_items(json, tb) {
  for (i = 0; i < json.menu.items.length; i++) {
    add_row(json.menu.items[i].text, i, tb);
  }
}

function add_row(text, ident,  tb) {
  row = dce('tr'); 
  col = dce('td');
  col.innerHTML = text;
  col.colSpan = 3;
  ac(row, col);
  ac(tb, row);
}
