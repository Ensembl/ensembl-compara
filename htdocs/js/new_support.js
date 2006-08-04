// General support functionality....

MAC = navigator.userAgent.toLowerCase().indexOf('mac')==-1?0:1;
var LOADED = 0;    // Has the page been loaded
var DIAG   = 0;    // Warn missing objects??
var PRECISION = 3; // precision of click...
var MODE   =  ( !document.all && document.getElementById) ? 'NS6' : 
              ( (document.layers) ? '' : ( (document.all) ? 'IE6' : '' ) );

// General Object wrapper code

// ego(n) = get object... return a reference to the object names "n"
function ego( n ) { obj = null;
  if( document.getElementById ) {
    obj = document.getElementById(n);
  } else {
    switch(MODE) {
     case 'IE6' : obj = document.all[n]; break;
     case 'NS6' : obj = document.getElementById(n);
    }
  }
  if( DIAG && !obj ) { alert( "missing obj: "+ n ); } return obj;}
function egi(n) { return ego(n); }

// gee(e) = get event element
function gee(evt) {
  if(evt.type == 'mouseout' ) {
    switch(MODE) {
      case 'IE6': return evt.fromElement;
      case 'NS6': return evt.relatedTarget;
      default:    return null;
    }
  } else {
    switch(MODE) {
      case 'IE6': return evt.srcElement;
      case 'NS6': return evt.target;
      default:    return null;
    }
  }
}
// gp(o,type) = get first ancestor of "o" of type "type"
function gp( o, type ) {
  if( o.nodeName == type) { return o; } T=o; while( T = T.parentNode ) { if( T.nodeName == type) { return T; } } return(o);
}

// m2(X,l,t,w,h) = move object X to position (l,t) and optionally resize it to w x h
function m2( X,l,t,w,h ) {
  if( w ) {
    if( w<0 ) { l+=w;w=-w; }
    if( h<0 ) { t+=h;h=-h; }
  }
  switch(MODE) {
    case 'IE6': X.style.pixelLeft = l; X.style.pixelTop  = t; break;
    case 'NS6': X.style.setProperty( 'left', l+'px', 'important' );
                X.style.setProperty( 'top',  t+'px',  'important' );
  }
  if( w||h ) { rs( X,w,h ); }
  return( 0 )
}

// rs(X,w,h) = resize X to w x h
function rs( X,w,h ) {switch(MODE) {
  case 'IE6': X.style.pixelHeight = h; X.style.pixelWidth = w; break;
  case 'NS6': X.style.setProperty( 'width',  w+'px',  'important' );
              X.style.setProperty( 'height', h+'px',  'important' );
}}

// get property "wh" of object "i"
function egP(i,wh) {flag=100;ip = 0;switch(MODE) {
  case 'IE6': case 'NS6': while (flag && (i!=null)) { ip+=i["offset"+wh]; i=i.offsetParent; flag--; }
}return( ip );}

function egX( i ) { return egP(i,'Left'); }
function egY( i ) { return egP(i,'Top'); }
function egW( i ) { return i ? parseInt( i.width  ? i.width  : (i.style ? i.style.width : 0 )) : 0; }
function egH( i ) { return i ? parseInt( i.height ? i.height : (i.style ? i.style.height : 0 ) ) : 0; }
function egXr( i ) { return parseInt( i.offsetLeft ); }
function egYr( i ) { return parseInt( i.offsetTop ); }

NNNN = 5;
function egeX(e) {
 switch(MODE) {
  case 'IE6': return event.clientX + (
    document.body.scrollLeft ? document.body.scrollLeft : (
      document.documentElement ? (
        document.documentElement.scrollLeft ? document.documentElement.scrollLeft : 0
      ) : 0 ) - 2
    );  
  case 'NS6': return e.pageX;
}}

function egeY(e) {
  if(NNNN-->0) {
//    alert( e.clientY +'..'+e.pageY+'..'+e.screenY +'..'+ ( (document.body.scrollTop)?document.body.scrollTop:document.documentElement.scrollTop) +'..' + ( window.pageYOffset ) ) - 2;
  }
switch(MODE) {
  case 'IE6': return event.clientY + (document.body.scrollTop?document.body.scrollTop:(document.documentElement?(document.documentElement.scrollTop?document.documentElement.scrollTop:0):0)) - 2;   
  case 'NS6': return e.pageY;
}}
function egeXr(e) {switch(MODE) {
  case 'IE6': return event.x   + document.body.scrollLeft;
  case 'NS6': return e.clientX + window.pageXOffset;
}}

function egeYr(e) {switch(MODE) {
  case 'IE6': return event.y   + document.body.scrollTop;
  case 'NS6': return e.clientY + window.pageYOffset;
}}

function hide(X) {switch(MODE) {
  case 'IE6' : case 'NS6' : X.style.visibility = "hidden";  X.style.zIndex = -10;
}}

function show(X) { if(X.style){switch(MODE) {
  case 'IE6' : case 'NS6' : X.style.visibility = "visible"; X.style.zIndex = 10;
}}}

function iv(X) {switch(MODE) {
  case 'IE6' : case 'NS6' : return X.style.visibility == "visible";
}return false;}



function dce( X ) { return document.createElement(X); }
function dtn( X ) { return document.createTextNode(X); }
function sa( X,n,v ) { X.setAttribute(n,v); }
function ga( X,n ) { return X.getAttribute(n); }
function ac( X,n ) { X.appendChild(n); }

function debug_clear() { var D = document.getElementById('debug'); if(D) { D.innerHTML = '' } }
function debug_print(X) { var D = document.getElementById('debug'); if(D) {
  var D2 = document.createElement('div'); D2.appendChild(document.createTextNode(X));
  D.appendChild(D2);
} }

