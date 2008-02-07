function dd_Item( type, id, name, on ) { this.type = type; this.id = id; this.name = name; this.initial = on; this.on = on; }
function dd_Menu( image, URL, items  ) { this.image = image; this.URL = URL; this.items = items; }
 
dd_NS6 = (!document.all && document.getElementById)? 1:0;
dd_NS4 = (document.layers) ? 1:0;
dd_IE4 = (document.all) ? 1:0;

function i_on( img, src ) {
    document.images[img].src = dd_imagepath+src+"-o.gif";
    return true;
}

function i_off( img, src ) {
    document.images[img].src = dd_imagepath+src+".gif";
    return true;
}

function dd_render_layer( i ) {
  options_array = dd_menus[i].items;
  num_rows      = options_array.length;
  rows          = '';
  extrarow      =
      '<tr><td colspan="2" class="dddiv_button center"><a '+
  'href="javascript:if(dd_hideItem()) { document.forms[\''+(dd_menus[i].URL)+'\'].submit(); } else { void(0); }"><img '+
        'src="'+dd_imagepath+'close_menu.gif" height="8" width="98" /></a></td></tr>';
    for( j=0; j<num_rows; j++) {
      entry = options_array[ j ];
      if( entry.type == 'checkbox' ) {
        rows +=
        '<tr class="bg2"><td class="center"><a href="#" onclick="dd_flip('+ i +','+ j +
  ');"><img id="x_'+ i +'_'+ j + '" src="'+dd_imagepath+'off.gif" border="0" height="'+ dd_checkheight +
        '" width="'+ dd_checkwidth+ '" alt=""></a></td>\n<td class="nowrap ddmain"><a href="#" onclick="dd_flip('+
  i +','+ j +');">'+ entry.name +'</a></td></tr>\n';
      } else {
        rows += '<tr class="bg2"><td class="ddmain"><img src="'+ dd_imagepath +'b.gif" height="'+ dd_checkheight+ '" width="'+
              dd_checkwidth +'" alt=""></td><td class="nowrap ddmain">';
        if( entry.on == '' ) {
    rows += entry.name+ '</td></tr>\n';
        } else {  
    rows += '<a href="'+ entry.on + (entry.id=='' ? '' : ('" target="'+entry.id) )+ '">'+ entry.name+ '</a></td></tr>\n';
        }
      }
    } 
    num_rows+=3;
    table_HTML =    
    '<table width="'+ dd_menuwidth +
      '" cellspacing="0" cellpadding="0" class="ddmenu">\n'
      + rows + extrarow +
      '</table>\n';
    return( table_HTML );
}

function dd_render_all_layers( ) {
   output = '<div class="dddiv" style="width:'+dd_menuwidth+'" id="m_"">&nbsp;</div>';
   for(i=0;i<dd_menus.length;i++) {
      output += '<div class="dddiv" style="width:'+dd_menuwidth+'" id="m_'+i+'">\n'+
          dd_render_layer(i);
      output +='</div>\n';
   }
   return(output);
}

function dd_flip( menu_id, menu_item) {
  dd_menus[menu_id].items[menu_item].on = 1 - dd_menus[menu_id].items[menu_item].on;
  dd_showDetails( menu_id, 1 );
  return( 1 );
}


var dd_iDelay        = 5000 // Delay to hide in milliseconds
var dd_sDisplayTimer = null;
var dd_oLastItem     = null;
var dd_showMenu      = 1;

