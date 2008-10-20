/** Code to handle the creation and loading of links into the modal dialog box

    Public functions: modal_dialog_open(); modal_dialog_close();
**/

function getPageScroll() {   
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
  var xS,yS,wW,wH;   
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

var ensembl_modal = { min_width:  800, min_height: 600, padding: 100, min_pad: 10 };

function __modal_page_resize() {
/* This is the prototype version... but it doesn't work in Opera at the moment 
  var Psc       = document.viewport.getScrollOffsets();
  var Psz       = document.viewport.getDimensions();
  var bg_left   = Psc.left;
  var bg_top    = Psc.top;
  var bg_width  = Psz.width;
  var bg_height = Psz.height;
*/
  var Psz       = getPageSize();
  var Psc       = getPageScroll();
  var bg_left   = Psc[0];
  var bg_top    = Psc[1];
  var bg_width  = Psz[2];
  var bg_height = Psz[3];
/* end of alternative section.... */
  
  var modal_width  = bg_width  - ensembl_modal.padding * 2;
  var modal_height = bg_height - ensembl_modal.padding * 2;
  if( modal_width  < ensembl_modal.min_width  ) {
    modal_width    = ensembl_modal.min_width  > bg_width  - 2 * ensembl_modal.min_pad ?
      bg_width  - 2 * ensembl_modal.min_pad : ensembl_modal.min_width;
  }
  if( modal_height < ensembl_modal.min_height ) {
    modal_height   = ensembl_modal.min_height > bg_height - 2 * ensembl_modal.min_pad ?
      bg_height - 2 * ensembl_modal.min_pad : ensembl_modal.min_height;
  }

  var l = bg_left + (bg_width  - modal_width  )/2;
  var t = bg_top  + (bg_height - modal_height )/2;

// Compute the size of the heading bar!! 
  var hh = $('modal_content').cumulativeOffset().top - $('modal_panel').cumulativeOffset().top;


  $('modal_bg').style.left        = bg_left     + "px";
  $('modal_bg').style.top         = bg_top      + "px";
  $('modal_bg').style.height      = bg_height   + "px";
  $('modal_bg').style.width       = bg_width    + "px";

  $('modal_disable').style.left   = bg_left     + "px";
  $('modal_disable').style.top    = bg_top      + "px";
  $('modal_disable').style.height = bg_height   + "px";
  $('modal_disable').style.width  = bg_width    + "px";

  $('modal_panel').style.top      = t            + "px";
  $('modal_panel').style.left     = l            + "px";
  $('modal_panel').style.height   = modal_height + "px";
  $('modal_panel').style.width    = modal_width  + "px";
  $('modal_content').style.height = (modal_height - hh) + 'px';
}

function modal_dialog_open( ) {
/** Open (and resize) the dialog box

    PUBLIC: modal_dialog_open();
**/
  $('modal_bg').show();
  $('modal_panel').show();
  
  __modal_page_resize();
}

function modal_dialog_close() {
/** Close the dialog box

    PUBLIC: modal_dialog_close();
**/
  if($('configuration')) {
    configurator_submit_form( 'close' );
  }
  modal_dialog_close_2();
}

var page_needs_to_be_reloaded = false;

function modal_dialog_close_2() {
  configuration_updated = false;
  $('modal_bg').hide();
  $('modal_panel').hide();
  if( page_needs_to_be_reloaded ) { // If a config has been updated reload the page!
    page_needs_to_uploaded = false;
    var t = window.location.href;
    var d = new Date();
    t = t + ( t.match(/\?/)?';':'?' )+'time='+( d.getTime()+d.getMilliseconds()/1000 );
    window.location.href = t;
  }
}

function __modal_dialog_link_open( event ) {
/**
  Open a dialog box based on the link that was clicked on - instead of opening
  the page in a new browser window; load the contents of the page into the
  modal dialog box instead with AJAX
   
  PRIVATE: Loaded by __modal_onload;
**/
  var el    = Event.findElement( event, 'A' );
  if( el.hasClassName('reset-button')) {
    page_needs_to_be_reloaded = true;
    configuration_updated     = true;
  }
  var title = el.innerHTML.stripTags();
  var url   = el.href;
  if( $('configuration') ) {
    configurator_submit_form( url, title ); //If this returns true it indicates a successful problem and returns true!
  } else {
    __modal_dialog_link_open_2( url, title );
  }
  Event.stop(event);
}

function __modal_dialog_link_open_2( url, title ) {
  if( url == 'close' ) {
    modal_dialog_close_2();
    return;
  }
  if( ENSEMBL_AJAX != 'enabled' ) {
    window.open(url,'control_panel','width=950,height=500,resizable,scrollbars');
  } else { 
    __success( 'modal dialog open '+title+':'+url );

  // Set the title and place holder content...
    $('modal_caption' ).update( title );
    $('modal_content' ).update(Builder.node('div',
      {className:'spinner'}, 'Loading content')
    );

    modal_dialog_open(); // Resize and open the modal dialog box

  // Now make the AJAX request
    new Ajax.Request( url, {
      method: 'get',
      onSuccess: function( transport ) { modal_success(transport) },
      onFailure: function( transport ) {
        $('modal_content').innerHTML = '<p class="ajax-error">Failure: the resource failed to load</p>';
      }
    });
  }
}

function modal_success( transport ) {
  var x = transport.responseText;
  var M = x.split('</div>');
  if( M.length > 1 && M[0].match(/<div id="modal_tabs">/) ) {
    var a = M.shift();
    $('modal_caption').update( a );
    $('modal_caption').setStyle({ paddingBottom: '0px' });
  }
  var b = M.join('</div>');
  $('modal_close').innerHTML = configuration_updated ? 'SAVE and close' : 'Close';
  $('modal_content').update( b );
//  $('modal_content').appendChild(document.createTextNode(b));
// Make the main tab links go back to this window!
  $$('#modal_caption a').each(function(n){n.addClassName('modal_link')});
  $$('#modal_content form').each(function(n){n.onsubmit = modal_form_submit;});
  $$('#modal_content form.upload').each(function(n){
    n.setAttribute('target','uploadframe');
    n.appendChild(Builder.node('div',[Builder.node('input',{type:'hidden',name:'uploadto',value:'iframe'})]));
  });
// Now make the local tree links go back to this window!
  $$('#local_modal a'  ).each(function(n){n.addClassName('modal_link')});
  window.onload();
}

function modal_form_submit( event ) {
  var el = Event.element( event );
  if( el.hasClassName('upload') ) {
    alert( 'iframe' );
  } else {
    new Ajax.Request( el.action, {
      method: el.method,
      parameters: el.serialize(true),
      onSuccess: function( transport ) { modal_success(transport) },
      onFailure: function( transport ) {
        $('modal_content').innerHTML = '<p>Failure: the resource failed to load</p>';
      }
    });
    Event.stop( event );
  }
}

function __modal_onload() { 
  $$('.modal_link').each(function(s) {
    s.observe( 'click',  __modal_dialog_link_open );
    s.removeClassName( 'modal_link' );  // Make sure that this only gets run once per link... we will need to re-run this once AJAX has finished loading!!
  });
  if( ENSEMBL_AJAX!='enabled' || $('modal_bg') ) return;
  $$('body')[0].appendChild(Builder.node( 'div', { id:'modal_disable',style: 'display:none;' + ( Prototype.Browser.IE ? 'filter:alpha(opacity=25)':'opacity:0.25') }));
  $$('body')[0].appendChild(Builder.node( 'div', { id:'modal_bg',     style: 'display:none;' + ( Prototype.Browser.IE ? 'filter:alpha(opacity=25)':'opacity:0.25') }));
  $$('body')[0].appendChild(Builder.node( 'div', { id:'modal_panel',  style: 'display:none' },[
    Builder.node( 'div', { id: 'modal_title' }, [
      Builder.node( 'span', { className: 'modal_but', id: 'modal_close' }, [ 'close' ] ),
      Builder.node( 'div', { id: 'modal_caption' }, [ 'Modal dialog' ] )
    ]),
    Builder.node( 'div', { id: 'modal_content' }, 'Modal content' )
  ]));
  Event.observe( $('modal_close'), 'click', modal_dialog_close );
  window.onresize = __modal_page_resize;
  window.onscroll = __modal_page_resize;
}

addLoadEvent( __modal_onload );

