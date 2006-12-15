
function hw( species, page, part ) {
  X=window.open( '/'+species+'/helpview?se=1&kw='+page+'#'+part,'helpview','height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes');
  X.focus()
}

function zz( script, chr, centre, size, zoom, extra, ori, config_number,exsp ) {
  EX1 = ( config_number && config_number > 0 ) ?
           ('?s'+config_number+'='+exsp+'&w'+config_number+'='+size+'&c'+config_number) :
           ('?w='+size+'&c=') ;
  EX1 = script + EX1 + chr + ':' + Math.ceil(centre)+':'+ori + extra
  zmenu('Navigation',
    EX1+"&zoom_width="+Math.ceil(zoom/2),  "Zoom in (x2)",
    EX1+"&zoom_width="+Math.ceil(zoom*1),  "Centre on this scale interval",
    EX1+"&zoom_width="+Math.ceil(zoom*2),  "Zoom out (x0.5)"
  );
}

function zn( script, chr, centre, size, extra, ori, config_number, exsp ) {
  EX1 = ( config_number && config_number > 0 ) ?
        ('?s'+config_number+'='+exsp+'&c'+config_number+'=') :
        ('?c=') ;
  EX1 = script + EX1 + chr + ':' + Math.ceil(centre) + ':' + ori + extra
  EX1 += ( config_number && config_number > 0 ) ? ('&w'+config_number+'=') : '&w=';
  zmenu('Navigation',
    EX1 + Math.floor(size/10), "Zoom in (x10)",
    EX1 + Math.floor(size/5), "Zoom in (x5)",
    EX1 + Math.floor(size/2), "Zoom in (x2)",
    EX1 + Math.floor(size*1), "Centre on this scale interval",
    EX1 + Math.floor(size*2), "Zoom out (x0.5)",
    EX1 + Math.floor(size*5), "Zoom out (x0.2)",
    EX1 + Math.floor(size*10), "Zoom out (x0.1)"
  )
}

function zmenu( event ) {
  if(!MOUSE_UP) { return false; }
  if(arguments.length < 1) { return true; }
  var d = (typeof arguments[0] == 'object' ) ? arguments[0] : arguments;
  if( d.length % 2 != 1) { return true; }

  var caption = d[0]
  var lnks    = new Array((d.length-1)/2);
  for(var i=0;i<d.length-1;i+=2) {
    if(d[i+1].substring(0,1)=='@') {
      lnks[i/2] = new Array( d[i+2], d[i+1].substring(1), '_blank' );
    } else {
      lnks[i/2] = new Array( d[i+2], d[i+1] );
    }
  }
  show_zmenu( caption, CLICK_X, CLICK_Y, lnks, ZMENU_ID  );
  return true;
}
