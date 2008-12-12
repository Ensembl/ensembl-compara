var this_method;

function toggle_method(method) {
  if ($(method).style.display == 'none') {
    display_method(method);
  } else {
    hide_method(method);
  }
}

function hide_method(method) {
  $(method).hide();
  $(method + "_link").innerHTML = "View source";
}

function display_method(method) {
  this_method = method;
  var ajax_panel = new Ajax.Request("/common/highlight_method/" + method, { method: 'get', parameters: "", onComplete: code_loaded });
}

function code_loaded(response) {
  $(this_method).innerHTML = response.responseText;
  $(this_method).show();
  $(this_method + "_link").innerHTML = "Hide source";
}
