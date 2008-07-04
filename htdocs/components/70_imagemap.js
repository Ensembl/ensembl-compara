function moveto( el, lt, tp, wd, ht ) {
  if( wd < 0 ) { lt+=wd;wd=-wd;}
  if( ht < 0 ) { tp+=ht;ht=-ht;}
  el.setStyle({ left: lt+'px', top: tp+'px'});
  if(wd||ht) resize( el, wd, ht );
}

function resize(el,wd,ht) {
  el.setStyle({ width: wd+'px', height: ht+'px'});
}

var dragging_object = null;
var dragging_image  = null;
var drag_offset_x   = 0;
var drag_offset_y   = 0;
var N               = 3;
var events          = {};
var lines           = ['l','r','b','t'];

var fudge_x         = Prototype.Browser.IE ? 2 : 1;
var fudge_y         = Prototype.Browser.IE ? 3 : 1;

function drag_start( event ) {
  dragging_object = Event.element(evt).up('div');
  var x = draggin_object.cumulativeOffset();
  drag_offset_x = Event.pointerX(event) - x[0];
  drag_offset_y = Event.pointerY(event) - x[1];
  Event.observe(ensembl_body,'mousemove', drag_move);
  Event.observe(ensembl_body,'mouseup'  , drag_stop);
  Event.observe(ensembl_body,'mousedown', drag_move);
}

function drag_stop( event ) {
  Event.stopObserving(ensembl_body,'mousemove', drag_move);
  Event.stopObserving(ensembl_body,'mouseup'  , drag_stop);
  Event.stopObserving(ensembl_body,'mousedown', drag_move);
}

function drag_move( event ) {
  moveto( dragging_object, Event.pointerX(event) - drag_offset_x, Event.pointerY(event) - drag_offset_y );
}

function select_start( evt ) {
  if( evt.button == 2 ) { return; }
  dragging_object = Event.findElement( evt, 'div' );
  dragging_image  = Event.findElement( evt, 'img' );
  if( !dragging_image ) {
    dragging_map = Event.findElement( evt, 'map' );
    dragging_image = $( dragging_map.id.substring(0, dragging_map.id.length - 4 ) );
  }
  var x           = dragging_object.cumulativeOffset();
  drag_offset_x   = x[0];
  drag_offset_y   = x[1];
  SELECTION_X     = Event.pointerX(evt) - x[0] - fudge_x;
  SELECTION_Y     = Event.pointerY(evt) - x[1] - fudge_y;
  lines.each(function(n){
    var nm = 'other_'+n;
    if($(nm)){$(nm).remove();}
    dragging_object.appendChild( Builder.node('div',{
      id: nm, left:SELECTION_X+'px', top:SELECTION_Y+'px',display:'block',
      height:'1px',width:'1px',style:'background-color:red',className:'redbox'
    },[
      Builder.node('img',{src:'/i/blank.gif',height:'1px',width:'1px'})
    ]));
    moveto($(nm), SELECTION_X, SELECTION_Y, 1,1 );

  });
  Event.observe(ensembl_body,'mousemove',select_move, true);
  Event.observe(ensembl_body,'mouseup',  select_stop, true);
  Event.observe(ensembl_body,'click',    select_click,true);
  Event.stop(evt);
}

function seq_region() { return 'x'; }

function select_move( evt ) {
  var enx = Event.pointerX(evt) - drag_offset_x - fudge_x;
  var eny = Event.pointerY(evt) - drag_offset_y - fudge_y;
  var bps = 99; // p2b( dragging_id, enx );
  dragging_image.title = seq_region()+': '+bps;
  var el = $( 'other_l' );
  if( el && el.getHeight() + el.getWidth() > 0 ) { /* this is our current rubber band */
    br_x = dragging_image.getWidth()  -1;
    br_y = dragging_image.getHeight() -1;
    if(enx<0) enx = 0;
    if(eny<0) eny = 0;
    if(enx>br_x) enx = br_x;
    if(eny>br_y) eny = br_y;
    W = enx-SELECTION_X;
    H = eny-SELECTION_Y;
    moveto(el,           SELECTION_X,           SELECTION_Y+(H>0?0:1), 1,            H+(H>0?1:-1) );
    moveto($('other_t'), SELECTION_X+(W>0?0:1), SELECTION_Y,           W+(W>0?1:-1), 1            );
    moveto($('other_r'), enx,                   SELECTION_Y+(H>0?0:1), 1,            H+(H>0?1:-1) );
    moveto($('other_b'), SELECTION_X+(W>0?0:1), eny,                   W+(W>0?1:-1), 1            );
  }
  Event.stop(evt);
}

