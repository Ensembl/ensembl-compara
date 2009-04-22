var XhtmlValidator = Class.create( {
  ent: /&(amp|lt|gt|quot|apos);/i,
  ats: {'class':1,title:1,id:1,style:1},
  nts: {
  // elements rt?, can have HTML content?, valid attributes [all tg can take class,name,id], child tg...
    'img'    :{rt:1,tx:0,at:{src:1,alt:1,title:1},tg:{}                              },
    'a'      :{rt:1,tx:1,at:{href:1,name:1,rel:1},tg:{img:1,span:1,em:1,i:1,strong:1}    },
    'strong' :{rt:1,tx:1,at:{},                   tg:{img:1,a:1,em:1,i:1,span:1}         },
    'i'      :{rt:1,tx:1,at:{},                   tg:{img:1,strong:1,em:1,a:1,span:1}     },
    'em'     :{rt:1,tx:1,at:{},                   tg:{img:1,strong:1,i:1,em:1,a:1,span:1}     },
    'p'      :{rt:1,tx:1,at:{},                   tg:{img:1,strong:1,em:1,i:1,a:1,span:1}},
    'span'   :{rt:1,tx:1,at:{},                   tg:{img:1,strong:1,em:1,i:1,a:1,span:1}},
    'li'     :{rt:0,tx:1,at:{},                   tg:{span:1,p:1,img:1,strong:1,em:1,i:1,a:1,ul:1,ol:1,dl:1}},
    'dt'     :{rt:0,tx:1,at:{},                   tg:{span:1,p:1,img:1,strong:1,em:1,i:1,a:1,ul:1,ol:1,dl:1}},
    'dd'     :{rt:0,tx:1,at:{},                   tg:{span:1,p:1,img:1,strong:1,em:1,i:1,a:1,ul:1,ol:1,dl:1}},
    'ol'     :{rt:1,tx:0,at:{},                   tg:{li:1}                          },
    'ul'     :{rt:1,tx:0,at:{},                   tg:{li:1}                          },
    'dl'     :{rt:1,tx:0,at:{},                   tg:{dd:1,dt:1}                     }
  },
  _tr: function(s) { return s.replace(/\s+/g,' ').replace(/^\s+/,'').replace(/\s+$/,''); },
  validate: function(string) {
    var err = 0;
    var a   = [];
    var slf = this;
// Firstly split the HTML up into tg and entries...
    string.split( /(?=<)/ ).each(function(w){
      if(w.substr(0,1) == '<' ) {
        var x = w.match(/^([^>]+>)([^>]*)$/);
        if(x) {
          a.push(x[1]);
          if( x[2].match(/\S/)) a.push(x[2]);
        } else { 
          err = 'Not well-formed: "'+slf._tr(w)+'"'
        }
      } else if( w.match(/>/)) {
        err = 'Not well-formed: "'+slf._tr(w)+'"'
      } else if( w.match(/\S/)) {
        a.push( w );
      }
    });
    if( err ) return(err);
      
    var stk = [];
    a.each(function(w){
      var LN = stk[0];
      if( w.substr(0,1) == '<' ) { // This is a tag...
        var TN = '';
        var ATS = '';
        var SCL = '';
        var cls = w.match(/<\/(\w+)>/);
        if( cls ) {
          if( stk.length == 0 ) {
            error = 'Attempt to close too many tags "/'+cls[1]+'"';
          } else {
            var LAST = stk.shift();
            if( LAST != cls[1] ) err = 'Mismatched tag "/'+cls[1]+'" != "'+LAST+'"';
	  }
        } else {
          var tag = w.match(/<(\w+)(.*?)(\/?)>/s); 
          if( tag ) {
            TN      = tag[1];
            if( TN.match(/[A-Z]/) ) {
              err = 'Non lower-case tag: "'+TN+'".';
            } else {
              if( !slf.nts[TN] ) { // Return an err if we don't allow the tag
                err = 'Tag "'+TN+'" not allowed';
              } else if( LN && ! slf.nts[ LN ].tg[TN] ) { // Return an err if this is nested in an invalid parent
                err = 'Tag "'+TN+'" not allowed in "'+stk[stk.length-1]+'"';
              } else if( ! LN && ! slf.nts[ TN ].rt ) { // Return an err if this tag has to be embeded in another tag and isn't
                err = 'Tag "'+TN+'" not allowed at top level';
              } else {
                ATS         = tag[2];
                SCL  = tag[3]=='/'?1:0;
                if( ! SCL ) stk.unshift( TN );
                if( ATS ) { 
                  while( m = ATS.match(/^\s+(\w+)\s*=\s*"([^"]*)"(.*)$/s ) ){
                    var AN = m[1];
                    var vl = m[2];
                    if( AN.match(/[A-Z]/) ) {
                      err = 'Non lower case attr name "'+AN+'" in tag "'+TN+'".';
                    } else {
                      if( slf.ats[AN] || slf.nts[TN].at[AN] ) {
                        vl.split(/(?=&)/).each(function(e){
                          if(e.substr(0,1)=='&') if( ! e.match(slf.ent) ) err='Unknown entity "'+e+'" in attr "'+AN+'" in tag "'+TN+'".';
                        });
                      } else {
                        err = 'Attr "'+AN+'" not valid in tag "'+TN+'".';
                      }
                    }
                    ATS = m[3];
                  }
                  if( ATS.match(/\S/) ) err = 'Problem with tag "'+TN+'"\'s attrs ('+ATS+').';
                }
              }
            }
          } else {
            err='Malformed tag "'+w+'"';
          }
        }
      } else { // This is raw HTML
        if( LN && ! slf.nts[LN].tx ) {    // Return an err if in a tag which can't contain raw text!!
          err = 'No raw text allowed in "'+LN+'"';
        } else { // Now check all entities.
          w.split(/(?=&)/).each(function(e){
            if(e.substr(0,1)=='&') if( ! e.match(slf.ent) ) err='Unknown entity "'+slf._tr(e)+'"';
          });
        }
      }
      if(err) return;  // Skip out of the loop...
    });
    if( !err && stk.length > 0 ) {
      return 'Unclosed tags "'+stk.join(' ')+'"';
    }
    return err;
  }
});
