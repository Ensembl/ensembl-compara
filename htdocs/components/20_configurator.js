  var configurator = {
    current_tab: '',
    current_panel: '',
    current_sub:   '',
    tabs: {
      account  : {code: 'account' },
      login    : {code: 'login',    def: 'login'    },
      register : {code: 'login',    def: 'register' },
      userdata : {code: 'userdata', def: 'list'     },
      config   : {code: 'config' },
      sitemap  : {code: 'sitemap',  def: 'software' },
      help     : {code: 'help' }
    },
    panels: { }
  };
/**------------------------------------------------------------------------
| Initialize the display of the configurator...                           |
------------------------------------------------------------------------**/
/**------------------------------------------------------------------------
| CLICK ON THE "[X]" ON THE PANEL                                         |
------------------------------------------------------------------------**/
  function action_close_panel() {    /**  **/
    close_panel();
    configurator.current_tab = '';
  }
/**------------------------------------------------------------------------
| CLICK ON A TAB IN THE CONFIGURATOR BAR                                  |
------------------------------------------------------------------------**/
  function action_open_tab(event) {
    tab_name = Event.element(event).id;
    if( configurator.current_tab ) {              
                                              /*** here we action a close of the current panel... ***/
      close_panel();                   /*** Now we empty the current panel***/
      $('conf').hide();                     /*** And hide it away... ***/
    }
    panel_name = configurator.tabs[tab_name].code;
    def_sub    = configurator.tabs[tab_name].def;
    if( configurator.current_tab == tab_name ) {
      configurator.current_tab = '';
    } else {
      if( configurator.panels[ panel_name ] ) {
        if( def_sub ) {
          configurator.panels[ panel_name ].def = def_sub;
        }
        expand_panel( configurator.panels[panel_name] );
        configurator.current_tab = tab_name;
      } else {
        $('conf_tt').appendChild(document.createTextNode('... loading current tab'));
        var URL = '/ajax.php/panel/'+panel_name;
        if( def_sub ) URL += '/'+def_sub;
        configurator.current_tab = tab_name;
        new Ajax.Request( URL+'?', {
          method: 'get',
          onSuccess: function( transport ) {
            var r;
            eval( 'r='+transport.responseText );
            configurator.panels[r.code] = r;
            configurator.panels[r.code].subs = {};
            expand_panel( r );
          }
        });
      }
    }
  }
/**------------------------------------------------------------------------
| CLICK ON A LHS MENU IN THE PANEL                                        |
------------------------------------------------------------------------**/
  function action_change_sub(event) {     /**  **/
    var M = Event.element(event).id.match(/([A-Z]+)_(\w+)/);
    if(M) {
      var panel_code = M[1];
      var sub_code   = M[2];
      var panel_conf = configurator.panels[panel_code];
      panel_conf.entries.each(function(elt) {
        if( sub_code == elt.code ) {
          sub_row = elt;
        }
      });
      expand_sub( panel_code, sub_row );
    }
  }
/** support functions - empty an HTML element **/
  function _empty(n) { $(n).innerHTML=''; }
/** support functions - close panel and empty components **/
  function close_panel() { _empty('conf_tt'); _empty('conf_cat');_empty('conf_rhs'); $('conf').hide(); }
