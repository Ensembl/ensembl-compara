/*========================================================================
 Zmenu code
 initial rendering and hiding of zmenus...
  hide_zmenu( {zmenu name} )
  show_zmenu( {caption}, {event_x}, {event_y}, {array menu_items}[, {zmn}] )
========================================================================*/

function hide_zmenu( zmn ) {hide(ego( zmn ));}

function show_zmenu( caption, e_x, e_y, menu_items, zmn ) {
  ZM = ego('zmenus');
  if( zmn ) {
    child=ego(zmn);
    if(child) { show(child);m2(child,e_x,e_y); return }
  } else {
    zmn = 'zmenu';
    child = ego(zmn);
    if(child) { ZM.removeChild(child) } 
  }

  nz = dce( 'div' );
  sa( nz, 'id', zmn );
  ac( ZM, nz );
  nz.className = 'zmenu';
  t = dce( 'table' );
  t.style.backgroundColor = '#ffffff'
  t.style.borderCollapse  = 'collapse';
  t.style.borderWidth     = '0px';
  t.style.width           = '200px';
  t_h=dce('thead');t_r=dce('tr');
  t_h1=dce('th');t_h2=dce('th');t_h3=dce('th');
  t_h1.onmousedown = drag_start;
  t_h1.style.width = '170px';
  t_h2.style.width = '15px';
  t_h3.style.width = '15px';
  ac( t_h1, dtn( caption ) );cl = dce( 'a' );var mn = dce( 'a' );
  mn.onclick = function() {
    var N = this.parentNode.parentNode.parentNode.parentNode.getElementsByTagName('tbody')[0];
    var I = this.getElementsByTagName('img')[0];
    if(N.style.display=='none') {
      N.style.display=''
      I.src = '/img/dd_menus/up.gif';
    } else { 
      N.style.display='none'
      I.src = '/img/dd_menus/down.gif';
    }
  }
  sa( cl, 'href', 'javascript:void(hide_zmenu("'+ zmn +'"))' );
  im2 = dce( 'img' );
  im2.style.borderWidth = 0;
  im2.height = 12
  im2.width  = 12
  im2.src = '/img/dd_menus/up.gif';
  im2.className = 'right';

  im = dce( 'img' );
  im.style.borderWidth = 0;
  im.height = 12
  im.width  = 12
  im.src = '/img/dd_menus/close.gif';
  im.className = 'right';

  sa( im, 'alt',   'X' );
  sa( im, 'title', 'Close zmenu' );
  
  sa( im2, 'alt', 'v' );
  sa( im2, 'title', 'Min zmenu' );
  ac(mn,im2);
  ac(cl,im);
  ac(t_h2,mn);
  ac(t_h3,cl);
  ac(t_r,t_h1);
  ac(t_r,t_h2);
  ac(t_r,t_h3);
  ac(t_h,t_r);
  ac(t,t_h);
  t_b=dce('tbody');
  ac(t,t_b);ac(nz,t);show(nz);
  for(i=0;i<menu_items.length;i++) {
    it=menu_items[i]
    caption=it[0];href=it[1];target=it[2]
    ro = dce('tr');
    t_b.appendChild(ro);
    ce = dce('td');
    ce.colSpan = 3;
    ro.appendChild(ce);
    
    if (caption.match(/^NOTES/)) {
       parseHTML(ce, caption);
    } else {

    o=dtn(caption);
    temp = href ? href.split(':') : new Array('','');
    if( temp[0] == 'pfetch' ) {
      o=dce('span');
      sa(o,'id','pfetch_'+zmn);
      ac(o,dtn('Pfetching...'));
      pfetch( 'pfetch_'+zmn, temp[1] );
    } else if( href ) {
      to=dce('a');ac(to,o);o=to;sa(o,'href',href)
        if(target) sa(o,'rel','external');
	if (caption.match(/DAS LINK:/)) sa(o,'target','external');
    }
    
    ac(ce,o);
    }
  }
  
  m2(nz, e_x, e_y )
}

function executeReturn( AJAX ) {
  if( AJAX.readyState == 4 ) {
    if( AJAX.status == 200 ) {
      eval(AJAX.responseText);
    }
  }
}

var _ms_XMLHttpRequest_ActiveX = "";

function AJAXRequest( method, url, data, process, extra, async, dosend) {
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
  if( extra == null ) {
    self.AJAX.onreadystatechange = function( ) {
      self.process( self.AJAX );
    }
  } else {
    self.AJAX.onreadystatechange = function( ) {
      self.process( self.AJAX, extra );
    }
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

function pfetch( key, ID ) {
  // Instantiate an object
  // Test to see if XMLHttpRequest is a defined object type for the user's browser
  // If not, assume we're running IE and attempty to instantiate the MS XMLHTtp object
  // Don't be confused by the ActiveXObject indicator. Use of this code will not trigger
  // a security alert since the ActiveXObject is baked into IE and you aren't downloading it
  // into the IE runtime engine
  URL = "/Homo_sapiens/ajax-pfetch";
  fastaAJAX = new AJAXRequest( 'GET', URL+'?ID='+encode(ID), '', changePFETCH, key );
}

function changePFETCH( myAJAX, key ) {
  if( myAJAX.readyState == 4 ) {
    if( document.getElementById( key ) ) {
      document.getElementById( key ).innerHTML = myAJAX.responseText
    }
  }
}

function encode( uri ) {
 if( encodeURIComponent ) return encodeURIComponent(uri);
 if( escape             ) return escape(uri);
}

function extractAttributes (el, content) {
  var pAttrs = /(\w+)=\"?([^\"\n]*)\"?/g;
  var pAttr = /(\w+)=\"?([^\"\n]*)\"?/;

  var aList = content.match(pAttrs);

  if (aList != null) {
    for (var i=0; i < aList.length; i++) {
      var attr = aList[i].match(pAttr);
        if (attr != null) {
	  sa(el, attr[1], attr[2]);
	}
    }
  }
}

function parseHTML (el, content) {
  var pTags = /<(a)\s+([^\>\n]*)\s*\>(.*)<\s*\/a\s*>|<(img)\s+([^\>\n]*)\s*\/?>|<(br)\s*\/?>/i;

  var tag;
  while ( (tag = content.match(pTags)) != null) {
     var txt = RegExp.leftContext;
     content = RegExp.rightContext;
     ac(el, dtn(txt));
     var tag_name = tag[1] || tag[4] || tag[6];
     var tag_attributes = tag[2] || tag[5];
     var tag_text = tag[3]; // Can contain other tags

     var cel = dce(tag_name);
     if (tag_attributes != null) {
       extractAttributes(cel, tag_attributes);
     }

     if (tag_name == 'a' || tag_name == 'A') {
        sa(cel, 'target', 'external');
     }

     if (tag_text != null) {
       parseHTML(cel, tag_text);
     }
     ac(el, cel);
  }
  ac(el, dtn(content));
}
