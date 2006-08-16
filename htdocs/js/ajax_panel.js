var id_to_update = "";

function toggle_panel(id, link) {

  var panel = document.getElementById(id);
  if (panel.style.display == "none") {
    if (id_to_update == "") {
      link.innerHTML = '<img src="/img/dd_menus/min-box.gif" width="16" height="16" alt="-" />';
      expand_panel(id);
    } else {
      panel.style.display = "block";
    }
  } else {
    link.innerHTML = '<img src="/img/dd_menus/plus-box.gif" width="16" height="16" alt="+" />';
    collapse_panel(id);
  } 

}

function collapse_panel(id) {
  var panel = document.getElementById(id);
  panel.style.display = "none";
}

function expand_panel(id) {
  var start = document.getElementById('p_2_bp_start');
  var chr = document.getElementById('chr');
  var end = document.getElementById('p_2_bp_end');
  var panel = document.getElementById(id);
  panel.style.display = "block";
  var url = "/Homo_sapiens/ajaxpanel";
  var data = "start=" + start.value + "&end=" + end.value + "&seqregion=" + chr.value; 
      data = data + "&panel_zoom=on";
  id_to_update = id;
  var panelContent = new Ajax.Request(url, 
                         {method: 'get', parameters: data, onComplete: panel_has_loaded, onLoading: panel_is_loading});
}

function panel_has_loaded(response) {
  $(id_to_update).innerHTML = response.responseText;
} 

function panel_is_loading(response) {
  $(id_to_update).innerHTML = "Loading...";
}
