  var ENSEMBL_TREE_COLLAPSE = 0;

  function __init_collapse_tree() {
    if( ENSEMBL_TREE_COLLAPSE ) return;
    ENSEMBL_TREE_COLLAPSE = 1;
    $$("table.nested th").each(function(n){
      Event.observe(n,'mouseup',function(event){
        var el = Event.element(event);
	__info("UP"+el);
      });
      Event.observe(n,'click',function(event){
        var el = Event.element(event);
	__info(el);
	__info(el.nextSibling);
	__info(event);
        el.nextSibling.toggle();
      });
     // n.nextSibling.hide();
      n.setStyle({cursor:'pointer'});
    });
  }
  addLoadEvent( __init_collapse_tree );
