var next_menu_node_id = 1;

var configuration_updated = false;

function _menu_create_node( n, n_id, current_state ) {
/* 
  Function to create a hide/show link on a node...
*/
  var q = Builder.node('span',
    { id: n_id, className: 'menu_help' },
    [ current_state ? 'Hide info' : 'Show info' ]
  );
  n.appendChild(q);
  Event.observe(q,'click',function(e){
    remove_grey_box();
    var me = Event.findElement(e,'SPAN');
    var n  = me.parentNode;
    var t = me.id;
    var x = t+'_dd';
    me.remove();
    if( $(x) ) {
      $(x).toggle();
      _menu_create_node( n, t, $(x).visible() );
    }
  });
}

var current_menu_id = '';
var current_link_id = '';
var current_selected_node = '';
var initial_configuration = false;

function __close_config(event) {
  configurator_submit_form($('cp_close').href,'close');
  Event.stop(event);
}

function __config_tab_link( event ) {
  n = Event.findElement( event, 'A' );
  configurator_submit_form(n.href,n.innerHTML);
  Event.stop(event);
}

function __init_config_menu() {
/*
  Section 1)
  Loop through all the track configuration links on the left hand side of the
  configuration box, remove the link (so the href doesn't get fired (yuk!)
  add an onclick event to show the appropriate menu and hide the menu
*/
  if( ! initial_configuration ) {
     initial_configuration = $('configuration') ? $('configuration').serialize(true) : false;
  }
  var has_configuration = $$('.track_configuration').length > 0;
  if(
    ( $$('.track_configuration').length + $$('.view_configuration').length ) > 0
  ) {
    if( $('modal_close') ) {
      $('modal_close').innerHTML = 'SAVE and close';
    } else if($('cp_close') ) {
      $('cp_close').innerHTML = 'SAVE and close';
      Element.observe( $('cp_close'),'click', __close_config );
      $$('#tabs dd a').each(function(n){ Element.observe( n,'click',__config_tab_link ); });
    }
  }

  $$('.track_configuration dd').each(function(n) {
    var link_id = n.id;
    var menu_id = 'menu_'+link_id.substr(5);
    if( n.hasClassName('active') ) {
      current_menu_id = menu_id;
      current_link_id = link_id;
    } else {
      $(menu_id).hide();
    }
    var an = n.select('a')[0]; 
    if( an ) {
      var txt =an.innerHTML;
      an.remove();
      n.appendChild(Builder.node('span', { className: 'fake_link' }, [ txt ] ));
    }
    Event.observe( n, 'click', function(e) {
      remove_grey_box();
      var dd_n = Event.findElement(e,'DD');
      var link_id = dd_n.id;
      var menu_id = 'menu_'+link_id.substr(5);
      if( current_menu_id ) {
        $(current_menu_id).hide();
        $(current_link_id).removeClassName('active');
      }
      $(menu_id).show();
      dd_n.addClassName('active');
      current_menu_id=menu_id;
      current_link_id=link_id;
    });
  });
/*
  Section 2)
  Add a hide/show link to each of the menu items on the right handside...
*/
  $$('dl.config_menu').each(function(menu_n){
    var col          = 1;
    var current_node = 0;
    var div_n = menu_n.up('div');
    menu_n.childElements().each(function(n){
      if(n.nodeName == 'DT') {
        if( current_node ) $('mn_'+current_node).remove();
        col = 3-col;
        n.addClassName('col'+col);
	if( !n.hasClassName('munged') ) {
	  n.addClassName( 'munged' ); // Stop a double rendering of the links!
          _menu_create_node( n, 'mn_'+next_menu_node_id, 0 );
	}
        current_node = next_menu_node_id;
        next_menu_node_id++;
        n.select('select').each(function(sn){
	  if(sn.visible()) {
            var current_selected = 'off';
            sn.hide();
            sn.select('option').each(function(on){
              if(on.selected) {
                var x = on.value;
                var i = Builder.node('img',{ src:'/i/render/'+x+'.gif', title:on.text, cursor: 'pointer', id:'gif_'+sn.id });
                n.insertBefore(i,sn.nextSibling);
                Event.observe(i,'click',change_img_value);
             }
            });
	  }
        });
      } else if(n.nodeName == 'DD' && current_node) {
        n.setAttribute('id','mn_'+current_node+'_dd');
        n.addClassName('col'+col);
        n.hide();
        current_node = 0;
      }
    });
    if( current_node ) $('mn_'+current_node).remove();
  });
  $$('#configuration dt.submit').each(function(n){ n.hide(); });
/* deprecated!!  
  if( $('config') ) {
    Event.observe( $('config'), 'submit', function(f){
      alert($('config').serialize());
    });
  } */
}

var configurator_action_url = '';
var configurator_action_title = '';

