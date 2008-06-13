function __collapse( div_node ) {
  div_node.getElementsBySelector('.content').each(function(child_div){
    child_div.hide();
  });
  b_node = Builder.node( 'img', { style: 'float:left; vertical-align: top', src: '/i/closed.gif', alt:'' } );
  b_node.observe('click',function(evt){
    var el = Event.element(evt);
    var p  = el.parentNode; 
    p.getElementsBySelector('.content').each(function(child_div){
      child_div.toggle();
    });
    p.firstChild.src = p.firstChild.src.match(/closed/) ? '/i/open.gif' : '/i/closed.gif'
  });
  div_node.insertBefore(b_node,div_node.firstChild)
}

function __init_ensembl_web_expandable_panels() {
  $$('div.expandable').each( function(div_node) {
    __collapse( div_node );
  });
}

function __init_ensembl_web_hide_form() {
  if( $('hideform') ) {
    Event.observe($('hideform'),'click',function(event){
      $('selectform').hide();
    });
  }
}

addLoadEvent(__init_ensembl_web_expandable_panels );

addLoadEvent(__init_ensembl_web_hide_form );


function __init_ensembl_rel_external() {
  $$('a[rel="external"]').each(function(n){
    n.target = '__blank'
  });
}
addLoadEvent( __init_ensembl_rel_external );

var Cookie = {
  set: function(name, value, daysToExpire) {
    var expire = '';
    if(daysToExpire != undefined) {
      var d = new Date();
      d.setTime(d.getTime() + (86400000 * parseFloat(daysToExpire)));
      expire = '; expires=' + d.toGMTString();
    }
    return (document.cookie = escape(name) + '=' + escape(value || '') + expire);
  },
  get: function(name) {
    var cookie = document.cookie.match(new RegExp('(^|;)\s*' + escape(name) + '=([^;\s]*)'));
    return (cookie ? unescape(cookie[2]) : null);
  },
  unset: function(name) {
    var cookie = Cookie.get(name) || true;
    Cookie.set(name, '', -1);
    return cookie;
  }
};
