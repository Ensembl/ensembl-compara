/*========================================================================
  This is the meat and drink of the new advanced web-interface code....
  
  This breaks down into two sections currently:
  
  * section 1 - drag functionality for zmenus - this is nice and
    straightforward - three functions drag_start (mouse down), 
    drag_move (mouse drag) and drag_stop( mouse up )...
    
  * section 2 - drag and select functionality...
  
========================================================================*/

var dragging_object = null;
var dragging_id     = null;
var drag_offset_x   = 0;
var drag_offset_y   = 0;
var selectoi ;
var SELECTION_X;
var SELECTION_Y;
var IE_offset = -1;
var N = 3;

// This is eht zmenu on mouse down menus....
// Grab event... get it's location and also location of current
// object... this gives us the 
function drag_start( evt ) { debug_print( 'drag_start' );
  evt = (evt) ? evt : ((event)?event:null)
  dragging_object = gee(evt).parentNode.parentNode.parentNode.parentNode;
  drag_offset_x = egeX(evt) - egX(dragging_object);
  drag_offset_y = egeY(evt) - egY(dragging_object);
  
  document.getElementsByTagName('body')[0].onmousemove = drag_move;
  document.getElementsByTagName('body')[0].onmouseup   = drag_stop;
  document.getElementsByTagName('body')[0].onmouseout  = drag_move;
}

function drag_stop( evt ) { debug_print( 'drag_stop' );
  document.getElementsByTagName('body')[0].onmousemove = null;
  document.getElementsByTagName('body')[0].onmouseup   = null;
  document.getElementsByTagName('body')[0].onmouseout  = null;
}

function drag_move( evt ) { debug_print( 'drag_move' );
  evt = (evt) ? evt : ((event)?event:null)
  m2( dragging_object, egeX(evt) - drag_offset_x, egeY(evt) - drag_offset_y );
}

// Funtionality for the drag-select mechanism....

function select_start( evt ) { if(MAC && MODE=='IE6') return;
  debug_print( 'select_start' );
  evt = (evt) ? evt : ((event)?event:null)
  SELECTION_DIV   = gp(gee(evt),'DIV');
  dragging_object = gp( gee(evt), 'DIV' );
  dragging_id     = dragging_object.getAttribute('id')
  IE_offset       = 0; // MODE == 'IE6' ? 2 : 0;
  drag_offset_x   = egX( SELECTION_DIV ) + IE_offset; 
  drag_offset_y   = egY( SELECTION_DIV ) + IE_offset; 
  SELECTION_X     = egeX(evt) - drag_offset_x
  SELECTION_Y     = egeY(evt) - drag_offset_y
  for(i=4;i<8;i++) {
    T = ego(red_box_divs[i]);
    if(T) { T.parentNode.removeChild(T); }
    var D = dce('div');
    var I = dce('img');
    sa(D,'id',red_box_divs[i]);
    D.className = 'redbox';
    D.style.backgroundColor = 'red';
    sa(I,'src', '/img/blank.gif');
    ac(D,I);
    ac(dragging_object,D);
    rs(D,1,1);
    rs(I,1,1);
  }

  show(ego('other_l'));
  m2(ego('other_l'), SELECTION_X, SELECTION_Y, 1, 1 );
  m2(ego('other_t'), SELECTION_X, SELECTION_Y, 1, 1 );
  m2(ego('other_r'), SELECTION_X, SELECTION_Y, 1, 1 );
  m2(ego('other_b'), SELECTION_X, SELECTION_Y, 1, 1 );
  ac(dragging_object,ego('other_l'));
  ac(dragging_object,ego('other_r'));
  ac(dragging_object,ego('other_b'));
  ac(dragging_object,ego('other_t'));
//  document.getElementsByTagName('body')[0].onmousemove = select_move;
  document.getElementsByTagName('body')[0].onmousemove = select_move;
  document.getElementsByTagName('body')[0].onmouseup   = select_stop;
  return false;
}

