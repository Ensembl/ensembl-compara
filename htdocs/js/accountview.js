var id_to_update;
var status_id;

var bookmark_label = "bookmark_";
var bookmark_name_label = "bookmark_name_";
var bookmark_editor_label = "bookmark_editor_";
var bookmark_manager_label = "bookmark_manage_";
var bookmark_editor_links_label = "bookmark_editor_links_";
var bookmark_editor_spinner_label = "bookmark_editor_spinner_";
var bookmark_text_field_label = "bookmark_text_field_";

function show_inplace_editor(id) {
  var form_to_show = document.getElementById(bookmark_editor_label + id);
  var link_to_hide = document.getElementById(bookmark_label + id);
  form_to_show.style.display = 'inline';
  link_to_hide.style.display = 'none';
}

function hide_inplace_editor(id) {
  var form_to_show = document.getElementById(bookmark_editor_label + id);
  var link_to_hide = document.getElementById(bookmark_label + id);
  form_to_show.style.display = 'none';
  link_to_hide.style.display = 'block';
}

function delete_bookmark(id, bookmark_id, user_id) {

  $(bookmark_editor_links_label + id).style.display = 'none';
  $(bookmark_editor_spinner_label + id).style.display = 'inline';

  id_to_update = id;
  var url = "/common/manage_bookmark";
  var data = "bookmark=" + bookmark_id + "&user=" + user_id + "&action=delete";

  var panelContent = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: delete_response_received,
                         });
}

function save_bookmark(id, bookmark_id, user_id) {

  $(bookmark_editor_links_label + id).style.display = 'none';
  $(bookmark_editor_spinner_label + id).style.display = 'inline';

  id_to_update = id;
  var url = "/common/manage_bookmark";
  var data = "bookmark=" + bookmark_id + "&user=" + user_id + "&name=" + $(bookmark_text_field_label + id).value + "&action=update";

  var panelContent = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: response_received,
                         });
}

function response_received(response) {
  $(bookmark_name_label + id_to_update).innerHTML = response.responseText;
  hide_inplace_editor(id_to_update);
  $(bookmark_text_field_label + id_to_update).value = response.responseText;
  $(bookmark_editor_links_label + id_to_update).style.display = 'inline';
  $(bookmark_editor_spinner_label + id_to_update).style.display = 'none';
}

function delete_response_received(response) {
  $(bookmark_label + id_to_update).style.display = "none";
  $(bookmark_editor_label + id_to_update).style.display = "none";
}

function show_manage_links(id) {
  var id_to_show = document.getElementById(id);
  id_to_show.style.display = 'inline';
}

function hide_manage_links(id) {
  var id_to_hide = document.getElementById(id);
  id_to_hide.style.display = 'none';
}
