var zmenus         = {};
var zmenus_counter = 1;

function _close_zmenu( evt ) {
  evt.findElement('table').hide();
}

function _show_zmenu( x ) {
  if( ! zmenus[ x.key ] ) {
    var z_id = 'zmenu_'+(zmenus_counter++);
    zmenus[ x.key ] = z_id;
    var A = x.title.split("; ");
    var ttl = A.shift();
    if(!ttl) ttl = 'Menu';
    var Q = __zmenu_init( z_id, ttl );
    A.each(function(s){
      var T = s.split(': ');

      if(T.length > 1 ) {
        __zmenu_add( Q, T[0], T[1] );
      } else {
        __zmenu_add( Q, '', T[0] );
      }
    });
    __zmenu_add( Q, 'Link', ttl, x.h );
    __zmenu_show( Q, x.x, x.y );

    var a = x.h.split(/\?/);
    var link_url     = a[0];
    var query_string = a[1];
    var arr = link_url.match(/^(https?:\/\/[^\/]+\/[^\/]+\/)([^\/]+)/);
    var URL = arr[1]+'Zmenu/'+arr[2]+'?'+query_string;
    __info( 'zmenu...'+URL );
    new Ajax.Request( URL, {
      method: 'get',
      onSuccess: function(transport){
        Q.getElementsBySelector('tbody.real')[0].replace( transport.responseText );
        __zmenu_close_button(Q);
      }
    });
  } else {
    $(zmenus[x.key]).show();
  }
  return;
}

function _show_zmenu_range( x ) {
  __zmenu_remove();
  var Q = __zmenu_init('zmenu_nav','Region');
  __zmenu_add( Q, '', 'Zoom into region', 'xx' );
  __zmenu_add( Q, '', 'Centre here',      'xx' );
  __zmenu_show(Q, x.x, x.y);
}

function _show_zmenu_location( x ) {
  __zmenu_remove();
  var Q = __zmenu_init('zmenu_nav', 'Location' );
  __zmenu_add( Q, '', 'Zoom out x10', 'xx' );
  __zmenu_add( Q, '', 'Zoom out x5',  'xx' );
  __zmenu_add( Q, '', 'Zoom out x2',  'xx' );
  __zmenu_add( Q, '', 'Centre here',  'xx' );
  __zmenu_add( Q, '', 'Zoom in x2',   'xx' );
  __zmenu_add( Q, '', 'Zoom in x5',   'xx' );
  __zmenu_add( Q, '', 'Zoom in x10',  'xx' );
  __zmenu_show(Q, x.x, x.y);
}

function __zmenu_init( z_id, z_cap ) {
  var Q = Builder.node('table', { className: 'zmenu', id: z_id},[
    Builder.node('tbody',{className:'real'},[
      Builder.node('tr',[
        Builder.node('th',{className: 'caption',colSpan:2},[z_cap])
      ])
    ])
  ]);
  ensembl_body.appendChild(Q);
  return $(z_id);
}

function __zmenu_add( Q, ll, text, link ) {
  var X = link ?  Builder.node('a',{href:link},[text]) : text;
  if( ll == '' ) {
    Q.getElementsBySelector('tbody.real')[0].appendChild(Builder.node('tr',[
      Builder.node('td',{colSpan:2},[X])
    ]));
  } else {
    Q.getElementsBySelector('tbody.real')[0].appendChild(Builder.node('tr',[
      Builder.node('th',[ll]),
      Builder.node('td',[X])
    ]));
  }
}

function __zmenu_show(Q,x,y) {
  __zmenu_close_button(Q);
  moveto(Q,x,y);
  Q.show();
}

function __zmenu_remove() {
  if($('zmenu_nav')){ $('zmenu_nav').remove(); }
}

function __zmenu_close_button(Z) {
  var b_close = Builder.node('span',{className:'close'},'X');
  var dt_node = Z.getElementsByClassName('caption')[0];
  var X=1;
  dt_node.insertBefore(b_close,dt_node.firstChild );
  Event.observe( b_close, 'click', _close_zmenu);
}
