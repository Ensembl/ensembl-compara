// THIS FILE SHOULD BE DYNAMICALLY RE-WRITTEN from -tmpl 
// Z-tooltip version 2
// rmp@psyphi.net May 2000

NS6 = (!document.all && document.getElementById)? 1:0;
NS4 = (document.layers) ? 1:0;
IE4 = (document.all) ? 1:0;

//if(NS4) {
//alert("you appear to be using netscape 4");
//}
//if(NS6) {
//alert("you appear to be using netscape 6");
//}
//if(IE4) {
//alert("you appear to be using IE4 or similar");
//}

var divname = "jstooldiv";
var x = 0;
var y = 0;
var window_width    = 800;
var timeoutId = 0;
var Z_MENU_XOFFSET    = 2;
var Z_MENU_YOFFSET    = 2;
var Z_MENU_CAPTIONBG    = "#e2e2ff";
var Z_MENU_CAPTIONFG    = "#000000";
var Z_MENU_TIPBG    = "#f5f5ff";
var Z_MENU_BORDERBG    = "#aaaaaa";
var Z_MENU        = true;
var Z_MENU_WIDTH    = 200;

var Z_MENU_TIMEIN     = 500;
var Z_MENU_TIMEOUT    = 6000;

SPECIES = Array();
SPECIES['gg'] = 'Gallus_gallus';
SPECIES['hs'] = 'Homo_sapiens';
SPECIES['mm'] = 'Mus_musculus';

if(NS4 || IE4 || NS6) {
  document.onmousemove = mouseMove;

  if(NS4 || NS6) {
    document.captureEvents(Event.MOUSEMOVE);
    window_width = window.innerWidth;
  }
}

function mouseMove(e) {
  if(NS4) {
    x = e.pageX +Z_MENU_XOFFSET;
    y = e.pageY +Z_MENU_YOFFSET;
  } else if(IE4) {
    x = event.x +Z_MENU_XOFFSET + document.documentElement.scrollLeft + document.body.scrollLeft;
    y = event.y +Z_MENU_YOFFSET + document.documentElement.scrollTop  + document.body.scrollTop;
  } else if(NS6) {
    x = e.clientX +Z_MENU_XOFFSET + window.pageXOffset - document.body.scrollLeft;
    y = e.clientY +Z_MENU_YOFFSET + window.pageYOffset - document.body.scrollTop; 
  }
}

// javascript repeat zmenu renderer...
//   e.g. void( zr('hs;X;2156692;306;AluSg') );
function zr(X) {
  Q = X.split(';',5); // 0:species 1:seq_region 2:start; 3:length; 4:label
  return zmenu( Q[4],'','bp: '+Q[2]+'-'+(Q[2]+Q[3]-1),'','Length: '+Q[3]+'bps', 'Centre on repeat', CV_link( Q[0], Q[1], Q[2]+Q[3]/2 ) );
}


// javascript zmenu renderer for generic features (zf)
// Unigene clusters  (zu)    Protein homologies   (zp)
// ESTs              (ze)    DNA alignements      (zd)
//   e.g. void( zp('hs;X;2156692;306;UNIGENE;Os.35391') );

function zu( X ) { return zf( 'Unigene cluster ', X ); }
function zp( X ) { return zf( 'Protein homology ', X ); }
function ze( X ) { return zf( 'EST ', X ); }
function zd( X ) { return zf( '', X ); }

function zf( Y, X ) {
  Q = X.split(';',6); // 0:species 1:seq_region 2:start; 3:length; 4:DB; 5:ID
  return zmenu( Q[5],
    '/'+Q[0]+'/r?d='+Q[4]+'&ID='+Q[5], Y=='' ? ( Q[4]+': '+Q[5] ) : ( Y+ ' '+ Q[5] ),
    '', 'bp: '+Q[2]+'-'+(Q[2]+Q[3]-1),
    '','Length: '+Q[3]+'bps',
    'Centre on feature', CV_link( Q[0], Q[1], Q[2]+Q[3]/2 ),
    'Centre on start of feature', CV_link( Q[0], Q[1], Q[2] ),
    'Centre on end of feature', CV_link( Q[0], Q[1], Q[2]+Q[3] )
  );
}

// javascript renderer for compara aligments
//   e.g. void( za('hs;X;2156692;100000;mm;X;2151414;120020;-1;TRANSLATED_BLAT') );