function select_click( evt ) {
  __info( 'click event fired............' );
  Event.stop(evt);
}

var stored_hrefs   = {};

function select_stop( evt ) {
  Event.stopObserving(ensembl_body,'mousemove', select_move,true);
  Event.stopObserving(ensembl_body,'mouseup'  , select_stop,true);
  Event.stopObserving(ensembl_body,'click',     select_click,true);
  var el = $('other_l');
  var et = $('other_t');
  __status( 'select stop...' );
  if( el && et && el.getHeight() + et.getWidth() > 0 ) {
    var t = el.cumulativeOffset();
    var start_x = t[0];
        t = et.cumulativeOffset();
    var start_y = t[1];
    var end_x   = Event.pointerX(evt);
    var end_y   = Event.pointerY(evt);
        t = dragging_image.cumulativeOffset();
    var tl_x = t[0];
    var tl_y = t[1];
    var br_x = tl_x + dragging_image.getWidth() - 1;
    var br_y = tl_y + dragging_image.getHeight()  - 1;
    if( end_x < tl_x ) { end_x = tl_x; }
    if( end_y < tl_y ) { end_y = tl_y; }
    if( end_x > br_x ) { end_x = br_x; }
    if( end_y > br_y ) { end_y = br_y; }
    W = end_x-start_x - fudge_x;
    H = end_y-start_y - fudge_y;
    __info( W+'...'+H );
    if( W*W+H*H > N*N-1) { // This is a region select....
      lines.each(function(n){
        if( $('real_'+n) ) { $('real_'+n).remove(); }
        $( 'other_'+n ).setAttribute('id', 'real_'+n);
      });
      _show_zmenu_range( { x: end_x, y: end_y } );
    } else {
      var image_map = $(dragging_image.id+'_map');
      if( image_map && !(evt.altKey) ) {
        __info( 'image_map...' );
        var flag = 1;
        var X = end_x-tl_x - fudge_x;
        var Y = end_y-tl_y - fudge_y;
        __info( end_x+' ......... '+end_y+' === '+X+','+Y );
        $A(image_map.areas).each(function(Ax){
          var KEY = dragging_image.id+':'+Ax.shape+':'+Ax.coords;
          if(Ax.href) {
            stored_hrefs[KEY] = Ax.href;
            Ax.removeAttribute('href');
          }
          var link = stored_hrefs[KEY];
          if( link ) {
            pts = Ax.coords.split(/\D+/);
            if( Ax.shape=='poly'   ? in_poly(   pts, X, Y ) : (
                Ax.shape=='circle' ? in_circle( pts, X, Y ) :
                                      in_rect(   pts, X, Y ) ) ) {
              __status( link );
              _show_zmenu( { x: end_x, y: end_y, key: KEY, h: link, title: Ax.title } );
              flag = 0;
            }
          }
        });
        if(flag) {
          _show_zmenu_location( { x: end_x, y: end_y } );
          __info( 'clicked on gap' );
          __status( "try again..." );
        }
      }
    }
  }
  Event.stop(evt);
  return false;
}

function in_circle( pts, pt_x, pt_y ) {
  return (pt_x-pts[0])*(pt_x-pts[0]) + (pt_y-pts[1])*(pt_y-pts[1]) <= pts[2]*pts[2];
}

function in_rect( pts, pt_x, pt_y ) {
  return pt_x >= pts[0] && pt_y >= pts[1] && pt_x <= pts[2] && pt_y<= pts[3];
}

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

function __drag_select_init() {
//  $$('.drag_select').each(function(n){ n.onmousedown = select_start; });
  $$('.drag_select').each(function(n){ Event.observe(n,'mousedown', select_start); });

}

addLoadEvent(__drag_select_init);

