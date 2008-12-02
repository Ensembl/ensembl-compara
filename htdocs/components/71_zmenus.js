/*
  zmenu global variables...
  zmenus                <- hash of ids for object "zmenus"
  zmenus_counter        <- incrementing counter to give each zmenu a unique id
  zmenus_current_zindex <- attempt to get zmenus to come to fron if clicked again
                           doesn't seem to set z-index tho' will need to look
			   at this in more detail
*/

var zmenus         = {};
var zmenus_counter = 1;
var zmenu_current_zindex = 200;

function _close_zmenu( evt ) { evt.findElement('table').hide(); }

function _show_zmenu( x ) {
/**
 Show the zmenu for a given feature - details are stored in the passed
 parameter hash "x"
  key   - index into zmenus area which stores details of zmenu (based on key for
          area in display)
  title - Title of map area; used to construct temporary menu
          of form "Type: Value; Type: Value; .... Type: Value"
  h     - The link for the map area - used to generate the temporary menu; munged to
          make AJAX call 
  x     - x location of click
  y     - y location of click
**/

// If the zmenu is cached just reload it... [ get id out of zmenus hash ]
__info(x.key);
  if( zmenus[ x.key ] && $(zmenus[x.key])) {
    $(zmenus[x.key]).show();
    moveto( $(zmenus[x.key]), x.x, x.y );
    return;
  }
  var z_id = 'zmenu_'+(zmenus_counter++);
// Store the id in the zmenus hash...
  zmenus[ x.key ] = z_id;
  var A = x.title.split("; ");
  var ttl = A.shift();
  if(!ttl) ttl = 'Menu';
  var Q = __zmenu_init( z_id, ttl );
  var loc = { cp:0,s:0,e:0 };
  A.each(function(s){
    var T = s.split(': ');
    if(T.length > 1 ) {
      __zmenu_add( Q, T[0], T[1] );
/* If the "entry is Location: chr:start-end then save the start/end and centre point for
   later... */
      if( T[0] == 'Location' ) {
        var tmp = T[1].match(/:(-?\d+)-(-?\d+)$/);
	if(tmp) loc = { cp: tmp[1]/2+tmp[2]/2, s: parseInt(tmp[1]), e: parseInt(tmp[2]) };
      }
    } else {
      __zmenu_add( Q, '', T[0] );
    }
  });
  if(x.h && x.h!='#') __zmenu_add( Q, 'Link', ttl, x.h );
  if( window.location.pathname.match(/\/Location/) && loc.cp ) {
    __zmenu_add( Q, ' ', 'Centre on feature', _new_url_cp( loc.cp, __seq_region.width + 1 ) );
    __zmenu_add( Q, ' ', 'Zoom to feature',   _new_url(    loc.s,  loc.e                  ) );
  }
  __zmenu_show( Q, x.x, x.y );
  __init_ensembl_rel_external();
// If AJAX isn't enabled return....
  if(!x.h) return;
  if( ENSEMBL_AJAX != 'enabled' ) return;
/* Rewrite the href URL to a zmenu URL....
 A link of the form: https?://{domain}/{species}/{type}/{view}?{params}
 becomes:            http://{domain}/{species}/Zmenu/{type}?{params}
 Then call this with AJAX - and replace the "temporary" zmenu content with this;
 Finally add back in the close zmenu button!
*/
  var a = x.h.split(/\?/);
  var link_url     = a[0];
  var query_string = a[1];
  var arr = link_url.match(/^(https?:\/\/[^\/]+\/[^\/]+\/)(.+)/);
  if(!arr) return;
  var URL = arr[1]+'Zmenu/'+arr[2]+'?'+query_string;
  new Ajax.Request( URL, {
    method: 'get',
    onSuccess: function(transport){
      var t = transport.responseText;
      if( t && t.match( /<tbody class="real">/ ) ) {
        Q.getElementsBySelector('tbody.real')[0].replace( t );
        __init_ensembl_rel_external();
        __zmenu_close_button(Q);
      }
    }
  });
}

function _new_url_cp( cp, w ) { return w>=1 ? _new_url( Math.round(1*cp-(w-1)/2), Math.round(1*cp+(w-1)/2) ) : ''; }