function select_move(evt) { debug_print( 'select_move' );
  evt     = (evt) ? evt : ((event)?event:null)
  O       = egi(dragging_id+'_i');
  var I   = gee(evt);
  enx     = egeX(evt) - drag_offset_x;
  eny     = egeY(evt) - drag_offset_y;
  bps     = p2b( dragging_id, enx );
  O.title = seq_region()+': '+bps
  el = ego( 'other_l' )
  if( el && egH( el )+egW( el ) > 0 ) { /* this is our current rubber band */
    br_x = O.width  -1;
    br_y = O.height -1;
    if(enx<0) enx = 0;  if(eny<0) eny = 0;
    if(enx>br_x) enx = br_x;if(eny>br_y) eny = br_y;
    W = enx-SELECTION_X;
    H = eny-SELECTION_Y;
    if( W*W+H*H > N*N-1 ) {
      show(el);
      show(ego('other_t'));
      show(ego('other_r'));
      show(ego('other_b'));
    }
    m2(el,             SELECTION_X,           SELECTION_Y+(H>0?0:1), 1,            H+(H>0?1:-1) );
    m2(ego('other_t'), SELECTION_X+(W>0?0:1), SELECTION_Y,           W+(W>0?1:-1), 1            );
    m2(ego('other_r'), enx,                   SELECTION_Y+(H>0?0:1), 1,            H+(H>0?1:-1) );
    m2(ego('other_b'), SELECTION_X+(W>0?0:1), eny,                   W+(W>0?1:-1), 1            );
  }
  return false;
}


