/** clever ajax loader **/
var comp_id=0;
var counter = 0;

function __ensembl_init_ajax_loader() {
  __info( "looping through the loop!!!" );
  $$('.ajax').each(function(panel) {
    panel.identify();
    __info( "panel "+panel.id);
    if(!panel.hasClassName('ajax')) return;
    panel.removeClassName('ajax'); // We only need to auto load this code once
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
        var t_node = Builder.node( node_type, {className:'spinner'},
          'Loading component');
        p_node.appendChild(t_node);
        new Ajax.Request( component, {
	  method: 'get',
          onSuccess: function(transport){
            __info( 'ajax return.... '+p_node.id );
            var x_node = Builder.node('div', {style:'display:none'});
            t_node.parentNode.appendChild(x_node);
            x_node.innerHTML = transport.responseText;
            var l = x_node.childNodes.length;
            for(i=0;i<l;i++) {
            t_node.parentNode.insertBefore(x_node.firstChild,t_node);
            }
	    if(t_node.parentNode.id=='local') {
	      __init_ensembl_web_float_box();
	    }
            t_node.parentNode.removeChild(t_node);
            x_node.parentNode.removeChild(x_node);
            __debug_raw( 'Loaded ('+_debug_end_time(__key)+'s) <a href="'+component+'">'+component+'</a>', 'success' );
            __info( 'recall onload .....'+p_node.id );
	    window.onload()
	    __info( 'onload called .....'+p_node.id );
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
  });
}

addLoadEvent( __ensembl_init_ajax_loader );
