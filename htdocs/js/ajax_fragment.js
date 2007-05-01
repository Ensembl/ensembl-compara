var ajax_call_count = 0;
var ajax_complete_count = 0;

function populate_info_fragments() {
  var fragments = getElementsByClass("fragment");
  for (i = 0; i < fragments.length; i++) {
    info_fragment(fragments[i].innerHTML);
    ajax_call_count = ajax_call_count + 1;
  }
}

function populate_fragments() {
  var fragments = getElementsByClass("fragment");
  for (i = 0; i < fragments.length; i++) {
    fragment(fragments[i].innerHTML);
    ajax_call_count = ajax_call_count + 1;
  }
}

function populate_trees() {;
  var fragments = getElementsByClass("fragment");
  for (i = 0; i < fragments.length; i++) {
    tree_fragment(fragments[i].innerHTML);
    ajax_call_count = ajax_call_count + 1;
  }
}

function ajax_call_complete() {
  ajax_complete_count = ajax_complete_count + 1;
  if (ajax_call_count == ajax_complete_count) {
    cv_draw_red_boxes( 1, ajax_complete_count + 1 )
  }
}

function info_fragment(caller) {
  //alert(caller);
  json = eval( '(' + caller + ')' );
  var data = "gene=" + json.fragment.stable_id+"&db=" +json.fragment.db;
  for (i = 0; i < json.components.length; i++) {
    data = data + "&component_" + i + "=" + json.components[i];
  }
  var url = "/" + json.fragment.species + "/populate_info_fragment";
  var ajax_panel = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: info_panel_loaded
                         });
}

function info_panel_loaded(r) {
  var response = eval( '(' + r.responseText + ')' );
  //alert(response.menu.width);
  $(response.component).innerHTML = unescape(response.html);
  $('loading').style.display = 'none';
  init_dropdown_menu();
}

function tree_fragment(caller) {
  //alert(caller);
  json = eval( '(' + caller + ')' );
  var data = "gene=" + json.fragment.stable_id;
  for (i = 0; i < json.components.length; i++) {
    data = data + "&component_" + i + "=" + json.components[i];
  }
  var url = "/" + json.fragment.species + "/populate_tree";
  var ajax_panel = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: tree_panel_loaded
                         });
}

function tree_panel_loaded(r) {
  var response = eval( '(' + r.responseText + ')' );
  //alert(response.menu.width);
  $(response.component).innerHTML = unescape(response.html);
  $('loading').style.display = 'none';
  init_dropdown_menu();
}

function fragment(caller) {
  URL = escape(document.location.href);
  json = eval( '(' + caller + ')' );
  var data = "code=" + json.fragment.code + "&id=" + json.fragment.id + "&";
  data = data + "title=" + json.fragment.title + "&";
  for (var j = 0; j < json.fragment.components.length; j++) {
    for (var element in json.fragment.components[j]) {
      data = data + "component_" + element + "=" + json.fragment.components[j][element] + "&";
    }
  }
  for (var j = 0; j < json.fragment.params.length; j++) {
    for (var element in json.fragment.params[j]) {
      data = data + element + "=" + json.fragment.params[j][element] + "&";
    }
  }

  for (var j = 0; j < json.fragment.options.length; j++) {
    for (var element in json.fragment.options[j]) {
      data = data + element + "=" + json.fragment.options[j][element] + "&";
    }
  }

  for (var j = 0; j < json.fragment.config_options.length; j++) {
    for (var element in json.fragment.config_options[j]) {
      data = data + element + "=" + json.fragment.config_options[j][element] + "&";
    }
  }

  data = data + "&url=" + URL;

  var url = "/" + json.fragment.species + "/populate_fragment";
  var ajax_panel = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: panel_loaded,
                           onLoading: panel_loading
                         });
}

function panel_loaded(response) {
  var json = eval( '(' + response.responseText + ')' );
  var html = "";
  var update = $(json.fragment.id + "_update");
  var update_menus = 0;
  var added = [];

  // Insert new HTML
  prepare_for_html(update, "");
  
  // Update page data for red boxes
  var URL_temp = '/Homo_sapiens/contigview?c=[[s]]:[[c]];w=[[w]]';
  var flag     = 'cv';
  for (var j = 0; j < json.fragment.components.length; j++) {
    for (var element in json.fragment.components[j]) {
      html = unescape(json.fragment.components[j][element].html);
      update.innerHTML = update.innerHTML + html;
    //  if (element == 'component_image_fragment') {
        start_px = json.fragment.components[j][element].start_px;
        end_px   = json.fragment.components[j][element].end_px;
        start_bp = json.fragment.components[j][element].start_bp;
        end_bp   = json.fragment.components[j][element].end_bp;
        start_cv = json.fragment.components[j][element].start_cv;
        end_cv   = json.fragment.components[j][element].end_cv;
        URL_temp = json.fragment.components[j][element].URL_temp;
        flag     = json.fragment.components[j][element].flag;
    //  }
      if (element == 'component_menu') {
        update_menus = 1;
      }
    }
  }

  update.style.display = 'block';
  display_html(update);
  var panel_number = parseInt(json.fragment.panel_number) + 1;
  var prefix = "p_" + panel_number; 

  $(json.fragment.id + "_title").innerHTML = json.fragment.title;

  if (update_menus == 1) {
    init_dropdown_menu();
  }

  var F = document.forms['panel_form'];
  F.appendChild(new_element(prefix + '_URL',      URL_temp ));
  F.appendChild(new_element(prefix + '_bp_end',   end_bp));
  F.appendChild(new_element(prefix + '_bp_start', start_bp));
  F.appendChild(new_element(prefix + '_flag',     flag ));
  F.appendChild(new_element(prefix + '_px_end',   end_px));
  F.appendChild(new_element(prefix + '_px_start', start_px));
  F.appendChild(new_element(prefix + '_visible',  '1'));

  view_init(prefix);

  ajax_call_complete();

}

function prepare_for_html(update, html) {
  //Effect.BlindUp(update);
  update.innerHTML = html;
}

function display_html(update) {
  //Effect.BlindDown(update); 
}

function new_element(name, value) {
  element = dce('input');
  sa(element, 'type', 'hidden');
  sa(element, 'name', name);
  sa(element, 'id', name);
  sa(element, 'value', value);
  return element;
}

function panel_loading(response) {
}

function toggle_fragment(name) {
  update = ego(name + "_update"); 
  if (update.style.display == "none") {
    display_fragment(name);
  } else {
    hide_fragment(name);
  }
}

function display_fragment(name) {
  toggle_box = ego(name + "_toggle");
  toggle_box.src = "/img/dd_menus/min-box.gif";
  update = ego(name + "_update");
  update.style.display = "block";
}

function hide_fragment(name) {
  toggle_box = ego(name + "_toggle");
  toggle_box.src = "/img/dd_menus/plus-box.gif";
  update = ego(name + "_update");
  update.style.display = "none";
}

function toggle_spinner(name) {
  spinner = ego(name + "_spinner"); 
  if (update.style.display == "none") {
    display_spinner(name);
  } else {
    hide_spinner(name);
  }
}

function display_spinner(name) {
  spinner = ego(name + "_spinner"); 
  spinner.style.display = "block";
}

function hide_spinner(name) {
  spinner = ego(name + "_spinner"); 
  spinner.style.display = "none";
}

function update_fragment(caller, params) {
  json = eval( '(' + params + ')' );
  alert(json.fragment);
}
