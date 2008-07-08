var zmenus         = {};
var zmenus_counter = 1;
var zmenu_current_zindex = 200;
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
    moveto( $(zmenus[x.key]), x.x, x.y );
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
  var Z = location.href;
  Z = Z.replace(/#.*$/,'').replace(/\?r=[^;]+;?/,'\?').replace(/;r=[^;]+;?/,';').replace(/[\?;]$/g,'');
  Z+= Z.match(/\?/) ? ';' : '?';
  Z+= "r="+__seq_region_name+':';
  
  var cp = 1 * x.bp;
  var w  = __seq_region_width-1;
  var Q  = __zmenu_init('zmenu_nav', 'Location: '+Math.floor(cp) );
  __info( x.bp+' '+cp+' '+w );
  __zmenu_add( Q, '', 'Zoom out x10', Z+(cp-w*5)  +'-'+(cp+w*5)   );
  __zmenu_add( Q, '', 'Zoom out x5',  Z+(cp-w*2.5)+'-'+(cp+w*2.5) );
  __zmenu_add( Q, '', 'Zoom out x2',  Z+(cp-w*1)  +'-'+(cp+w*1)   );
  __zmenu_add( Q, '', 'Centre here',  Z+(cp-w/2)  +'-'+(cp+w/2)   );
  __zmenu_add( Q, '', 'Zoom in x2',   Z+(cp-w/4)  +'-'+(cp+w/4)   );
  __zmenu_add( Q, '', 'Zoom in x5',   Z+(cp-w/10) +'-'+(cp+w/10)  );
  __zmenu_add( Q, '', 'Zoom in x10',  Z+(cp-w/20) +'-'+(cp+w/20)  );
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
  Q.setStyle({'z-index':zmenu_current_zindex++});
  __info( zmenu_current_zindex+' '+Q.getStyle('z-index') );
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
  Event.observe( dt_node, 'mousedown', drag_start );
}
