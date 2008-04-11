var form_bgs = {nodata_req: '#fec',nodata_opt: '#fff',data_error: '#fcc',data_valid: '#cfc'};
function _trim(    s ) { return s.replace(/^(\s+)?(.*\S)(\s+)?$/, '$2'); }
function _isint(   s ) { return /^[-+]?\d+$/.test(s);               }
function _isfloat( s ) { return /^[-+]?(\d+\.\d+|\d+\.?|\.\d+)?([Ee][+-]?\d+)?$/.test(s); }
function _isemail( s ) { return /^[^@]+@[^@.:]+[:.][^@]+$/.test(s); }
function _isurl(   s ) { return /^https?:\/\/\w.*$/.test(s);        }
function _ispass(  s ) { return /^\S{6,32}$/.test(s);               }

function _valid( type, s ) {
  switch(type) {
    case 'Email'       : return _isemail(s);
    case 'URL'         : return _isurl(s);
    case 'Password'    : return _ispass(s);
    case 'NonNegInt'   : return _isint(s)   && parseInt(s)   >= 0; 
    case 'NonNegFloat' : return _isfloat(s) && parseFloat(s) >= 0;
    case 'PosInt'      : return _isint(s)   && parseInt(s)   >  0;
    case 'PosFloat'    : return _isfloat(s) && parseFloat(s) >  0;
    case 'Int'         : return _isint(s);
    case 'Float'       : return _isfloat(s);
    case 'Age'         : return _isint(s) && parseInt(s)>=0 && parseInt(s)<=150;
    default            : return 1;
  }
}
function os_check( type, element, req ) {
  V = _trim( element.value );
  if( type == 'selectrange' ) {
    V = _trim( element.options[element.selectedIndex].value );
    var a = req.split(',');
    req = a[0]; 
    min_range = a[1];
    max_range = a[2];
    f = _isint(V) && parseInt(V)>=min_range && parseInt(V)<=max_range;
  } else if( type == 'select' ) {
    V = _trim( element.options[element.selectedIndex].value );
    f = true
  } else { 
    f = _valid( type, V );
  }
  X = $( element.id );
  X.style.backgroundColor = form_bgs[ (V == '') ? ( req==1 ? 'nodata_req' : 'nodata_opt' ) : ( f==true ? 'data_valid' : 'data_error' ) ];
}

function on_load( list ) {
  list.each(function(el){
    if( $(el.form) ) {
      os_check( el.type, $(el.form).elements[el.element],el.req);
    }
  });
}

function form_obj( form, element, type, name, req ) {
  this.form = form;       /** Name of form **/
  this.element = element; /** Name of element in form **/
  this.type = type;       /** Type of element (used for validation) **/
  this.name  = name;      /** Label of element (used in warning messages) **/
  this.req = req;         /** Whether element is required - true/false flag  **/
}

function on_submit( list, conf ) {
  warning ="";                             /** Warning that will appear **/
  list.each(function(el){ /** iterate through all elements **/
    element = $(el.form).elements[el.element];
    tmpl = '';
    switch( el.type ) {
      case "selectrange":           /** All drop downs in the list to be checked are required!!! **/
        V = _trim( element.options[element.selectedIndex].value );
        var a = el.req.split(',');
        req = a[0];
        min_range = a[1];
        max_range = a[2];
        if( V == '' && req==1 ) { tmpl = "You must select a value for '####'"; }
        f = _isint(V) && parseInt(V)>=min_range && parseInt(V)<=max_range;
        if( V != '' && !f ) {
          tmpl = "The value for '####' is invalid.";
        }
        break;
      case "select" :
        V = _trim( element.options[element.selectedIndex].value );
        if( V == '' && el.req ) { tmpl = "You must select a value for '####'"; }
        break;
      default:
        value = element.value;
        if( el.req == 'match' ) {
          if( value != obj.value)        { tmpl = "The values of '####' do not match"; }
        } else {
          if( _trim( value ) == '' ) {       /** If required then check to see it isn't blank... **/
            if( el.req )                 { tmpl = "You must enter a value for '####'"; }
          } else {                           /** Now check the types of parameters - currently only email but could add URL... **/
            if( !_valid(el.type,value) ) { tmpl = "The value of '####' is invalid."; }
          }
        }
        break;
    }
    if( tmpl ) {
      warning += tmpl.replace(/####/, el.name )+"\n";
    }
  });
  if (warning != "") {                     /** If any warnings display them **/
    alert(warning+"Correct these and try again");
    return false;
  } else {                                 /** If conf is ZERO do nothing else call up confirm box.. **/
    if( conf ) {
      if( confirm("Check the values you entered are correct before continuing") ) {
        conf.value == 1;
        return true;
      } else {
        return false;
      }
    } else {
      return true;
    }
  }
}
