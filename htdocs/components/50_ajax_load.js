/** clever ajax loader **/
var comp_id=0;
var counter = 0;

function __ensembl_init_ajax_loader() {
$$('.ajax').each(function(panel) {
  if(panel.hasClassName('ajax')) {
    panel.removeClassName('ajax'); // We only need to auto load this code once
    if( ENSEMBL_AJAX != 'enabled' ) {
      panel.appendChild( Builder.node('p',{className:'ajax_error'},'AJAX is disabled in this browser' ) );
      return;
    }
    var tmp = eval(panel.title);
    if(!tmp) return;
    panel.setAttribute('title','');
    var p_node;
    if( tmp[0].substr(0,1) != '/' ) {
      var caption=tmp.shift();
      panel.appendChild(Builder.node('h4',caption));
      p_node = Builder.node('div',{className:'content'});
      panel.appendChild(p_node);
    } else {
      p_node = panel;
    }
    tmp.each(function(component) {
      if( component.substr(0,1) == '/' ) {
        var __key = counter++;
	_debug_start_time( __key );
	var node_type;
        switch( p_node.nodeName ) {
	  case 'DL' : node_type = 'dt'; break;
	  case 'UL' : 
	  case 'OL' : node_type = 'li'; break;
	  default:    node_type = 'p';
	}
        var t_node = Builder.node( node_type, {className:'spinner'}, 'Loading component');
        p_node.appendChild(t_node);
        if( component.match(/\?/) ) {
// Remove the old time stamp and replace with a new one! 
          component = component.replace(/\&/g,';').replace(/#.*$/g,'').replace(/\?time=[^;]+;?/g,'\?').replace(/;time=[^;]+;?/g,';').replace(/[\?;]$/g,'');
          var d = new Date();
          component += ( component.match(/\?/)?';':'?' )+'time='+( d.getTime()+d.getMilliseconds()/1000 )
        }
        new Ajax.Request( component, {
	  method: 'get',
          requestHeaders: { Cookie: document.cookie },
          onSuccess: function(resp){
	    $(t_node).replace(resp.responseText);
            __debug_raw( 'Loaded ('+_debug_end_time(__key)+'s) <a href="'+component+'">'+component+'</a>', 'success' );
	    var t = new Date();
	    window.onload();
	    __info( 'Window onload events took '+_time_diff(t)+' seconds' );
          },
          onFailure: function(transport){
            t_node.parentNode.replaceChild(Builder.node('p',
              {className:'ajax_error'},
              'Failure: the resource "'+component+'" failed to load'
            ),t_node);
            __debug_raw( 'Failed to load ('+_debug_end_time(__key)+'s) <a href="'+component+'">'+component+'</a>', 'error' );
          }
        });
      }
    });
  }
});
}

addLoadEvent( __ensembl_init_ajax_loader );
