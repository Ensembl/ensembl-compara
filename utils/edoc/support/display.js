var this_method;

function toggle_method(method) {
  if ($(method).style.display == 'none') {
    display_method(method);
  } else {
    hide_method(method);
  }
}

function hide_method(method) {
  Effect.BlindUp(method);
  $(method + "_link").innerHTML = "View source";
}

function display_method(method) {
  this_method = method;
  var url = "/common/highlight_method/" + method;
  var data = "";
  var ajax_panel = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: code_loaded,
                           onLoading: code_loading
                         });
}

function code_loaded(response) {
  $(this_method).innerHTML = response.responseText;
  Effect.BlindDown(this_method);
  $(this_method + "_link").innerHTML = "Hide source";
}

function code_loading(response) {
} 