function select_stop(evt) { debug_print( 'select_stop' );
  evt = (evt) ? evt : ((event)?event:null)
  document.getElementsByTagName('body')[0].onmousemove = null;
  document.getElementsByTagName('body')[0].onmouseup   = null;

  F = document.forms['panel_form'];
  el = ego( 'other_l' )
  if( el && egH( el )+egW( el ) > 0 ) { /* this is our current rubber band */
    sx = egX( el );
    sy = egY(ego('other_t'));
    hide( el );
    hide(ego('other_t'));
    hide(ego('other_r'));
    hide(ego('other_b'));
    rs( el, 0 , 0 );
    rs( ego('other_t'), 0 , 0 );
    rs( ego('other_r'), 0 , 0 );
    rs( ego('other_b'), 0 , 0 );
    e_x = enx   = egeX(evt);
    e_y = eny   = egeY(evt);
    O    = egi(dragging_id+'_i');
    tl_x = egX(O);
    tl_y = egY(O);
    br_x = tl_x + egW(O)  -1;
    br_y = tl_y + egH(O) -1;
    if( enx < tl_x ) { enx = tl_x; }
    if( eny < tl_y ) { eny = tl_y; }
    if( enx > br_x ) { enx = br_x; }
    if( eny > br_y ) { eny = br_y; }
    W = enx-sx;
    H = eny-sy;
    if( W*W+H*H > N*N-1) {
//  ac(dragging_object,ego('real_l'));
//  ac(dragging_object,ego('real_r'));
//  ac(dragging_object,ego('real_b'));
//  ac(dragging_object,ego('real_t'));
      show(ego('real_l'));
      show(ego('real_t'));
      show(ego('real_r'));
      show(ego('real_b'));

      m2(ego('real_l'), sx,    sy, 1,   H+1 ); m2(ego('real_t'), sx, sy,    W+1, 1   );
      m2(ego('real_r'), enx,   sy, 1,   H+1 ); m2(ego('real_b'), sx, eny,   W+1, 1   );
      chr = F.chr.value
/* Centre point of object */
      ocp = Math.floor( 0.5 * F.elements[dragging_id+'_bp_end'].value + 0.5 * F.elements[dragging_id+'_bp_start'].value );
      ow  = Math.floor( 1.0 * F.elements[dragging_id+'_bp_end'].value - 1.0 * F.elements[dragging_id+'_bp_start'].value + 1 );
      ns  = 1.0 * p2b( dragging_id,  sx-tl_x );
      ne  = 1.0 * p2b( dragging_id, enx-tl_x );
      cp  = Math.floor( 0.5 * ns + 0.5 * ne );
      w   = ne - ns;
      aw  = F.elements['main_width'].value;
      panel_type = F.elements[dragging_id+'_flag'].value;
      switch( panel_type ) {
        case 'bp':
          lnks = new Array(
            new Array( 'View this region in basepair view', cv_URL( { c: cp, zw: w } ) ),
            new Array( 'Centre on this region',             cv_URL( { c: cp }       ) )
          );
          break;
        case 'cv':
          lnks = new Array(
            new Array( 'View this region in basepair view', cv_URL( { c: cp, zw: w } ) ),
            new Array( 'Zoom into this region',             cv_URL( { c: cp, w: w  } ) ),
            new Array( 'Centre on this region',             cv_URL( { c: cp        } ) )
          );
      }
      var S = seq_region( dragging_id ) +': '+ns+ " - " + ne;
      show_zmenu( S, e_x, e_y, lnks, 0 );
      return void(0);
    } else {
// This is a click 
      image_map = ego( dragging_id + '_i_map' );
// If we have an image map lets see if it is in a feature
/*
      if(evt.ctrlKey) {
        chr = F.chr.value
        cp  = p2b( dragging_id, enx-tl_x )
        aw  = F.elements['main_width'].value;
        // This is the centering action!! 
        URL = '';
        panel_type = F.elements[dragging_id+'_flag'].value;
        switch( panel_type ) {
          case 'bp': URL = cv_URL( { c: cp } ); break;
          case 'cv': URL = cv_URL( { c: cp } ); break;
        }
        alert( URL )
        return void(0);
      } else if(evt.shiftKey) {
        // Make this a zoom in action.... 
        chr = F.chr.value 
        cp  = p2b( dragging_id, enx-tl_x )
        aw  = F.elements['main_width'].value;
        URL = '';
        panel_type = F.elements[dragging_id+'_flag'].value;
        switch( panel_type ) {
          case 'bp': URL = cv_URL( { c: cp, zw: F.elements['bp_width'].value/2   } ); break;
          case 'cv': URL = cv_URL( { c: cp,  w: F.elements['main_width'].value/2 } ); break;
        }
        alert( URL )
        return void(0);
      }
*/
      if(image_map && !(evt.altKey)) {
        L = image_map.areas.length;
        for(i=0;i<L;i++) {
          zmn = 'zmenu_'+dragging_id+'_'+i
          A = image_map.areas[i];
          pts = A.coords.split(/\D+/);
          if( A.shape=='poly' ? in_poly( pts, enx-tl_x, eny-tl_y ) : ( A.shape=='circle' ? in_circle( pts, enx-tl_x, eny-tl_y ) : in_rect( pts, enx-tl_x, eny-tl_y ) ) ) {
            if(A.onclick) {
              CLICK_X  = e_x;
              CLICK_Y  = e_y;
              ZMENU_ID = zmn;
              MOUSE_UP = 1;
              A.onclick();
              MOUSE_UP = 0;
            } else if(A.onmouseover) {
              CLICK_X  = e_x;
              CLICK_Y  = e_y;
              ZMENU_ID = zmn;
              MOUSE_UP = 1;
              A.onmouseover();
              MOUSE_UP = 0;
            } else {
              if( A.title.substr(  0, 6 ) == 'About:' ) {
                lnks = new Array(
                  new Array( "Genes were annotated by the Ensembl automatic analysis pipeline using either a GeneWise model from a human/vertebrate protein, a set of aligned human cDNAs followed by GenomeWise for ORF prediction or from Genscan exons   supported by protein, cDNA and EST evidence. GeneWise models are further combined with available aligned cDNAs to annotate UTRs." ),
                  new Array('Further help',A.href)
                );
              } else {
                if( A.href && A.href != 'javascript:void(0)') {
                  lnks = new Array(
                    new Array( 'test' ),
                    new Array('Further information...',A.href)
                  );
                } else {
                  lnks = new Array(
                    new Array( 'test' )
                  );
                }
              }
              show_zmenu( A.title, e_x, e_y, lnks, zmn );
            }
            return void(0);
          }
        }
      }
// If not give the appropriate centering dialog...
      chr = F.chr.value
      cp  = p2b( dragging_id, enx-tl_x )
      aw  = 1.0*F.elements['main_width'].value; 
      zw  = 1.0*F.elements['bp_width'].value; 
      panel_type = F.elements[dragging_id+'_flag'].value;
      switch( panel_type ) {
        case 'bp': 
          lnks = new Array(
//        new Array( 'Centre basepair view here', '/' ),
            new Array( 'Zoom in x5',    cv_URL({ c: cp, zw: zw/5 } ) ),
            new Array( 'Zoom in x2',    cv_URL({ c: cp, zw: zw/2 } ) ),
            new Array( 'Centre',        cv_URL({ c: cp, zw: zw } ) ),
            new Array( 'Zoom out x2',   cv_URL({ c: cp, zw: zw*2 } ) ),
            new Array( 'Zoom out x5',   cv_URL({ c: cp, zw: zw*5 } ) )
          );
          break;
        case 'cv':
          lnks = new Array(
//        new Array( 'Centre basepair view here', '/' ),
            new Array( 'Zoom in x10',   cv_URL({ c: cp, w: aw/10 } ) ),
            new Array( 'Zoom in x5',    cv_URL({ c: cp, w: aw/5 }  ) ),
            new Array( 'Zoom in x2',    cv_URL({ c: cp, w: aw/2 }  ) ),
            new Array( 'Centre',        cv_URL({ c: cp          }  ) ),
            new Array( 'Zoom out x2',   cv_URL({ c: cp, w: aw*2 }  ) ),
            new Array( 'Zoom out x5',   cv_URL({ c: cp, w: aw*5 }  ) ),
            new Array( 'Zoom out x10',  cv_URL({ c: cp, w: aw*10 } ) )
          );
      }
      show_zmenu( seq_region( dragging_id ) +': '+ cp, e_x, e_y, lnks );
    }
  }
  return void(0);
}

