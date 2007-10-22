function openATV( server, u ) {
  atv_window = open("", "atv_window", 
    "width=300,height=150,status=no,toolbar=no,menubar=no,resizable=yes");

  // open document for further output
  atv_window.document.open();
  
  // create document
  atv_window.document.write( "<HTML><HEAD><TITLE>ATV" );
  atv_window.document.write( "</TITLE></HEAD><BODY>" );
  atv_window.document.write( "<BODY TEXT =\"#FFFFFF\" BGCOLOR =\"#000000\">" );
  atv_window.document.write( "<FONT FACE = \"HELVETICA, ARIAL\">" );
  atv_window.document.write( "<CENTER><B>" );
  atv_window.document.write( "Please do not close this window<BR>as long as you want to use ATV." );
  atv_window.document.write( "<APPLET ARCHIVE = \""+server+"/java/eATVapplet.jar\"" );
  atv_window.document.write( " CODE = \"forester.atv_awt.ATVapplet.class\"" );
  atv_window.document.write( " WIDTH = 200 HEIGHT = 50>\n" );
  atv_window.document.write( "<PARAM NAME = url_of_tree_to_load\n" );
  atv_window.document.write( " VALUE = " + u  + ">");
  atv_window.document.write( "</APPLET>" );
  atv_window.document.write( "</BODY></HTML>" );
  
  // close the document - (not the window!)
  atv_window.document.close();  
}
