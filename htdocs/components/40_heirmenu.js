// Javascript to do collapsible hierarchical menus

function codelinks() {
  return;
  pre_blocks = document.getElementsByTagName( 'pre' );
  if(!document.all){
  for( i = 0; i< pre_blocks.length; i++ ) {
    c = pre_blocks[i];
    T = c.innerHTML;
    T = T.replace( /^(#[^!].*)$/gm, '<div style="background-color: #ffcc99; margin: 0.2em 0 -0.8em 0; padding: 0.3em">$1</div>' );
    T = T.replace( /^sub (.*)$/gm, '<span style="font-weight: bold">sub <span style="color: #00c">$1</span></span>' );
    T = T.replace( /(\$\w+)/gm, '<span style="color: #900; font-weight: bold">$1</span>' );
    T = T.replace( /([\[\](){}])/gm, '<span style="font-weight: bold">$1</span>' );
    T = T.replace( /([@$%])/gm, '<span style="font-weight: bold">$1</span>' );
    T = T.replace( /-&gt;(\w+)/gm, '<span style="font-weight: bold">-&gt;<span style="color: #00c">$1</span></span>' );
//    T = T.replace( /'([^']+)'/gm, "'<span style=\"background-color: #ccffcc\">$1</span>'" );
    c.innerHTML = T;
  }
  }
  code_entries = document.getElementsByTagName( 'code' );
  for( i = 0; i< code_entries.length ; i++ ) {
    c = code_entries[i];
    cl = c.getAttribute( 'class' ) ;
    switch( cl ) {
      case 'module':
        c.style.cursor = 'pointer';
        c.onclick   = auto_cvs_link;
        c.setAttribute( 'title', 'View source code of '+c.innerHTML+' from cvs.sanger.ac.uk' );
    }
  }
}

function auto_cvs_link() {
  cvs_link( this.getAttribute('class'), this.innerHTML );
}

function cvs_link( type, module_name ) {
  mod_path = module_name.replace( /::/g, '/' ); 
  prefix = 'http://cvs.sanger.ac.uk/cgi-bin/viewcvs.cgi/';
  if( type == 'module' ) {
    area = 'ensembl-webcode/modules';
    extn = '.pm';
  } else if( type == 'script' ) {
    area = 'ensembl-webcode/perl/default';
    extn = '';
  }
  URL = prefix+area+'/'+mod_path+extn+'?rev=HEAD&view=markup'
  window.open( URL, 'cvs', '' );
}

function open_code_window( anchor ) { window.open('sourcecode.html#'+anchor,'sourcecode',''); }
function exp_coll(ind)

{
 s = document.getElementById("sp_" + ind);
 i = document.getElementById("im_" + ind);
 if (s.style.display == 'none')
 {
   s.style.display = 'block';
   i.src = "/img/minus.gif";
 }
 else if (s.style.display == 'block')
 {
   s.style.display = 'none';
   i.src = "/img/plus.gif";
 }
}

function exp(ind)
{
 s = document.getElementById("sp_" + ind);
 i = document.getElementById("im_" + ind);
 if (!(s && i)) return false;
 s.style.display = 'block';
 i.src = "/img/minus.gif";
}

function coll(ind)
{
 s = document.getElementById("sp_" + ind);
 i = document.getElementById("im_" + ind);
 if (!(s && i)) return false;
 s.style.display = 'none';
 i.src = "/img/plus.gif";
}

function coll_all()
{

 coll(0);
}

function exp_all()
{

 exp(0);
}
addLoadEvent( codelinks );