function cv_alert() { alert('CV'); }
function bp_alert() { alert('BP'); }
function cv_URL( hash ) {
  F   = document.forms['panel_form'];
  URL = F.elements[ 'base_URL'].value;
  URL += '?c='+F.elements[ 'chr'].value+':'+hash.c+
         ';w='+(hash.w?hash.w:F.elements[ 'main_width'].value);
  if( hash.zw ) {
    URL += ';zoom_width='+hash.zw;
  }
  return URL;
}
// Functionality required by zmenu
function in_circle( pts, pt_x, pt_y ) { return (pt_x-pts[0])*(pt_x-pts[0]) + (pt_y-pts[1])*(pt_y-pts[1]) <= pts[2]*pts[2]; }
function in_rect( pts, pt_x, pt_y ) { return pt_x >= pts[0] && pt_y >= pts[1] && pt_x <= pts[2] && pt_y<= pts[3]; }
function in_poly( pts, pt_x, pt_y ) {
  var L = pts.length;
  var T = 0;
  for(var i=0;i<L;i+=2) {
    x1 = pts[     i % L ] - pt_x;
    y1 = pts[ (i+1) % L ] - pt_y;
    x2 = pts[ (i+2) % L ] - pt_x;
    y2 = pts[ (i+3) % L ] - pt_y;
    T += Math.atan2( x1*y2-y1*x2, x1*x2+y1*y2);
  }
  return Math.abs(T/Math.PI/2) > 0.01;
}

