/*
ensFormElementControl.js

Browser-independent functions for manipulating form elements
(checkboxes, radio buttons, select lists etc)

Currently used by martview and blastview systems

*/
//----------------------------------------------------------------------
// Returns a 2 char string representing browser type
// ns for netscape 4 and earlier
// n6 for netscape 6 and later
// ie for IE
//
function getBrowser(){
  var bType;
  var b = navigator.appName;
  var v = parseInt( navigator.appVersion );
  var ns = false;
  var n6 = false;
  var ie = false;
  if( b=="Netscape" ){ 
    if( v > 4 ){ bType='n6' }
    else       { bType='ns' }      
  }
  else{ bType='ie' }
  return bType;
}

//----------------------------------------------------------------------
// Returns the value of the currently-selected radio
//
function radioValue( radioGrp ){
  for( var i=0; i<radioGrp.length; i++ ){
    if( radioGrp[i].checked == true ){
      if( radioGrp[i].disabled != true ){	    
        return radioGrp[i].value;
      }
    }
  }
  return;
}

//----------------------------------------------------------------------
// Returns the value of the (first) selected option of the selectGroup
//
function selectValue( selectGrp ){
  var idx = selectGrp.selectedIndex;
  if( idx < 0 ){ 
    idx = 0;
  }
  return selectGrp.options[idx].value;
}

//----------------------------------------------------------------------
// Returns an array of values of all selected options of the selectGroup
//
function selectValues( selectGrp ){
  var values = new Array();
  for( var i=0; i<selectGrp.length; i++ ){
    if( selectGrp[i].selected == true ){
      values.push( selectGrp[i].value );
    }
  }
  return values;
}

//----------------------------------------------------------------------
// Returns the value(s) of the currently-selected checkbox group
//
function checkboxValues( checkGrp ){
  var values = new Array();
  if( checkGrp.length ){ // List of checkboxes
    for( var i=0; i<checkGrp.length; i++ ){
      if( checkGrp[i].checked == true ){
        values.push( checkGrp[i].value );
      }
    }
  }
  else{ // Single checkbox
    if( checkGrp.checked == true ){
      values.push( checkGrp.value );
    }
  }
  return values;
}

//----------------------------------------------------------------------
// Disables the radio button of radioGrp identified by radioValue
// If this button is checked, code tries to check an alternative
// Does not work for Netscape <= 4
function disableRadio( radioGrp, radioValue ){
  if( getBrowser() == "ns" ){ return }
  var checkAnother = false;
  for( var i=0; i<radioGrp.length; i++ ){
    if( radioGrp[i].value == radioValue ){
      if( radioGrp[i].checked == true ){ checkAnother = true }
      radioGrp[i].disabled = true;
      break;
    }
  }
  if( checkAnother == true ){
    for( var i=0; i<radioGrp.length; i++ ){
      if( radioGrp[i].disabled == false ){
        radioGrp[i].checked = true;
        return;
      }
    }
  }
}

//----------------------------------------------------------------------
// Enables the radio button of radioGrp identified by radioValue
function enableRadio( radioGrp, radioValue, isChecked ){
  for( var i=0; i<radioGrp.length; i++ ){
    if( radioGrp[i].value == radioValue ){
      radioGrp[i].disabled = false;
      if( isChecked == true ){ radioGrp[i].checked = true }
      break;
    }
  }
}
//----------------------------------------------------------------------
// Disables the option selectGrp identified by selectValue
// If this button is checked, code tries to check an alternative
// Does not work for Netscape <= 4
// Does not work with IE!
function disableSelectOption( selectGrp, optionValue ){
  if( getBrowser() == "ns" ){ return }
  var selectAnother = false;
  for( var i=0; i<selectGrp.length; i++ ){
    if( selectGrp[i].value == optionValue ){
      if( selectGrp[i].selected == true ){ selectAnother = true }
      selectGrp[i].disabled = true;
      break;
    }
  }
  if( selectAnother == true ){
    for( var i=0; i<selectGrp.length; i++ ){
      if( selectGrp[i].disabled == false ){
        selectGrp[i].selected = true;
        return;
      }
    }
  }
}

//----------------------------------------------------------------------
// Enables the option of selectGrp identified by optionValue
// Does not work with IE!
function enableSelectOption( selectGrp, optionValue, isSelected ){
  for( var i=0; i<selectGrp.length; i++ ){
    if( selectGrp[i].value == optionValue ){
      selectGrp[i].disabled = false;
      if( isSelected == true ){ selectGrp[i].selected = true }
      break;
    }
  }
}
//----------------------------------------------------------------------
// resets the values of a select dropdown
function setSelectOptions( selectGrp, optValues, optLabels, optDefault ){
  // Get browser type
  var bType = getBrowser();

  // First check for explicit labels
  var genLabels;
  if( optLabels == undefined ){ 
    genLabels++;
    optLabels = new Array(); 
  }

  // Check for options
  if( optValues.length == 0 ){ 
    optValues[0] = 0;
    optLabels[0] = "---Unavailable---";
    optDefault   = 0;
  }

  // Check for labels, and create hash of values
  var optValuesHash = new Array();
  for( var i=0; i<optValues.length; i++ ){
    optValuesHash[optValues[i]] = 1;
    if( genLabels ){ optLabels[optValues[i]] = optValues[i] }
  }

  // Check for default
  if( optDefault == undefined ){ optDefault = optValues[0] }
  // Get the selected value from the options
  var optSelected;
  for( var i=0; i<selectGrp.options.length; i++ ){
    if( selectGrp.options[i].selected == true ){
      var val = selectGrp.options[i].value;
      if( optValuesHash[val] ){
        optSelected = val;
      }
    }
  }  
  if( optSelected == undefined ){ optSelected = optDefault }

  // Delete existing select options
  while( selectGrp.options.length > 0 ){
    selectGrp.options[0] = null;
  }

  // Assign new options
  var selIdx = 0;
  for( var i=0; i<optValues.length; i++ ){
    var val = optValues[i];
    var txt = optLabels[optValues[i]];
    var sel = false;
    if( val == optSelected ){ selIdx = i }
    if( bType == 'ns' ){
      selectGrp.options[i] = new Option( txt,val,sel,sel );
    }   
    else{
      var newElem = document.createElement("OPTION");
      newElem.text     = txt;
      newElem.value    = val;
      newElem.selected = sel;
      if( bType == 'ie' ){
        selectGrp.add( newElem );
      }
      else{
        selectGrp.add( newElem, null);
      }
    }
  }
  selectGrp.options[selIdx].selected = true;
}

//----------------------------------------------------------------------
// Returns the union of a set of arrays
function arrayUnion( arrayOfArrays ){

  // Single array; just return it's values
  if( arrayOfArrays.length == 1 ){ return arrayOfArrays[0] }

  // Multiple arrays (this algorithm is _inefficient_!)
  // Concatenate all arrays to form an uber-array
  // Sort the uber-array
  // Count the repeats
  // If the repeats equal the number of arrays, then value is union
  var tmpAry = new Array();
  for( var i=0; i<arrayOfArrays.length; i++ ){
    tmpAry = tmpAry.concat( arrayOfArrays[i] );
  }
  tmpAry.sort();
  var newAry = new Array();
  var last;
  var k=1;
  for( var i=0; i<tmpAry.length; i++ ){
    var topt = tmpAry[i];
    if( last == topt ){
      k++;
      if( k == arrayOfArrays.length ){
        newAry.push( topt );
      }
    }
    else{
      k=1;
      last = topt;
    }
  }
  return( newAry );
}

//----------------------------------------------------------------------
// Debug function. Should be empty
function debug(){
}
