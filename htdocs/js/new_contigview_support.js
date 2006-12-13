/* slice information code */

var CLICK_X;
var CLICK_Y;
var ZMENU_ID;
var MOUSE_UP=0;
var red_box_divs = new Array( 'real_l', 'real_r', 'real_t','real_b', 'other_l','other_r','other_b','other_t' );

function seq_region( ) { return document.forms[ 'panel_form' ].chr.value; }

function p2b( n, px ) { 
  F = document.forms[ 'panel_form' ];
  px_start  = F.elements[n+'_px_start'].value;
  bp_start  = F.elements[n+'_bp_start'].value;
  px_len    = F.elements[n+'_px_end'].value-px_start+1;
  scale     =(F.elements[n+'_bp_end'].value-bp_start+1)/px_len;
  px -= px_start;
  if( px<0 )      { px = 0; }
  if( px>px_len ) { px = px_len; }
  return Math.floor( px*scale + 1.0*bp_start )
}

function b2p( n, bp ) {
  F = document.forms[ 'panel_form' ];
  bp_start  = F.elements[n+'_bp_start'].value;
  px_start  = F.elements[n+'_px_start'].value;
  bp_len    = F.elements[n+'_bp_end'].value-bp_start+1;
  scale     =(F.elements[n+'_px_end'].value-px_start+1)/bp_len;
  bp -= bp_start;
  if( bp<0 )      { px = 0; }
  if( bp>bp_len ) { px = bp_len; }
  return Math.floor( bp*scale + 1.0*px_start )
}

/* panel expansion contraction code */
function _change_panel_state( n ) {
  F = document.forms[ 'panel_form' ];
  if( F.elements[n+'_visible'].value == 1 ) {
    F.elements[n+'_visible'].value = 0
    ego(n).style.display = 'none'
    hide(ego(n+'_rl'));hide(ego(n+'_rr'));hide(ego(n+'_rt'));hide(ego(n+'_rb'));
    egi( n+'_box' ).src = 'box-0.gif';
  } else {
    F.elements[n+'_visible'].value = 1
    ego(n).style.display = 'block'
    egi(n+'_box').src = 'box-0.gif';
  }
}


/* Contigview style specific scripts:
  * cv_init
    initializes the four panels from the information given in the
    "panel_form" form
  * cv_change_panel_state
    changes the panel from open to closed and updates the red boxes
*/

function view_init(n) {
  if( !ego( n+'_rl' ) ) {
    A = ego( n );
    if(A) {
    A.onmousedown = select_start
    for(k=0;k<edges.length;k++) {
      var L = edges.substr(k,1);
      d1=dce('div');
      ac(A,d1);

      sa(d1,'id',n+'_r'+L);
      d1.className = 'redbox';

      var i1=document.createElement('img');
      ac(d1,i1);

      i1.src = '/img/blank.gif';

      i1.width  = 1;
      i1.height  = 1;
      i1.style.borderWidth = 0;
/*
      d2=dce('div');  sa(d2,'id',n+'_'+L);  d2.className = 'redbox';
      ac(d2,i2);      ac(A,d2);
      i2=dce('img');  i2.src = '/img/blank.gif'; i2.width = 1; i2.height  = 1; i2.style.borderWidth = 0;
*/
    }
    }
  }
  alert(n);
}

function contigview_init( id_1, id_2 ) {
  edges = 'rltb';
  F = document.forms[ 'panel_form' ];
/* initialize all the elements - including minimizing panels */
  for(l=id_2;l>=id_1;l--) {
    n='p_'+l;
    view_init(n);
  }
  cv_draw_red_boxes( id_1, id_2 );
  B = ego( 'ensembl-webpage' );
  for(i=0;i<4;i++) {
    var D = dce('div');
    var I = dce('img');
    sa(D,'id',red_box_divs[i]);
    D.className = 'redbox';
    D.style.backgroundColor = 'red';
    sa(I,'src', '/img/blank.gif');
    ac(D,I);
    ac(B,D);
    rs(D,1,1);
    rs(I,1,1);
  }
  var D = dce('div');
  sa(D,'id','zmenus');
  ac(B,D);
}

function cv_change_panel_state( pn, id_1, id_2 ) {
  _change_panel_state( pn );
  cv_draw_red_boxes( id_1, id_2 );
}

function draw_red_box(prefix, panel_id, previous_prefix, previous_id) {
  F = document.forms[ 'panel_form' ];
  name = prefix+'_'+panel_id;
  I = egi(name+'_i');
  X = egX( I ); Y = egY( I ); W = egW( I ); H = egH( I );
  Z = ego( name );
  if( Z ) {
   Z.style.borderColor = 'black';
  }
  if( F.elements[name+'_visible'].value == 1 ) {
    l2 = previous_id;
    fl  = 1 
    while( fl && F.elements[previous_prefix+'_'+l2+'_visible'] ) {
      name2 = previous_prefix+'_'+l2;
      if( F.elements[name2+'_visible'].value == '1' ) {
        ego( name2 ).style.borderColor = 'red';
        sx = b2p( name, F.elements[name2+'_bp_start'].value );
        ex = b2p( name, F.elements[name2+'_bp_end'].value );
        show( ego(name+'_rl') ); 
        show( ego(name+'_rr') );
        show( ego(name+'_rt') );
        show( ego(name+'_rb') );
        m2( ego( name+'_rl') , sx, 2, 1, H-3 );
        m2( ego( name+'_rr') , ex, 2, 1, H-3 );
        m2( ego( name+'_rt') , sx, 2, ex-sx, 1 );
        m2( ego( name+'_rb') , sx, H-2, ex-sx, 1 );
        fl = 0;
      }
      l2++;
    }
  } else {
    ego( name ).style.display = 'none'
    egi( name+'_box' ).src = 'box-0.gif';
  }
  A = ego( name+'_i_map' )
  if( A ) {
    for(i=0;i<A.areas.length;i++) {
      A.areas[i].onmousedown = select_start;
      if( A.areas[i].onclick || A.areas[i].onmouseover ) A.areas[i].href  = "javascript:void(0)" ;
    } 
  }
}

function cv_draw_red_boxes( id_1, id_2 ) {
  for(loop=id_2;loop>=id_1;loop--) {
    draw_red_box('p', loop, 'p', loop+1);
  }
  return true;
}