function za( X ) {
  Q = X.split(';',10); // 0:type 1:species_1 2:seq_region_1 3:start_1 4:length_1
                       // 5:species_2 6:seq_region_2 7:start_2 8:length_2 9:orientation_2
  sp1  = Q[1];
  loc1 = ''+Q[2]+':'+Q[3]+'-'+(1*Q[3]+Q[4]-1);
  cp1  = ''+Q[2]+':'+Math.floor(1*Q[3]+Q[4]/2-1/2);
  sp2  = Q[5]
  loc2 = ''+Q[6]+':'+Q[7]+'-'+(1*Q[7]+Q[8]-1);
  cp2  = ''+Q[6]+':'+Math.floor(1*Q[7]+Q[8]/2-1/2);
  return zmenu(
    'Location: '+loc1,
    '/'+sp1+'/alignview?class=da&l='+loc1+'&s1='+sp2+'&l1='+loc2+'&type='+Q[0], 'Alignment',
    '/'+sp2+'/contigview?l='+loc2, 'Jump to '+SPECIES[sp2]+' ContigView',
    '/'+sp1+'/dotterview?ref='+sp1+':'+cp1+'&hom='+sp2+':'+cp2, 'Dotter',
    '/'+sp1+'/multicontigview?c='+cp1+'&c1='+cp2+':'+Q[8]+'&s1='+sp2+'&w='+(Q[4]?Q[4]:100000)+'&w1='+(Q[8]?Q[8]:100000), 'MultiContigView',
    '', (Q[8]==-1 ? 'Orientation: Reverse' : 'Orientation: forward' )
  );
}

// javascript renderer for compara aligments
//   e.g. void( za('hs;X;2156692;100000;mm;X;2151414;120020;-1;TRANSLATED_BLAT') );

function zs( X ) {
  Q = X.split(';', 13 ); // sp, sreg, st, off, ID, src, cl, status, mapweight, ambig, alleles, type, dbSNP
  DATA = new Array(
     'SNP: '+Q[4],
     '/'+Q[0]+'/snpview?snp='+Q[4]+'&source='+(Q[5] == '' ? 'dbSNP' : Q[5])+'&l='+Q[1]+':'+Q[2], 'SNP properties',
     '', 'bp: '+Q[2]+(Q[3]==0?'':('&nbsp;-&nbsp;'+(Q[2]+Q[3]))), 
     '', 'class: '+Q[6],
     '', 'status: '+Q[7],
     '', 'ambiguity code: '+Q[8],
     '', 'alleles: '+Q[9]
  );
  C = DATA.length;
  if( Q[12] ) { DATA[C] = 'dbSNP: '+Q[12]; DATA[C+1] = '/'+Q[0]+'/r?d=dbSNP&ID='+Q[12]; C+=2; }
  return zmenu( DATA );
}

function zmenu() {
  zmenuoff();

  var txt = "";

  if(arguments.length < 1) { return true; }
  d = (typeof arguments[0] == 'object' ) ? arguments[0] : arguments;
  if( d.length % 2 != 1) { return true; }

  txt += '<div id="zmenu" style="position:relative;top:0;left:0;width:'+Z_MENU_WIDTH+'px">'+
       '<table cellpadding="2" cellspacing="0" style="border:0px; width:'+Z_MENU_WIDTH+'px"><tr><th style="width:'+(Z_MENU_WIDTH-15)+'px">'+
       '&nbsp;'+d[0]+'</th><th style="width:15px">'+
       '<a href="javascript:void(zmenuoff());" onmouseover="window.status=\'\';return true;"><img width="12" height="12" src="/img/dd_menus/close.gif" class="right" alt=""></a></th></tr>';

  for(i = 1; i < d.length; i+=2) {
    link = '<tr><td colspan="2">';
    url  = d[i];
    var temp = new Array();
    temp = url.split(':');
    if( temp[0] == "pfetch") {
      link += '<span id="pfetch">PFETCHING...</span>';
      pfetch( temp[1] );
    } else if(url != "") {
      target = '';
      if(url.substr(0,1)=='@') { url = url.substr(1); target = ' target="_blank"'; }
      link += '<a href="'+url+'"'+target+'>'+d[i+1]+'</a>';
    } else {
      link += '<span>'+d[i+1]+'</span>';
    }
    link += '</td></tr>';
    txt += link;
  }

  txt += '</table>';

  if(x + Z_MENU_WIDTH > window_width) { x -= Z_MENU_WIDTH; }

  if(NS4) {
    l = document.layers[divname];
    l.document.open("text/html");
    l.document.write(txt);
    l.document.close();
    l.document.bgColor  = Z_MENU_TIPBG;
    l.width             = Z_MENU_WIDTH;
    l.left              = x;
    l.top               = y;
  } else if(IE4) {
    l = document.all[divname];
    l.style.backgroundColor  = Z_MENU_TIPBG;
    l.innerHTML              = txt;
    l.style.pixelWidth       = Z_MENU_WIDTH;
    l.style.pixelLeft        = x;
    l.style.pixelTop         = y;
  } else if(NS6) {
    l = document.getElementById(divname);

    rng = document.createRange();
    rng.setStartBefore(l);
    htmlFrag = rng.createContextualFragment(txt);

    while (l.hasChildNodes()) { l.removeChild(l.lastChild); }
    l.appendChild(htmlFrag);
    l.style.border        = 1;
    l.style.border
    l.style.backgroundColor    = Z_MENU_TIPBG;
    l.style.setProperty( 'left', x+'px', 'important' );
    l.style.setProperty( 'top',  y+'px', 'important' );
  }
  window.clearTimeout(timeoutId);
  timeoutId = window.setTimeout('zmenuon_now()', Z_MENU_TIMEIN);
  return true;
}

function hw( species, page, part ) {
  if(page=='populate_fragment') page = 'contigview';
  X=window.open( '/'+species+'/helpview?se=1&kw='+page+'#'+part,'helpview','height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes');
  X.focus()
}

