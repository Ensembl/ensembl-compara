var displayed_settings = new Array();
displayed_settings[0] = '';
displayed_settings[1] = 'user';

function reallyDelete(id) {
  if (confirm("Are you sure you want to delete this group?")) { 
    document.getElementById('remove').submit();
  }
}

function save_tab_change(tabview,element) {
  var url = "/common/user_tabs";
  var data = "tab=" + element + "&name=" + tabview;
  var ajax_info = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: tab_change_saved 
                         });
}

function tab_change_saved(response) {
}

function add_mix(ident) {
  var element;
  open = false;
  while (open == false) {
    element = "mixer_" + ident;
    if ($(element).style.display == "block") {
      ident = ident + 1;
    } else {
      $(element).style.display = "block";
      open = "true";
    }
  }
  add_to_display(ident);
}

function remove_mix(ident) {
  var element = "mixer_" + ident;
  $(element).style.display = "none"
  remove_from_display(ident);
}

function mixer_change(ident) {
  add_to_display(ident);
}

function add_to_display(ident) {
  var element = group_id_for_ident(ident);
  set_style_for_class(displayed_settings[ident], 'none');
  displayed_settings[ident] = (element);
  set_style_for_displayed_settings('block');
  save_mixer_settings();
}

function remove_from_display(ident) {
  set_style_for_class(displayed_settings[ident], 'none');
  displayed_settings[ident] = '';
  save_mixer_settings();
}

function set_style_for_displayed_settings(style) {
  for (var n = 0; n < displayed_settings.length; n++) {
    if (displayed_settings[n] != '') {
      set_style_for_class(displayed_settings[n], '');
    }
  }
}

function save_mixer_settings() {
  var url = "/common/mixer";
  var data = "settings=" + displayed_settings;
  var ajax_info = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: mixer_settings_saved 
                         });
}

function mixer_settings_saved(response) {
}

function group_id_for_ident(ident) {
  var element = "mixer_" + ident + "_select";
  return $(element).value;
}


function hide_info(id) {
  var data = "id=" + id;
  var url = "/common/hide_info";
  var ajax_info = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: info_is_hidden
                         });
  Effect.Fade(id);
}

function info_is_hidden(response) {
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