function _new_url( s, e ) {
/** compute new url for location based link link...
 Firstly remove the r parameter from the URL... then add it back again based on:
   __seq_region.name, s and e
*/
  var Z = location.href;
  Z = Z.replace(/\&/g,';').replace(/#.*$/g,'').replace(/\?r=[^;]+;?/g,'\?').replace(/;r=[^;]+;?/g,';').replace(/[\?;]$/g,'');
  Z+= Z.match(/\?/) ? ';' : '?';
  return Z+"r="+__seq_region.name+':'+s+'-'+e;
}

function _show_zmenu_range_other( x ) {
  __zmenu_remove();
  var Z = location.search;
  Z = Z.replace(/\?r=[^;]+;?/,'\?').replace(/;r=[^;]+;?/,';').replace(/[\?;]$/g,'');
  Z+= Z.match(/\?/) ? ';' : '?';
  var view = x.bp_end - x.bp_start > 1e6 ? 'Overview' : 'View';
  var Q = __zmenu_init('zmenu_nav','Region: '+x.bp_start+'-'+x.bp_end);
  __zmenu_add( Q, '', 'Jump to location '+view,
    '/'+x.species+'/Location/'+view+Z+'r='+x.region+':'+x.bp_start+'-'+x.bp_end 
  );
  __zmenu_show(Q, x.x, x.y);

}
function _show_zmenu_range( x ) {
/**
  zmenu for range query takes a parameter hash
  bp_start - start of range in base pairs
  bp_end   - end of range in base pairs
  x        - x-coord of pixel at which mouse released
  y        - y-coord of pixel at which mouse released
*/
  __zmenu_remove();
  var Q = __zmenu_init('zmenu_nav','Region: '+x.bp_start+'-'+x.bp_end);
  __zmenu_add( Q, '', 'Jump to region',   _new_url( x.bp_start, x.bp_end ) );
  __zmenu_add( Q, '', 'Centre here',      _new_url_cp( (x.bp_start+x.bp_end)/2, __seq_region.width-1 ) );
  __zmenu_show(Q, x.x, x.y);
}

function _show_zmenu_location_other( x ) {
  __zmenu_remove();
  var Z = location.search;
  Z = Z.replace(/\?r=[^;]+;?/,'\?').replace(/;r=[^;]+;?/,';').replace(/[\?;]$/g,'');
  Z+= Z.match(/\?/) ? ';' : '?';
  var Q = __zmenu_init( 'zmenu_nav', 'Location: '+Math.floor(x.bp) );
  var w = __seq_region ? (__seq_region.end - __seq_region.start +1) : 100000;
  var s = Math.floor(x.bp-w/2);
  __zmenu_add( Q, '', 'Chromosome summary',
    '/'+x.species+'/Location/Chromosome'+Z+'r='+x.region+':'+s+'-'+(w+s) 
  );
  __zmenu_add( Q, '', 'Jump to location view',
    '/'+x.species+'/Location/View'+Z+'r='+x.region+':'+s+'-'+(w+s)
  );
  __zmenu_show( Q, x.x, x.y );
}

function _show_zmenu_location( x ) {
  __zmenu_remove();
  var w  = __seq_region.width;
  var Q  = __zmenu_init('zmenu_nav', 'Location: '+Math.floor(x.bp) );
  __zmenu_add( Q, '', 'Zoom out x10', _new_url_cp( x.bp, w*10 ) );
  __zmenu_add( Q, '', 'Zoom out x5',  _new_url_cp( x.bp, w*5  ) );
  __zmenu_add( Q, '', 'Zoom out x2',  _new_url_cp( x.bp, w*2  ) ); 
  __zmenu_add( Q, '', 'Centre here',  _new_url_cp( x.bp, w*1  ) );
  __zmenu_add( Q, '', 'Zoom in x2',   _new_url_cp( x.bp, w/2  ) );
  __zmenu_add( Q, '', 'Zoom in x5',   _new_url_cp( x.bp, w/5  ) );
  __zmenu_add( Q, '', 'Zoom in x10',  _new_url_cp( x.bp, w/10 ) );
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

var xhtml_obj;
function __zmenu_add( Q, ll, text, link ) {
  var X;
  var use_innerHTML = 0;
  if( link && link!='#') {
    X = Builder.node('a',{href:link},[text]);
  } else {
    if(!xhtml_obj) xhtml_obj = new XhtmlValidator();
    error = xhtml_obj.validate( text );
    use_innerHTML = error ? 0 : 1;
  }
  var X = (link && link!='#')?  Builder.node('a',{href:link},[text]) : text;
  if( ll == '' ) {
    if( use_innerHTML ) {
      var A = Builder.node('td',{colSpan:2});
      A.innerHTML = X;
      Q.getElementsBySelector('tbody.real')[0].appendChild(Builder.node('tr',[A]));
    } else {
      Q.getElementsBySelector('tbody.real')[0].appendChild(Builder.node('tr',[
        Builder.node('td',{colSpan:2},[X])
      ]));
    }
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
