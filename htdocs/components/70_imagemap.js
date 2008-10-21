// Two support functions which make it easer to move and/or resize
// a div - used by the red box drawing code!

function moveto( el, lt, tp, wd, ht ) {
  if( wd < 0 ) { lt+=wd;wd=-wd;}
  if( ht < 0 ) { tp+=ht;ht=-ht;}
  el.setStyle({ left: lt+'px', top: tp+'px'});
  if(wd||ht) resize( el, wd, ht );
}

function resize(el,wd,ht) {
  el.setStyle({ width: wd+'px', height: ht+'px'});
}

var stored_hrefs    = {};   // We need to remove hrefs to stop them firing so cache them!!
var dragging_object = null; // div containing image currently working on...
var dragging_image  = null; // image currently draggin on
var drag_offset_x   = 0;    // offset of drag start from current div 
var drag_offset_y   = 0;    // offset of drag end   from current div
    // this is used to attach the red box to the div even if the page resizes 
    // (relative to start of the div!)
    // may change this to be image based!!
var drag_size2      = 4;    // What defines a click and a region - click is end < 3 pixels from start
                            // This is actually the square of the value 2^2

/* Fudge factors to map the image co-ordinates to real co-ordinates */
var fudge_x         = Prototype.Browser.IE ? 2 : 1;
var fudge_y         = Prototype.Browser.IE ? 3 : 1;

/**
  the following three drag_start/drag_stop/drag_move functions
  basically deal with the dragging of the zmenus around the screen
  once they have been rendered.
**/

function drag_start( evt ) {
  dragging_object = Event.findElement(evt,'table');
  var x = dragging_object.cumulativeOffset();
  drag_offset_x = Event.pointerX(evt) - x[0];
  drag_offset_y = Event.pointerY(evt) - x[1];
  Event.observe(ensembl_body,'mousemove', drag_move);
  Event.observe(ensembl_body,'mouseup'  , drag_stop);
  Event.observe(ensembl_body,'mousedown', drag_move);
}

function drag_stop( evt ) {
  Event.stopObserving(ensembl_body,'mousemove', drag_move);
  Event.stopObserving(ensembl_body,'mouseup'  , drag_stop);
  Event.stopObserving(ensembl_body,'mousedown', drag_move);
}

function drag_move( evt ) {
  moveto( dragging_object, Event.pointerX(evt) - drag_offset_x, Event.pointerY(evt) - drag_offset_y );
}

/*
  When we select the start we need to know if we are in one of
  the "selectable" regions...  These have a href of
  #drag|slice_number|slice_depth|species|seq_region_name|start|end|strand
*/

var drag_bounds;
var start_x;
var start_y;

