var FormCheck = Class.create({
  initialize: function() {
    this.nodata_req = '#fec';
    this.nodata_opt = '#fff';
    this.data_error = '#fcc';
    this.data_valid = '#cfc';
    var labels = {};
    $$('label').each(function(l){ 
      labels[l.htmlFor] =l.title ? l.title : l.innerHTML;
    });
    this.labels     = labels;
  },
  trim:      function( s ) { return s.replace(/^(\s+)?(.*\S)(\s+)?$/, '$2'); },
  _isint:    function( s ) { return /^[-+]?\d+$/.test(s) },
  _isfloat:  function( s ) { return /^[-+]?(\d+\.\d+|\d+\.?|\.\d+)?([Ee][+-]?\d+)?$/.test(s) },
  _isemail:  function( s ) { return /^[^@]+@[^@.:]+[:.][^@]+$/.test(s) },
  _isurl:    function( s ) { return /^https?:\/\/\w.*$/.test(s)        },
  _ispass:   function( s ) { return /^\S{6,32}$/.test(s)               },
  _iscode:   function( s ) { return /^\S+$/.test(s)                    },
  _ishtml:   function( s ) { var err = XhtmlValidator().validate( s ); return err ? 0 : 1 },
  _isalpha:  function( s ) { return /^\w+$/.test(s)                    },
  valid: function( type, s ) {
    switch(type) {
      case 'code'        : return this._iscode(  s);
      case 'alpha'       : return this._isalpha( s);
      case 'email'       : return this._isemail( s);
      case 'url'         : return this._isurl(   s);
      case 'password'    : return this._ispass(  s);
      case 'nonnegint'   : return this._isint(   s) &&   parseInt(s) >= 0; 
      case 'nonnegfloat' : return this._isfloat( s) && parseFloat(s) >= 0;
      case 'posint'      : return this._isint(   s) &&   parseInt(s) >  0;
      case 'posfloat'    : return this._isfloat( s) && parseFloat(s) >  0;
      case 'int'         : return this._isint(   s);
      case 'html'        : return this._ishtml(  s);
      case 'float'       : return this._isfloat( s);
      case 'age'         : return this._isint(   s) &&   parseInt(s)>=0
                                                    &&   parseInt(s)<=150;
      default            : return 1;
    }
  },
  simple: function( el ) {
    var req  = el.hasClassName( 'required' );
    var opt  = el.hasClassName( 'optional' );
    if( !req && !opt ) return '';
    var tmpl = '';
    var type = '';
    el.classNames().each(function(c){ if(c.substr(0,1)=='_') type = c.substr(1); });
    var V;
    if ( el.nodeName == 'SELECT' ) {
      V = this.trim( el.options[el.selectedIndex].value );
      if( V == '' && req ) tmpl = "You must select a value for '####'";
    } else {
      V = this.trim(el.value);
      if( V == '' ) { // If required then check to see it isn't blank...
        if( req ) tmpl = "You must enter a value for '####'";
      } else if( type == 'html' ) { // Check HTML - need to error out of validator...
      	err = XhtmlValidator().validate( V );
	if( err ) tmpl = "The value of '####' is invalid ("+err+")";
      } else {        // Now check the types of parameters - currently only email but could add URL...
        if( !this.valid(type,V) ) tmpl = "The value of '####' is invalid.";
      }
    }
    if( tmpl != '' ) {
      var name = this.labels[el.id];
      if(!name) name = el.id;
      return tmpl.replace(/####/, name )+"\n";
    } else {
      return '';
    }
  },
  check: function( el ) {
    var req  = el.hasClassName( 'required' );
    var opt  = el.hasClassName( 'optional' );
    if( !req && !opt ) return;
    var type = '';
    el.classNames().each(function(c){ if(c.substr(0,1)=='_') type = c.substr(1); });
    var V;
    if( el.nodeName == 'SELECT' ) {
      V = this.trim( el.options[el.selectedIndex].value );
      f = true
    } else { 
      V = this.trim( el.value );
      f = this.valid( type, V );
    }
    el.style.backgroundColor = (V == '') ? ( req==1 ? this.nodata_req : this.nodata_opt ) : ( f==true ? this.data_valid : this.data_error );
  }, 
  on_submit: function( e ) { // On submitting form check the values
    var f = Event.element(e);
    var warnings = '';
    var X = this;
    f.getElements().each(function(el){ warnings += X.simple( el ); });
    if( warnings != "") {                     // If any warnings display them
      alert(warnings+"Correct these and try again");
      return Event.stop(e);
    } else {                                 // If conf is ZERO do nothing else call up confirm box..
      if( f.hasClassName( 'confirm' ) && !confirm("Check the values you entered are correct before continuing")) return Event.stop(e);
    }
  },
  add_label: function( code, name ) {
    this.labels[code]=name;
  }
});
function FormCheck_on_load() {
  var fc = new FormCheck();
  $$('.check').each(function(f){
    f.getElements().each(function(el){
      fc.check( el );
      el.observe( 'change', function (e) { fc.check(Event.element(e)); } );
      el.observe( 'keyup',  function (e) { fc.check(Event.element(e)); } );
    });
    f.observe('submit', function (e) { fc.on_submit(e); } );
  });
};
addLoadEvent(FormCheck_on_load);
