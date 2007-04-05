var gap = 10;
var update_interval = 1000;
var running = 0;

function ajaxLoadAverage( ID ) { tempAJAX = new AJAXRequest( 'GET', '/Homo_sapiens/ladist?i='+ID+';rand='+Math.random(), '', ajaxLoadAverageCallBack, ID ); }
function ajaxMysql( ID ) { tempAJAX = new AJAXRequest( 'GET', '/Homo_sapiens/mydist?i='+ID+';rand='+Math.random(), '', ajaxMysqlCallBack, ID ); }
function ajaxLsf() { tempAJAX = new AJAXRequest( 'GET', '/Homo_sapiens/lsfdist?rand='+Math.random(), '', ajaxLsfCallBack ); }

function bgcol( la ) { if( la < 0.5 ) return '#ffffff'; if( la < 1   ) return '#ffffcc'; if( la < 2   ) return '#ffcc99'; return '#ff9999'; }

function ajaxLsfCallBack( myAJAX ) {
  if( myAJAX.readyState == 4 && myAJAX.status == 200 ) {
    resp = myAJAX.responseText;
    document.getElementById('lsf').innerHTML = resp;
    if( running ) {
      document.getElementById('lsf_f').innerHTML = gap-1;
      window.setTimeout("clear('lsf_f')",update_interval);
      window.setTimeout("ajaxLsf()",gap * update_interval);
    } else {
      document.getElementById('lsf_f').innerHTML = '#';
    }
  }
}
function ajaxLoadAverageCallBack( myAJAX, ID ) {
  if( myAJAX.readyState == 4 && myAJAX.status == 200) {
    resp = myAJAX.responseText;
    LAS = resp.split('|');
    document.getElementById('sv_'+ID).innerHTML = LAS[0];
    document.getElementById('sv_'+ID).style.backgroundColor = bgcol( (LAS[0]-20)/10 );
    document.getElementById('bl_'+ID).innerHTML = LAS[1];
    document.getElementById('bl_'+ID).style.backgroundColor = bgcol( (LAS[1]-20)/10 );
    document.getElementById('la1_'+ID).innerHTML = LAS[2];
    document.getElementById('la1_'+ID).style.backgroundColor = bgcol( LAS[2] );
    document.getElementById('la2_'+ID).innerHTML = LAS[3];
    document.getElementById('la2_'+ID).style.backgroundColor = bgcol( LAS[3] );
    document.getElementById('la3_'+ID).innerHTML = LAS[4];
    document.getElementById('la3_'+ID).style.backgroundColor = bgcol( LAS[4] );
    document.getElementById('la4_'+ID).innerHTML = LAS[5];
    document.getElementById('la5_'+ID).innerHTML = LAS[6];
    if( running ) {
      document.getElementById('la6_'+ID).innerHTML = gap-1;
      window.setTimeout("clear('la6_"+ID+"')",update_interval);
      window.setTimeout("ajaxLoadAverage("+ID+")",gap * update_interval);
    } else {
      document.getElementById('la6_'+ID).innerHTML = '#';
    }
  }
}

function clear(X) {
  count = document.getElementById(X).innerHTML;
  count--;
  if( count > 0 ) {
    document.getElementById(X).innerHTML = count;
    window.setTimeout("clear('"+X+"')",update_interval);
  } else {
    document.getElementById(X).innerHTML = '';
  }
}

function ajaxMysqlCallBack( myAJAX, ID ) {
  if( myAJAX.readyState == 4 && myAJAX.status == 200 ) {
    resp = myAJAX.responseText;
    LAS = resp.split('|');
    document.getElementById('my_'+ID).innerHTML = '*';
    document.getElementById('my1_'+ID).innerHTML = '*';
    document.getElementById('my2_'+ID).innerHTML = '*';
    document.getElementById('my3_'+ID).innerHTML = '*';
    document.getElementById('my4_'+ID).innerHTML = '*';
    document.getElementById('my5_'+ID).innerHTML = '*';
    document.getElementById('my_'+ID).innerHTML = LAS[0];
    document.getElementById('my_'+ID).style.backgroundColor = bgcol( (LAS[0]-20)/10 );
    document.getElementById('my1_'+ID).innerHTML = LAS[1];
    document.getElementById('my1_'+ID).style.backgroundColor = bgcol( LAS[1] );
    document.getElementById('my2_'+ID).innerHTML = LAS[2];
    document.getElementById('my2_'+ID).style.backgroundColor = bgcol( LAS[2] );
    document.getElementById('my3_'+ID).innerHTML = LAS[3];
    document.getElementById('my3_'+ID).style.backgroundColor = bgcol( LAS[3] );
    document.getElementById('my4_'+ID).innerHTML = LAS[4];
    document.getElementById('my5_'+ID).innerHTML = LAS[5];
    if( running ) {
      document.getElementById('my6_'+ID).innerHTML = gap-1;
      window.setTimeout("clear('my6_"+ID+"')",update_interval);
      window.setTimeout("ajaxMysql("+ID+")",gap * update_interval);
    } else {
      document.getElementById('my6_'+ID).innerHTML = '#';
    }
  }
}

function start() {
  if(running) { return; }
  running = 1;
  document.getElementById('status').innerHTML = 'Running';
  ajaxLsf();
  for(i=1;i<15;i++) { ajaxLoadAverage(i); }
  for(i=0;i<9;i++)  { ajaxMysql(i); }
}

function stop() {
  if(!running) return;
  document.getElementById('status').innerHTML = 'Stopped';
  running = 0;
}
function create_table() {
  HTML = '<table>';
  HTML += '<tr><th>Server</th><th>httpds</th><th>p.blast</th><th>LA</th><th>LA</th><th>LA</th><th>Mem free</th><th>time</th></tr>';
  for(i=1;i<15;i++) {
   // if(i==12) i=14;
    HTML += '<tr><td>web-3-'+(i<10?'0':'')+i+'</td><td style="text-align: right" id="sv_'+i+'"></td><td style="text-align: right" id="bl_'+i+'"></td><td id="la1_'+i+'"></td><td id="la2_'+i+'"></td><td id="la3_'+i+'"></td><td id="la4_'+i+'"></td><td id="la5_'+i+'"></td><td style="color: #999; font-size: 0.8em" id="la6_'+i+'"></tr>';
  }
  HTML += '</table>';
  document.getElementById('httpd').innerHTML = HTML;
  
  HTML = '<table>';
  HTML += '<tr><th>Server</th><th>connections</th><th>LA</th><th>LA</th><th>LA</th><th>-</th><th>time</th></tr>';
  for(i=0;i<9;i++) {
   // if(i==12) i=14;
   machine_name = i==0 ? 'ecs3a-archive' : 'ecs3'+(String.fromCharCode(i+96));
    HTML += '<tr><td>'+machine_name+'</td><td style="text-align: right" id="my_'+i+'"></td><td id="my1_'+i+'"></td><td id="my2_'+i+'"></td><td id="my3_'+i+'"></td><td id="my4_'+i+'"></td><td id="my5_'+i+'"><td style="color: #999; font-size: 0.8em" id="my6_'+i+'"></tr>';
  }
  HTML += '</table>';
  document.getElementById('mysql').innerHTML = HTML;
}