function select_start( evt ) {
  if( evt.button == 2 ) { return; }
  dragging_object = Event.findElement( evt, 'div' );
  dragging_image  = Event.findElement( evt, 'img' );
  if( !dragging_image ) {
    dragging_map = Event.findElement( evt, 'map' );
    dragging_image = $( dragging_map.id.substring(0, dragging_map.id.length - 4 ) );
  }
  var x           = dragging_object.cumulativeOffset();
  var y           = dragging_image.cumulativeOffset();
  drag_offset_x   = x[0];
  drag_offset_y   = x[1];
  start_x         = Event.pointerX(evt);
  start_y         = Event.pointerY(evt);
  SELECTION_X     = start_x - x[0] - fudge_x;
  SELECTION_Y     = start_y - x[1] - fudge_y;
  var pX = Event.pointerX(evt) - y[0] -fudge_x;
  var pY = Event.pointerY(evt) - y[1] -fudge_y;
  var map = $(dragging_image.id+'_map');
  $A(map.areas).each(function(Ax){
    var KEY = dragging_image.id+':'+Ax.shape+':'+Ax.coords;
    var link = '';
    if(Ax.href) {
      T = Ax.href.split(/#/);
      stored_hrefs[KEY] = T.length>1 ? '#'+T[1] : Ax.href;
      Ax.removeAttribute('href');
    }
    link = stored_hrefs[KEY];
    drag_bounds = { lnk: '' };
// See if we have a selectable region and it is draggable...
    if( link && link.substring(0,6) == '#drag|' ) {
      pts = Ax.coords.split(/\D+/);
      if( in_rect( pts, pX, pY ) ) { // we have the start of a selectable area....
                                     // so we draw a "red ants" box!
        var s = 'height:1px;width:1px;left:'+SELECTION_X+'px;top:'+SELECTION_Y+'px';
        $R(0,3).each(function(n){
          var nm = 'other_'+n;
          var cl = n > 1 ? 'rubberband2' : 'rubberband';
          if($(nm)){$(nm).remove();}
          dragging_object.appendChild( Builder.node('div',{ id: nm,style:s,className:cl},[
            Builder.node('img',{src:'/i/blank.gif',alt:''})
          ]));
        });
	// Store information about region so the mouse move/mouse up code can use it!
        drag_bounds = { lnk: link, l: parseInt(pts[0]), r: parseInt(pts[2]), t: parseInt(pts[1]), b: parseInt(pts[3]), img: dragging_image.id };
	// Attach the mouse move event!
        Event.observe(ensembl_body,'mousemove',select_move, true);
      }
    }
  });
  Event.observe(ensembl_body,'mouseup',  select_stop, true);
  Event.stop(evt);
}

function select_move( evt ) {
  var enx = Event.pointerX(evt) - drag_offset_x - fudge_x;
  var eny = Event.pointerY(evt) - drag_offset_y - fudge_y;
  // Compute new location of end of box and re-draw!!
  if(enx<drag_bounds.l) enx = drag_bounds.l;
  if(eny<drag_bounds.t) eny = drag_bounds.t;
  if(enx>drag_bounds.r) enx = drag_bounds.r;
  if(eny>drag_bounds.b) eny = drag_bounds.b;
  W = enx-SELECTION_X;
  H = eny-SELECTION_Y;
  if($('other_0')) {
    moveto($('other_0'), SELECTION_X+(W>0?0:1), SELECTION_Y,           W+(W>0?1:-1), 1            );
    moveto($('other_1'), enx,                   SELECTION_Y+(H>0?0:1), 1,            H+(H>0?1:-1) );
    moveto($('other_2'), SELECTION_X+(W>0?0:1), eny,                   W+(W>0?1:-1), 1            );
    moveto($('other_3'), SELECTION_X,           SELECTION_Y+(H>0?0:1), 1,            H+(H>0?1:-1) );
  }
  Event.stop(evt);
}


function select_stop( evt ) {
  Event.stopObserving(ensembl_body,'mousemove', select_move,true);
  Event.stopObserving(ensembl_body,'mouseup'  , select_stop,true);
  var el = $('other_l');
  var et = $('other_t');
  var end_x   = Event.pointerX(evt);
  var end_y   = Event.pointerY(evt);
  var box_end_x = 0;
  var box_end_y = 0;
  t = dragging_image.cumulativeOffset();
  var im_x = t[0];
   var im_y = t[1];
  if( drag_bounds ) {
    var tl_x = t[0] + drag_bounds.l;
    var tl_y = t[1] + drag_bounds.t;
    var br_x = t[0] + drag_bounds.r;
    var br_y = t[1] + drag_bounds.b; 
    box_end_x = end_x < tl_x ? tl_x : ( end_x > br_x ? br_x : end_x );
    box_end_y = end_y < tl_y ? tl_y : ( end_y > br_y ? br_y : end_y );
  }

  var dist2 = (end_x-start_x)*(end_x-start_x) + (end_y-start_y)*(end_y-start_y);
  if( drag_bounds.lnk && dist2 >= drag_size2 ) { // This is a region select....
    $R(0,3).each(function(n){
      if( $('real_'+n) ) { $('real_'+n).remove(); }
      $( 'other_'+n ).setAttribute('id', 'real_'+n);
    });
    var A = drag_bounds.lnk.split(/\|/);
    var _start = parseFloat( A[5] );
    var _scale_factor = ( parseFloat( A[6] ) - parseFloat( A[5] ) + 1 ) / ( drag_bounds.r-drag_bounds.l );
    var s = start_x - tl_x;
    var e = box_end_x - tl_x;
    if( e < s ) { var t = e; e = s; s = t; }
    if( window.location.pathname.match(/\/Location/) ) {
      _show_zmenu_range( { 
        bp_start: Math.floor(s * _scale_factor + _start),
        bp_end:   Math.floor(e * _scale_factor + _start),
        x: end_x, y: end_y
      } );
    } else {
      _show_zmenu_range_other( {
        bp_start: Math.floor(s * _scale_factor + _start),
        bp_end:   Math.floor(e * _scale_factor + _start),
        x: end_x, y: end_y,
	species:    A[3],
	region:     A[4]
      });
    }
  } else {
    var image_map = $(dragging_image.id+'_map');
    if( image_map && !(evt.altKey) ) {
      var flag = 1;
      var X = end_x-im_x - fudge_x;
      var Y = end_y-im_y - fudge_y;
      var drag_href  = '';
      var drag_start = 0;
      var drag_end   = 0;
      $A(image_map.areas).each(function(Ax){
        var KEY = dragging_image.id+':'+Ax.shape+':'+Ax.coords;
        if(Ax.href) {
          T = Ax.href.split(/#/);
          stored_hrefs[KEY] = T.length>1 ? '#'+T[1] : Ax.href;
          Ax.removeAttribute('href');
        }
        var link = stored_hrefs[KEY];
        if( link ) {
          pts = Ax.coords.split(/\D+/);
          if( Ax.shape=='poly'   ? in_poly(   pts, X, Y ) : (
              Ax.shape=='circle' ? in_circle( pts, X, Y ) :
                                  in_rect(   pts, X, Y ) ) ) {
            if( link.substring(0,6)=='#drag|') {
              drag_href  = link;
              drag_start = 1*pts[0];
              drag_end   = 1*pts[2];
            } else {
              _show_zmenu( { x: end_x, y: end_y, key: KEY, h: link, title: Ax.title } );
              flag = 0;
            }
          }
        }
      });
      if( flag==1 && drag_href ){
        A = drag_href.split(/\|/);
        if( window.location.pathname.match(/\/Location/) ) {
          _show_zmenu_location( {
            x: end_x, y: end_y,
            bp: 1*A[5] + (1*A[6]-1*A[5]+1)/(drag_end-drag_start) * (X - drag_start)
          } );
	} else {
          _show_zmenu_location_other( {
            x: end_x, y: end_y,
            bp: 1*A[5] + (1*A[6]-1*A[5]+1)/(drag_end-drag_start) * (X - drag_start)
          } );

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
/*
 Time to get out those Dalek's again - we need to compute the winding number
 of the polygon! this is the number of degrees that a pointer turns
 through to draw all the points in the polygon... if the point is outside the
 polygon then this is 0 / otherwise some multiple of 2 pi
*/
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

var drag_areas = {};
function sortN(a,b){ return a-b; }
function sortNr(a,b){ return b-a; }
function __drag_select_init() {
//  $$('.drag_select').each(function(n){ n.onmousedown = select_start; });
  $$('.drag_select').each(function(n){
    n.getElementsBySelector('img').each(function(i_n){
      if( i_n.hasClassName('munged_image_map') ) return;
      var m = $(i_n.id+'_map');
      if(m) {
        m.descendants().each(function(ma){
          if(ma.href) {
            var T = ma.href.split(/#/);
            if( T[1] && T[1].substring(0,5)=='drag|') {
              var a = T[1].split(/\|/);
              if( ! drag_areas[a[1]] )       drag_areas[a[1]] = {};
              if( ! drag_areas[a[1]][a[2]] ) drag_areas[a[1]][a[2]] = [];
              var b = ma.coords.split(/[, ]+/);
              var flag = 1;
              drag_areas[a[1]][a[2]].each(function(x){ // check for duplicates...
                if( x.img == i_n.id &&
                  x.pixel_start == b[0] && x.pixel_top   == b[1] &&
                  x.pixel_end   == b[2] && x.pixel_bottom== b[3] &&
                  x.species     == a[3] && x.seq_region  == a[4] &&
                  x.bp_start    == a[5] && x.bp_end      == a[6] &&
                  x.strand      == a[7]
                ) flag = 0;
              });
              if( flag) {
                drag_areas[a[1]][a[2]].push( {
                           img: i_n.id,
                  pixel_bottom: b[3], pixel_top: b[1],
                   pixel_start: b[0], pixel_end: b[2],
                       species: a[3], seq_region: a[4],
                      bp_start: a[5], bp_end: a[6],
                        strand: a[7]
                } );
              }
            }
          }
        });
      }
      i_n.addClassName('munged_image_map');
    });
    Event.observe(n,'mousedown',select_start);
  });
/** now lets draw the red boxes... **/
  $H(drag_areas).each(function(slice_pair){
// Remove any current red-boxes so we can start again...
    $$('.redbox').each(function(n){n.remove();});
    var T = $H(slice_pair.value);
    var panel_ids = T.keys();
    panel_ids.sort(sortNr);
    var first_panel = panel_ids.shift();
    if(panel_ids.length > 0 ) {
      panel_ids.each(function(panel){
/* Now we draw the red lines on the two displays....
  first_panel from pixel_start -> pixel_end (pixel_bottom -> pixel_top)
  panel       from "p_start"   -> "p_end"   (pixel_bottom -> pixel_top)

  p_start = first_panel.bp_start - panel.bp_start) */
        slice_pair.value[first_panel].each(function(area_b){
          slice_pair.value[panel].each(function(area_t){
            var img_b = $(area_b.img);
            var img_t = $(area_t.img);
            var div_b = img_b.up('div');
            var div_t = img_t.up('div');
            var off_t = img_t.cumulativeOffset().top - div_t.cumulativeOffset().top;
            var off_b = img_b.cumulativeOffset().top - div_b.cumulativeOffset().top;

            __draw_red_box( div_b,
              area_b.pixel_start, area_b.pixel_end,
              off_b + parseInt( area_b.pixel_top ) , off_b + parseInt( area_b.pixel_bottom ),
              'redbox'
            );
            var bp_w_t = area_t.bp_end-area_t.bp_start+1;
            var sf     = bp_w_t ? (area_t.pixel_end-area_t.pixel_start)/bp_w_t : 1;
            var pixel_start = (area_b.bp_start-area_t.bp_start) * sf + parseInt( area_t.pixel_start );
            var pixel_end   = (area_b.bp_end  -area_t.bp_start) * sf + parseInt( area_t.pixel_start );
            __draw_red_box( div_t,
              pixel_start,pixel_end,
              off_t + parseInt( area_t.pixel_top    )+2,
	      off_t + parseInt( area_t.pixel_bottom )-2,
              'redbox2'
            );
          });
        });
        first_panel = panel;
      });
    } else if( first_panel && $('tab_location').hasClassName('active') ) {
      __info( 'got here....' );
      slice_pair.value[first_panel].each(function(area_t){
        var img_t = $(area_t.img);
        var div_t = img_t.up('div');
        var off_t = img_t.cumulativeOffset().top - div_t.cumulativeOffset().top;
        var bp_w_t = area_t.bp_end-area_t.bp_start+1;
        var sf     = bp_w_t ? (area_t.pixel_end-area_t.pixel_start)/bp_w_t : 1;
        var pixel_start = (__seq_region.start-area_t.bp_start) * sf + parseInt( area_t.pixel_start );
        var pixel_end   = (__seq_region.end  -area_t.bp_start) * sf + parseInt( area_t.pixel_start );
        __draw_red_box( div_t,
          pixel_start,pixel_end,
          off_t + parseInt( area_t.pixel_top    )+2,
          off_t + parseInt( area_t.pixel_bottom )-2,
          'redbox2'
        );
      });
    }
  });
}

function __draw_red_box( d, l, r, t, b, c ) { 
  var w = r-l+1;
  var h = b-t+1;
  var s1 = 'left:'+l+'px;width:1px;top:'+t+'px;height:'+h+'px';
  var s2 = 'left:'+r+'px;width:1px;top:'+t+'px;height:'+h+'px';
  var s3 = 'left:'+l+'px;width:'+w+'px;top:'+t+'px;height:1px';
  var s4 = 'left:'+l+'px;width:'+w+'px;top:'+b+'px;height:1px';
  d.appendChild(Builder.node('div',{className:c,style:s1},[Builder.node('img',{'src':'/i/blank.gif',alt:''})]));
  d.appendChild(Builder.node('div',{className:c,style:s2},[Builder.node('img',{'src':'/i/blank.gif',alt:''})]));
  d.appendChild(Builder.node('div',{className:c,style:s3},[Builder.node('img',{'src':'/i/blank.gif',alt:''})]));
  d.appendChild(Builder.node('div',{className:c,style:s4},[Builder.node('img',{'src':'/i/blank.gif',alt:''})]));
}

addLoadEvent(__drag_select_init);

var __seq_region;

function __get_location_info() {
  if(!$('tab_location')) return;
  var T = $('tab_location').firstDescendant().innerHTML;
  T = T.replace(/,/g,'');
  var M = T.match(/^Location: (.+):(\d+)-(\d+)$/);
  if( M ) {
    __seq_region = { name:  M[1], start: parseInt(M[2]), end: parseInt(M[3]) };
    __seq_region.width = __seq_region.end-__seq_region.start+1;
  }
}

addLoadEvent(__get_location_info);


function __resize_nav() {
  $$('.navbar').each(function(n){
    n.setStyle({width:ENSEMBL_WIDTH+'px'});
  });
}

addLoadEvent(__resize_nav);
