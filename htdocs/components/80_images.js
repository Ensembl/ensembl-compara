/***********************************************************************
**                                                                    **
**  This Javascript module alters the search box to have a graphical  **
**  drop down akin to the Firefox drop down on server load            **
**                                                                    **
**    Global variables: ENSEMBL_SEARCH_BOX - Flag to make sure that   **
**                      we only populate the drop down box once!!     **
**                                                                    **
**    Public functions: remove_search_index(code);                    **
**                      add_search_index(code,label);                 **
**                                                                    **
***********************************************************************/


  var IMAGE_FORMAT_TYPES = [];

  function image_format_type( format_code, format_label ) {
    IMAGE_FORMAT_TYPES.push( { cd:format_code, lb:format_label } );
  }

  function add_image_format(menu,url,code,label) {
    if(!menu) return;   // Sanity check can't add to what doesn't exist!
		url2 = url.replace(/\?export=[^;]+/,'?export='+code).replace(/\;export=[^;]+/,';export='+code);
    var n = Builder.node( 'dt', 
		  Builder.node( 'div', { style: 'float: right' }, [
  			Builder.node( 'a', { href: url2 }, [ '[view]' ] )
		  ] ),
		  Builder.node( 'a', { href: url2+';download=1', width: '9em' }, [ 'Export as '+label ] )
		);
		menu.appendChild(n);
		Event.observe(n,'click',function(event){ Event.findElement(event,'dl').toggle(); });
  }

  function __init_image_export() {
    $$('.iexport a').each(function(n){
			if( n.hasClassName('munged') ) return;
      var url = n.href;
      n.innerHTML = 'Export image';
      var mn = Builder.node( 'dl', {className:'iexport_mn', id: 'menu_'+n.identify(), style: 'display:none' } );
      n.up('div').parentNode.appendChild(mn);
      Event.observe(n,'click',function(event){
			  var nd = Event.findElement(event,'a');
        var menu = $('menu_'+nd.id);
        Position.clone(nd,menu,{setWidth:false,offsetTop:nd.getHeight()-4});
        menu.toggle();
  			event.stop();
      });
      IMAGE_FORMAT_TYPES.each(function(t){
        add_image_format( mn, url, t.cd, t.lb );
      });
      n.addClassName('munged');
      n.addClassName('print_hide');
    });
// Create the search list!
  }

  image_format_type( 'pdf',      'PDF' );
  image_format_type( 'svg',      'SVG' );
  image_format_type( 'eps',      'PostScript' );
  image_format_type( 'png-10',   'PNG (x10)' );
  image_format_type( 'png-5',    'PNG (x5)' );
  image_format_type( 'png-2',    'PNG (x2)' );
  image_format_type( 'png',      'PNG' );
  image_format_type( 'png-0.5',  'PNG (x0.5)' );

  addLoadEvent( __init_image_export );