function dd_showDetails( nDest, flag ) {
  if(dd_showMenu == 0) { return( 0 ) ; }
  if(nDest != -1 ) {
    sDest = "m_"+nDest;
    if( dd_IE4) { 
      i    = document.all["b_"+nDest];
      dest = document.all[sDest]
    } else if( dd_NS4 ) {
      i    = document.images["b_"+nDest];
      dest = document.layers[ sDest ]
    } else if( dd_NS6 ) {
      i    = document.getElementById( "b_"+nDest );
      dest = document.getElementById( sDest );
    } else {
      return( 0 );
    }
    if( flag == 0 && (dd_oLastItem==dest) ) {
      if( dd_hideItem() ) { return( 1 ); }
      dd_oLastItem = null
      dd_nLastItem = -1
      return( 0 );
    }
    if ((dd_oLastItem!=null) && (dd_oLastItem!=dest)) {
      if( dd_hideItem() ) { return( 1 ); }
    }
    if(dest) {
      xx_left = dd_getRealPos(i,"Left");
      xx_top  = dd_getRealPos(i,"Top");
      dd_show( sDest );
      dd_move_to( sDest, xx_left, xx_top + dd_menuheight );
      dd_zIndex( sDest, 100 );
      M = dd_menus[nDest].items;
      for(j=0;j<M.length;j++) {
        if(M[j].type=='checkbox') {
          image_code = 'x_'+nDest+'_'+j;
          document.images[ image_code ].src = dd_imagepath+(M[j].on==1?'on':'off')+'.gif';
        }
      }
    }  
    dd_oLastItem = dest
    dd_nLastItem = nDest
  } else {
    if( dd_oLastItem!=null ) {
      if( dd_hideItem() ) { return( 1 ); }
    }
    dd_oLastItem = null
    dd_nLastItem = -1
  }
  return( 0 );
}

function dd_getRealPos(i,which) {
  iPos = 0;
  if( dd_IE4 || dd_NS6 ) {
    while (i!=null) {
      iPos += i["offset" + which];
      i = i.offsetParent;
    }
  } else if( dd_NS4 ) {
    while(i!=null) {
      iPos += parseInt( which == 'Top' ? i.top ? i.top : i.y : i.left ? i.left : i.x );
      if( i.parentLayer && i.parentLayer.owningElement!=null ) {
        i = i.parentLayer.owningElement;
      } else {
        i = document.body;
      }
    }
  }
  return( iPos );
}

function dd_hideItem() { 
  if (dd_oLastItem) {
    dd_hide( 'm_'+dd_nLastItem );
    dd_zIndex( 'm_'+dd_nLastItem, -100 );
    // Now we will check to see what options have been changed!
    options_list='';
    options_array = dd_menus[dd_nLastItem].items
    for(j=0;j<options_array.length;j++) {
      if(options_array[j].type=='checkbox') {
        if( options_array[j].initial != options_array[j].on ) {
          options_list += '|'+(options_array[j].id)+':'+(options_array[j].on==1 ? 'on' : 'off');
        }
        // dd_hide( 'off_'+dd_nLastItem+'_'+j );
        // dd_hide( 'on_'+dd_nLastItem+'_'+j );
      }
    }
    if(options_list!='') {
      dd_showMenu = 0;
      document.forms[dd_menus[dd_nLastItem].URL].elements[dd_menus[dd_nLastItem].URL].value = options_list;
      dd_oLastItem = null;
      dd_nLastItem = -1;
      return(1);
    }
    dd_oLastItem = null;
  }
  return(0);
}

function dd_zIndex( X, N ) {
  if(dd_NS4) {
    document.layers[ X ].zIndex                 = N;
  } else if(dd_IE4) {
    document.all[ X ].style.zIndex              = N;
  } else if(dd_NS6) {
    document.getElementById( X ).style.setProperty ( 'z-index', N, 'important' );
  }
  return( 0 )
  
}
function dd_show( X ) {
  if(dd_NS4) {
    document.layers[ X ].visibility                 = "show";
  } else if(dd_IE4) {
    document.all[ X ].style.visibility              = "visible";
  } else if(dd_NS6) {
    document.getElementById( X ).style.visibility   = "visible";
  }
  return( 0 )
}

function dd_hide( X ) {
  if(dd_NS4) {
    document.layers[ X ].visibility                 = "hide";
  } else if(dd_IE4) {
    document.all[ X ].style.visibility              = "hidden";
  } else if(dd_NS6) {
    document.getElementById( X ).style.visibility   = "hidden";
  }
  return( 0 )  
}

function dd_move_to( X, left, top ) {
  if(dd_NS4) {
    document.layers[ X ].left                       = left;
    document.layers[ X ].top                        = top;
  } else if(dd_IE4) {
    document.all[ X ].style.pixelLeft               = left;
    document.all[ X ].style.pixelTop                = top;
  } else if(dd_NS6) {
    document.getElementById( X ).style.setProperty( 'left', left+'px', 'important' );
    document.getElementById( X ).style.setProperty( 'top',  top+'px',  'important' );
  }
  return( 0 )
}
