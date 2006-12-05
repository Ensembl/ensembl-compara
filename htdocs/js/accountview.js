var id_to_update;
var status_id;

var bookmark_label = "bookmark_";
var bookmark_name_label = "bookmark_name_";
var bookmark_editor_label = "bookmark_editor_";
var bookmark_manager_label = "bookmark_manage_";
var bookmark_editor_links_label = "bookmark_editor_links_";
var bookmark_editor_spinner_label = "bookmark_editor_spinner_";
var bookmark_text_field_label = "bookmark_text_field_";

function reallyDelete(id) {
  if (confirm("Are you sure you want to delete this group?")) { 
    document.getElementById('remove').submit();
  }
}

function hide_info(id) {
  Effect.Fade(id);
}

function toggle_group_settings(id) {
  if ($(element_name(id)).style.display == 'none') {
    show_group_settings(id);
  } else {
    hide_group_settings(id);
  }
}

function element_name(id) {
  return "group_" + id + "_settings";
}

function element_image(id) {
  return "group_" + id + "_image";
}

function show_group_settings(id) {
  new Effect.BlindDown(element_name(id));
  $(element_image(id)).src = "/img/minus.gif";
}

function hide_group_settings(id) {
  new Effect.BlindUp(element_name(id));
  $(element_image(id)).src = "/img/plus.gif";
}