function configurator_submit_form( url, title ) {
  remove_grey_box(); // Remove our "pseudo" graphical dropdowns....
  // Grab the final configuration ...
  var _referer = initial_configuration._referer;
  var final_configuration = $H( $('configuration') ? $('configuration').serialize(true) :{} );
  // ... and compare it with the initial configuration
  var diff_configuration = {};
  var config_name = '';
  final_configuration.each(function(pair){
    if( pair.key == 'config' ) {
      config_name = pair.value;
    } else if( pair.value != initial_configuration[pair.key] ) {
      diff_configuration[ pair.key ] = pair.value;
    }
    delete initial_configuration[pair.key];
  });
  $H(initial_configuration).each(function(pair){ diff_configuration[ pair.key ] = 'no'; }); // CheckBox 0 value!
  initial_configuration = false;
  if( $H(diff_configuration).keys().size() == 0 ) {
    if( title == 'close' ) {
      if( window.opener != window ) {
        window.opener.location.href = _referer; 
      }
      window.close();
    } else {
      __modal_dialog_link_open_2( url, title );
      return;
    }
  }
  if( config_name ) {
    diff_configuration[ 'config' ] = config_name;
  }
  diff_configuration[ 'submit' ] = 1;
  var T = new Date();
  diff_configuration[ 'time' ] = T.getTime();
  // ... create a query string from this...
  if( ENSEMBL_AJAX == 'enabled' ) { // We have Ajax so submit it using AJAX
    $('modal_disable').show();
    configurator_action_url   = url;
    configurator_action_title = title;
    new Ajax.Request( $('configuration').action,{
      method : $('configuration').method,
      parameters: $H(diff_configuration),
      onSuccess: function( transport ) { configurator_success(transport) },
      onFailure: function( transport ) {
        $('modal_disable').hide();
	$('modal_content').innerHTML = '<p class="ajax-error">Failure: unable to update configuration</p>';
      }
    });
  } else {
    if( title == 'close' ) {
      diff_configuration._ = 'close';
      diff_configuration._referer = _referer;
      var url_2 = $('configuration').action+"?"+$H(diff_configuration).toQueryString();
      if( window.opener == window ) {
        window.location.href = url_2+';force_close=1';
        return 1;
      } else {
        window.opener.location.href = url_2;
        window.close();
      }
    } else {
      diff_configuration._ = url;
      diff_configuration._referer = _referer;
      var url_2 = $('configuration').action+"?"+$H(diff_configuration).toQueryString();
      window.location.href = url_2; // Jump to the configuration changing code!
    } 
  }
  return 0;
}

function configurator_success( transport ) {
  var x = transport.responseText;
  $('modal_disable').hide();
  if( x == 'SUCCESS' ) { // Form submitted OK!... we need to flag this case!
    configuration_updated = true;
    page_needs_to_be_reloaded = true;
    $('modal_content').update(Builder.node('div', 'Content updated'));
    __modal_dialog_link_open_2( configurator_action_url, configurator_action_title );
  } else if( x.match('/^FAILURE:/') ) {
    $('modal_content').update(Builder.node('div','Content failed to update: '+x));
  } else { // We've got the form back....
    modal_success( transport ); // Act like we just loaded it!!!
  }
}

function remove_grey_box() {
  if( $('s_menu') ) $('s_menu').remove();
  current_selected_index = 0;
}

function change_img_value(e) {
  var i_node = Event.element(e);
  var select_id = i_node.id.substr(4);
      current_selected_index = select_id;
  var value     = i_node.src;
  if($('s_menu')) $('s_menu').remove();
  var x = Position.cumulativeOffset(i_node);
  if( Prototype.Browser.Gecko ) {
    var x2 = i_node.cumulativeScrollOffset();
    x[1]-= x2[1];
    var x3 = $$('body')[0].cumulativeScrollOffset();
    x[1]+= x3[1];
  } 
  var select_menu = Builder.node('dl',{
    id:       's_menu',
    className:'popup_menu',
    style:    'position:absolute;top:'+(x[1]+15)+'px;left:'+(x[0]+10)+'px;z-index: 1000000;'
  });
  $$('body')[0].appendChild(select_menu);
  //$('modal_panel').appendChild(select_menu);

  $(select_id).select('option').each(function(on){
    dt_node = Builder.node('dt',
      [ Builder.node('img',  {title: on.text,src:'/i/render/'+on.value+'.gif'}),on.text ]
    )
    select_menu.appendChild(dt_node);
    Event.observe(dt_node,'click',function(e){
      var value = Event.findElement(e,'DT').select('img')[0].title;
      dt_node.parentNode.remove();
      $(current_selected_index).select('option').each(function(on){
        if(on.text == value) {
          on.selected = "selected";
          $('gif_'+current_selected_index).src = '/i/render/'+on.value+'.gif';
          current_selected_index = 0; return;
        }
      });
    });
  });
//  i_node.relativize();
}

addLoadEvent(__init_config_menu);