function zz( script, chr, centre, size, zoom, extra, ori, config_number,exsp ) {
  if(script=='populate_fragment') script = 'contigview';
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
  if(script=='populate_fragment') script = 'contigview';
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

function zmenuon_now() {
       if(NS4) { l = document.layers[divname];         l.visibility       = "show";    }
  else if(IE4) { l = document.all[divname];            l.style.visibility = "visible"; }
  else if(NS6) { l = document.getElementById(divname); l.style.visibility = "visible"; }
  window.clearTimeout(timeoutId);
  timeoutId = window.setTimeout('zmenuoff()', Z_MENU_TIMEOUT);
  return true;
}

function zmenuoff() {
       if(NS4) { document.layers[divname].visibility               = "hide";   }
  else if(IE4) { document.all[divname].style.visibility            = "hidden"; }
  else if(NS6) { document.getElementById(divname).style.visibility = "hidden"; }
}

function encode( uri ) {
 if( encodeURIComponent ) return encodeURIComponent(uri);
 if( escape             ) return escape(uri);
}

function decode( uri ) {
  uri = uri.replace(/\+/g, ' ');
  if( decodeURIComponent ) return decodeURIComponent(uri);
  if( unescape           ) return unescape(uri);
  return uri;
}

function executeReturn( AJAX ) {
  if( AJAX.readyState == 4 ) {
    if( AJAX.status == 200 ) {
      eval(AJAX.responseText);
    }
  }
}

var _ms_XMLHttpRequest_ActiveX = "";

function AJAXRequest( method, url, data, process, async, dosend) {
  // self = this; creates a pointer to the current function
  // the pointer will be used to create a "closure". A closure
  // allows a subordinate function to contain an object reference to the
  // calling function. We can't just use "this" because in our anonymous
  // function later, "this" will refer to the object that calls the function
  // during runtime, not the AJAXRequest function that is declaring the function
  // clear as mud, right?
  // Java this ain't

  var self = this;

  // check the dom to see if this is IE or not
  if( window.XMLHttpRequest ) { // Not IE
    self.AJAX = new XMLHttpRequest();
  } else if( window.ActiveXObject ) { // Hello IE! --

    if( _ms_XMLHttpRequest_ActiveX ) { // Instantiate the latest MS ActiveX Objects
      self.AJAX = new ActiveXObject( _ms_XMLHttpRequest_ActiveX );
    } else { // loops through the various versions of XMLHTTP to ensure we're using the latest
      var versions = [ "Msxml2.XMLHTTP.7.0", "Msxml2.XMLHTTP.6.0",
                       "Msxml2.XMLHTTP.5.0", "Msxml2.XMLHTTP.4.0",
                       "MSXML2.XMLHTTP.3.0", "MSXML2.XMLHTTP",
                       "Microsoft.XMLHTTP" ];
      for (var i = 0; i < versions.length ; i++) {
        try { // try to create the object
                          // if it doesn't work, we'll try again
                          // if it does work, we'll save a reference to the proper one to speed up future instantiations
          self.AJAX = new ActiveXObject(versions[i]);
          if( self.AJAX ) {
            _ms_XMLHttpRequest_ActiveX = versions[i];
            break;
          }
        }
        catch (objException) { // trap; try next one
        };
      };
    }
  }

  // if no callback process is specified, then assing a default which executes the code returned by the server
  if (typeof process == 'undefined' || process == null) {
    process = executeReturn;
  }

  self.process = process;

    // create an anonymous function to log state changes
  self.AJAX.onreadystatechange = function( ) {
    self.process(self.AJAX);
  }

  // if no method specified, then default to POST
  if( !method ) { method = "POST"; }
  method = method.toUpperCase();
  if (typeof async == 'undefined' || async == null) { async = true; }
  self.AJAX.open(method, url, async);
  if (method == "POST") {
    self.AJAX.setRequestHeader("Connection", "close");
    self.AJAX.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    self.AJAX.setRequestHeader("Method", "POST " + url + "HTTP/1.1");
  }
  // if dosend is true or undefined, send the request
  // only fails is dosend is false
  // you'd do this to set special request headers
  if ( dosend || typeof dosend == 'undefined' ) {
          self.AJAX.send(data);
  }
  return self.AJAX;
}

function pfetch( ID ) {
  // Instantiate an object
  // Test to see if XMLHttpRequest is a defined object type for the user's browser
  // If not, assume we're running IE and attempty to instantiate the MS XMLHTtp object
  // Don't be confused by the ActiveXObject indicator. Use of this code will not trigger
  // a security alert since the ActiveXObject is baked into IE and you aren't downloading it
  // into the IE runtime engine
  URL = "/Homo_sapiens/ajax-pfetch";
  fastaAJAX = new AJAXRequest( 'GET', URL+'?ID='+encode(ID), '', changePFETCH );
}

function changePFETCH( myAJAX ) {
  if( myAJAX.readyState == 4 ) {
    if( document.getElementById('pfetch') ) {
      document.getElementById('pfetch').innerHTML = myAJAX.responseText
    }
  }
}

