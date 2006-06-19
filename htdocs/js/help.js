/*========================================================================
 Help popup code
 initial rendering and hiding of help popups...
========================================================================*/

function miniPopup ( event, helpID, species, script, offset_x, offset_y ) {
  if(arguments.length < 1) { return true; }
  offset_x = offset_x || 10;
  offset_y = offset_y || 10;
  help_x = egeX(event) + offset_x;
  help_y = egeY(event) + offset_y;
  show_help( helpID, help_x, help_y, species, script );
  return true;
}

function hide_help( help ) {hide(ego( help ));}

function show_help( helpID, e_x, e_y, species, script ) {

  PP = ego('popups');
  if( helpID ) {
    child=ego(helpID);
    if(child) { show(child);m2(child,e_x,e_y); return }
  } else {
    helpID = 0;
    child = ego(helpID);
    if(child) { PP.removeChild(child) } 
  }

  // create the new popup help
  nh = dce( 'div' );
  sa( nh, 'id', 'popup' + helpID );
  ac( PP, nh );
  nh.className = 'help-popup';
  t = dce( 'table' );
  t.style.backgroundColor = '#ffffff'
  t.style.borderCollapse  = 'collapse';
  t.style.borderWidth     = '0px';
  t.style.width           = '400px';

  // fetch content
  caption = 'HELP: item ' + helpID;
  text = 'This is help item ' + helpID + '.<p>When completed, this code will pull in help text from the database using <strong>AJAX</strong> calls.</p>';
  // Link out to "normal" Help popup
  text += '<p><a href="javascript:void(window.open(' + "'/" + species + '/helpview?se=1;kw=' + script + "','helpview','width=700,height=550,resizable,menubar,scrollbars'))" + '">More help</a>...</p>';

  // create draggable table header
  t_h=dce('thead');t_r=dce('tr');
  t_h1=dce('th');t_h2=dce('th');t_h3=dce('th');
  t_h1.onmousedown = drag_start;
  t_h1.style.width = '370px';
  t_h2.style.width = '15px';
  t_h3.style.width = '15px';
  ac( t_h1, dtn( caption ) );cl = dce( 'a' );var mn = dce( 'a' );
  mn.onclick = function() {
    var N = this.parentNode.parentNode.parentNode.parentNode.getElementsByTagName('tbody')[0];
    var I = this.getElementsByTagName('img')[0];
    if(N.style.display=='none') {
      N.style.display=''
      I.src = '/img/dd_menus/up.gif';
    } else { 
      N.style.display='none'
      I.src = '/img/dd_menus/down.gif';
    }
  }
  sa( cl, 'href', 'javascript:void(hide_help("popup' + helpID + '"))' );
  im2 = dce( 'img' );
  im2.style.borderWidth = 0;
  im2.height = 12
  im2.width  = 12
  im2.src = '/img/dd_menus/up.gif';
  im2.className = 'right';

  im = dce( 'img' );
  im.style.borderWidth = 0;
  im.height = 12
  im.width  = 12
  im.src = '/img/dd_menus/close.gif';
  im.className = 'right';

  sa( im, 'alt',   'X' );
  sa( im, 'title', 'Close popup' );
  
  sa( im2, 'alt', 'v' );
  sa( im2, 'title', 'Min popup' );
  ac(mn,im2);
  ac(cl,im);
  ac(t_h2,mn);
  ac(t_h3,cl);
  ac(t_r,t_h1);
  ac(t_r,t_h2);
  ac(t_r,t_h3);
  ac(t_h,t_r);
  ac(t,t_h);

  // create main cell
  t_b=dce('tbody');
  ro = dce('tr');
  ce = dce('td');
  ce.colSpan = 3;
  ce.innerHTML = text;
  ac(ro, ce); ac(t_b, ro); ac(t,t_b);

  // complete popup table and position at click point
  ac(nh,t);show(nh);
  m2(nh, e_x, e_y );
}

