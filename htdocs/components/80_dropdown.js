/**------------------------------------------------------------------------
| Initialize the display of the float box...                              |
------------------------------------------------------------------------**/

  var __ensembl_web_current_ddmenu_node;
  
  function __activate_menu(evt) {
    el = Event.element(evt);
    if( ! el.id ) el = el.up('dt');
    var name = el.id.substr(7);
    var menu_node = $('menu_'+name );
    if( name == __ensembl_web_current_ddmenu_node ) {
      __ensembl_web_current_ddmenu_node = '';
      menu_node.hide();
    } else {
      if( __ensembl_web_current_ddmenu_node ) {
        $('menu_'+__ensembl_web_current_ddmenu_node).hide();
      }
      __ensembl_web_current_ddmenu_node = name;
      Position.clone( el,menu_node,{setWidth:false,offsetTop:el.getHeight()-4});
      menu_node.show();
    }
  }

  function __ddmenu_init( dt_node ) {
    if( dt_node.id ) {
      Event.observe(dt_node,'click',__activate_menu);
    }
  }
  function __init_ensembl_web_dropdown() {
    if( $('dropdown') ) {
      $$('#dropdown dt').each( function(dt_node) {
        __ddmenu_init( dt_node );
      });
    }
  }
  
  addLoadEvent( __init_ensembl_web_dropdown );


function dropdown_redirect( id ) {
  var element = document.getElementById(id);
  var URL = element.options[element.options.selectedIndex].value;
  document.location = URL;
  return true;
}