/** Expand the panel - based on the configuration supplied **/
  function expand_panel( panel_conf ) {
    _empty('conf_tt');
    $('conf_tt').appendChild(document.createTextNode(panel_conf.name));
    var def_row;
    panel_conf.entries.each(function(elt) {
      node = Builder.node('dd', { id: panel_conf.code+'_'+elt.code }, elt.name);
      if( panel_conf.def == elt.code ) {
        def_row = elt;
        node.addClassName('same');
      }
      $('conf_cat').appendChild(node);
      node.onclick = action_change_sub
    });
    expand_sub( panel_conf.code, def_row );
  }
  function expand_sub( panel_code, sub_conf ) {
    switch(sub_conf.type) {
      case 'sub': 
        new Ajax.Request('/ajax.php/sub/'+panel_code+'/'+sub_conf.code, {
          method: 'get',
          onSuccess: function( transport ) {
            var r;
            eval( 'r='+transport.responseText );
            eval( r.javascript );
            $('conf_rhs').innerHTML = r.html;
          }
        });
        break;
      case 'radiobuttons': 
        dl_node = Builder.node('dl', { className: 'cblist'} );
        _empty( 'conf_rhs');
        $('conf_rhs').appendChild(dl_node);
        dl_node.appendChild(Builder.node('dt',[sub_conf.name+':']));
        $H(sub_conf.values).each(function(ent) {
          entry_radiobutton = Builder.node( 'img', {className: 'ms', id: 'node_'+ent.key, src: '/i/radio-'+(ent.key==sub_conf.state?1:0)+'.gif'} );
          dl_node.appendChild(Builder.node('dd',[entry_radiobutton, ' ',ent.value ]));
        });
        break;
      case 'checkboxes':
      default:
        dl_node = Builder.node('dl', { className: 'cblist'} );
        _empty( 'conf_rhs');
        $('conf_rhs').appendChild(dl_node);
        all_entries_checkbox = Builder.node('img', {className: 'ms', id: 'all', src: '/i/state-'+sub_conf.state+'.gif'} );
        all_entries = Builder.node( 'dt', [all_entries_checkbox, 'All '+sub_conf.name] );
        dl_node.appendChild(all_entries);
        all_entries_checkbox.onclick = progress_state;
        sub_conf.entries.each(function( ent ) {
          entry_checkbox = Builder.node('img', {className: 'ms', id: 'node_'+ent.key, src: '/i/state-'+ent.state+'.gif'} );
          entry = Builder.node( 'dd', {title: ent.description}, [entry_checkbox, ent.name] );
          dl_node.appendChild(entry);
          entry_checkbox.onclick = progress_state;
        });
        if( sub_conf.das_entries && sub_conf.das_entries.length > 0 ) {
          all_entries = Builder.node( 'dt', 'DAS based sources' );
          dl_node.appendChild(all_entries);
          sub_conf.das_entries.each(function( ent ) {
            entry_checkbox = Builder.node('img', {className: 'ms', id: 'node_'+ent.key, src: '/i/state-'+ent.state+'.gif'} );
            entry = Builder.node( 'dd', {title: ent.description}, [entry_checkbox, ent.name] );
            dl_node.appendChild(entry);
            entry_checkbox.onclick = progress_state;
          });
        }
    }
    $('conf').show();
  }

  
  function _node( part, n ) {
    if( current_set[part] ) {
      $(current_set[part]).removeClassName( 'active' );
    }
    var nd = $(part+'_node_'+n);
    nd.addClassName( 'active' );
    current_set[part] = part+'_node_'+n
    $(part+'_list').immediateDescendants().each(function(node){node.remove()});
    sub_conf  = configurator_tabs[part]['entries'][ n ];
    switch(sub_conf.type) { 
      case 'misc' :
        $(part+'_list').innerHTML = sub_conf.contents;
        break;
      case 'radiobuttons' :
        break;
      default:
        break;
    }
  }
  function process(tab_name) {
    flag = 1;
    _empty(tab_name+'_cat_list');
    c = 0;
    configurator_tabs[tab_name]['entries'].each(function(elt) {
      node = Builder.node('dd', { id: tab_name+'_node_'+c}, elt.name);
      c++;
      $(tab_name+'_cat_list').appendChild(node)
      node.onclick = action_change_sub
    });
    _node(tab_name,0);
  }
  function progress_state(e) {
    if(!e) { e = event; }
    el = Event.element(e);
    N = el.src;
/** this is we record the new state **/
    if( N.match( /state-3\.gif/ ) ) {  el.src = N.replace( /state-3/, 'state-0' ); }
    if( N.match( /state-2\.gif/ ) ) {  el.src = N.replace( /state-2/, 'state-3' ); }
    if( N.match( /state-1\.gif/ ) ) {  el.src = N.replace( /state-1/, 'state-2' ); }
    if( N.match( /state-0\.gif/ ) ) {  el.src = N.replace( /state-0/, 'state-1' ); }
    
  }

/*** THE INITIALIZER ***/
  function __init_ensembl_web_configurator() { /** Make all the tags clickable **/
    $('conf').appendChild(
      Builder.node( 'table', { id: 'conf_tb' }, [
        Builder.node( 'tr', [
          Builder.node( 'th', { colspan: 2 }, [
            Builder.node( 'img', { id: 'conf_close', src: '/i/close.gif', alt: '[X]', title: 'Save changes and close' } ),
            Builder.node( 'span', { id: 'conf_tt' } )
          ])
        ]),
        Builder.node( 'tr', [
          Builder.node( 'td', { id: 'conf_lhs' }, [
            Builder.node( 'dl', { id: 'conf_cat' } )
          ]),
          Builder.node( 'td', { id: 'conf_rhs' }, 'X' )
        ]),
      ])
    );
    if( $('mh_lnk') ) {
      $$('#mh_lnk a.conf').each(function(node){
         Event.observe(node,'click',action_open_tab);
      });
      Event.observe($('conf_close'),'click',action_close_panel);
    }
  }

//  Event.observe(window, 'load', __init_ensembl_web_configurator );
/***
    $$('img.ms').each(function(node){node.onclick = progress_state});
    $w('config').each(function(key){
      block = configurator_tabs[key]['entries'];
      block.each(function(tab){
        tab.state = tab.initial_state;
        if(tab.entries) {
          tab.entries.each(function(entry){entry.state = entry.initial_state});
        }
        if(tab.das_entries) {
          tab.das_entries.each(function(entry){entry.state = entry.initial_state});
        }
      });
    });
**/


