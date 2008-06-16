/** Code to handle the creation and loading of links into the modal dialog box

    Public functions: modal_dialog_open(); modal_dialog_close();
**/
var min_modal_width  = 800;
var min_modal_height = 600;
var modal_pad        = 100;
var min_pad          =  10;
// Support functions nicked from light box!

function getPageScroll(){
  var xS,yS;
  if (self.pageYOffset) {
    yS = self.pageYOffset;
    xS = self.pageXOffset;
  } else if (document.documentElement && document.documentElement.scrollTop){   // Explorer 6 Strict
    yS = document.documentElement.scrollTop;
    xS = document.documentElement.scrollLeft;
  } else if (document.body) {// all other Explorers
    yS = document.body.scrollTop;
    xS = document.body.scrollLeft;
  }
  aPS = new Array(xS,yS);
  return aPS;
}

function getPageSize() {
  var xS,yS,wW, wH;
  if(window.innerHeight && window.scrollMaxY) {
    xS = window.innerWidth + window.scrollMaxX;
    yS = window.innerHeight + window.scrollMaxY;
  } else if (document.body.scrollHeight > document.body.offsetHeight){ // all but Explorer Mac
    xS = document.body.scrollWidth;
    yS = document.body.scrollHeight;
  } else { // Explorer Mac...would also work in Explorer 6 Strict, Mozilla and Safari
    xS = document.body.offsetWidth;
    yS = document.body.offsetHeight;
  }
  if(self.innerHeight) {  // all except Explorer
    wW = document.documentElement.clientWidth ? document.documentElement.clientWidth :self.innerWidth;
    wH = self.innerHeight;
  } else if (document.documentElement && document.documentElement.clientHeight) { // Explorer 6 Strict Mode
    wW = document.documentElement.clientWidth;
    wH = document.documentElement.clientHeight;
  } else if (document.body) { // other Explorers
    wW = document.body.clientWidth;
    wH = document.body.clientHeight;
  }
  aPS = new Array( xS<wW?xS:wW, yS<wH?wH:yS,wW,wH);
  return aPS;
}


function __modal_page_resize() {
  var Psz = getPageSize();
  var Psc = getPageScroll();

  var modal_width  = Psz[2] - modal_pad * 2;
  var modal_height = Psz[3] - modal_pad * 2;
  if( modal_width  < min_modal_width  ) { modal_width  = min_modal_width  > Psz[2] - 2 * min_pad ? Psz[2] - 2 * min_pad : min_modal_width;  }
  if( modal_height < min_modal_height ) { modal_height = min_modal_height > Psz[3] - 2 * min_pad ? Psz[3] - 2 * min_pad : min_modal_height; }

  var l = Psc[0]+(Psz[2]-modal_width)/2;
  var t = Psc[1]+(Psz[3]-modal_height)/2;

  $('modal_bg').style.width   = Psz[0] + "px";
  $('modal_bg').style.height  = Psz[1] + "px";
  $('modal_panel').style.top  = t      + "px";
  $('modal_panel').style.left = l      + "px";
  $('modal_panel').style.height = modal_height + "px";
  $('modal_panel').style.width  = modal_width  + "px";
}

function modal_dialog_open( ) {
/** Open (and resize) the dialog box

    PUBLIC: modal_dialog_open();
**/
  __modal_page_resize();
  $('modal_bg').style.display    = 'block';
  $('modal_panel').style.display = 'block';
}

function modal_dialog_close() {
/** Close the dialog box

    PUBLIC: modal_dialog_close();
**/
  $('modal_bg').style.display    = 'none';
  $('modal_panel').style.display = 'none';
}

function __modal_dialog_link_open( event ) {
/**
  Open a dialog box based on the link that was clicked on - instead of opening
  the page in a new browser window; load the contents of the page into the
  modal dialog box instead with AJAX
   
  PRIVATE: Loaded by __modal_onload;
**/
  var el    = Event.element( event );
  var title = el.innerHTML.stripTags();
  var url   = el.href;
  __success( 'modal dialog open '+title+':'+url );

  // Set the title and place holder content...
  $('modal_title'  ).replaceChild(document.createTextNode(title),$('modal_title').lastChild);
  $('modal_content' ).innerHTML = '<p>Loading content.....</p>';

  modal_dialog_open(); // Resize and open the modal dialog box

  // Now make the AJAX request
  new Ajax.Request( url, {
    method: 'get',
    onSuccess: function(transport){
      $('modal_content').innerHTML = transport.responseText;
      var x = 0;
      var firstnode = -1;
      __info( "first_node" );
      while( x < $('modal_content').childNodes.length && firstnode < 0) {
        __debug( x );
        if( $('modal_content').childNodes[x].nodeType == 1 ) firstnode =x;
        x++;
      }
      if( firstnode >= 0 ) {
        var node_title = $('modal_content').childNodes[firstnode].innerHTML.stripTags();
        var text_node  = document.createTextNode( node_title );
        $('modal_title').replaceChild( text_node, $('modal_title').firstChild.nextSibling );
      $('modal_content').removeChild( $('modal_content').childNodes[firstnode] );
      }
      window.onload()
    },
    onFailure: function(transport){
      $('modal_content').innerHTML = '<p>Failure: the resource failed to load</p>';
    }
  });

  Event.stop( event );
}

function __modal_onload() { 
  $$('.modal_link').each(function(s) {
    s.observe( 'click',  __modal_dialog_link_open );
    s.removeClassName( 'modal_link' );  // Make sure that this only gets run once per link... we will need to re-run this once AJAX has finished loading!!
  });
  if($('modal_bg')) return;
  $$('body')[0].appendChild(Builder.node( 'div', { id:'modal_bg',    style: 'display:none' }));
  $$('body')[0].appendChild(Builder.node( 'div', { id:'modal_panel', style: 'display:none' },[
    Builder.node( 'h3', { id: 'modal_title' }, [
      Builder.node( 'span', { className: 'modal_but', id: 'modal_close' }, [ 'close' ] ),
      'Modal dialog'
    ]),
    Builder.node( 'div', { id: 'modal_content' }, 'Modal content' )
  ]));
  $('modal_close').onclick = modal_dialog_close;
  window.onresize = __modal_page_resize;
  window.onscroll = __modal_page_resize;
}

Event.observe(window, 'load', __modal_onload );

