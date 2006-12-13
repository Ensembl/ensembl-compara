var count = 0;

function populate_fragments() {
  var fragments = getElementsByClass("fragment");
  for (i = 0; i < fragments.length; i++) {
    fragment(fragments[i].innerHTML);
  }
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

  for (var j = 0; j < json.fragment.components.length; j++) {
    for (var element in json.fragment.components[j]) {
      html = html + unescape(json.fragment.components[j][element].html);
      start_px = json.fragment.components[j][element].start_px;
      end_px = json.fragment.components[j][element].end_px;
      start_bp = json.fragment.components[j][element].start_bp;
      end_bp = json.fragment.components[j][element].end_bp;
      start_cv = json.fragment.components[j][element].start_cv;
      end_cv = json.fragment.components[j][element].end_cv;
    }
  }

  if (json.error) {
    update.innerHTML = json.error;
  } else { 
    update.innerHTML = html;
  }

  update.style.display = 'block';
  count = count + 1;
  var prefix = "f_" + count; 

  $(json.fragment.id + "_title").innerHTML = json.fragment.title;

  var F = document.forms['panel_form'];
  F.appendChild(new_element(prefix + '_URL', '/Homo_sapiens/contigview?c=[[s]]:[[c]];w=[[w]]'));
  F.appendChild(new_element(prefix + '_bp_end', end_bp));
  F.appendChild(new_element(prefix + '_bp_start', start_bp));
  F.appendChild(new_element(prefix + '_flag', 'cv'));
  F.appendChild(new_element(prefix + '_px_end', end_px));
  F.appendChild(new_element(prefix + '_px_start', start_px));
  F.appendChild(new_element(prefix + '_visible', '1'));

  view_init(prefix);

  //draw_red_box('f', 1, 'p', 2);

  /**
  html = "";
  for (i = 0; i < json.fragment.components.length; i++) {
    for (var element in json.fragment.components[i]) {
      html = html + json.fragment.components[i][element].html;
      start_px = json.fragment.components[i][element].start_px;
      end_px = json.fragment.components[i][element].end_px;
      start_bp = json.fragment.components[i][element].start_bp;
      end_bp = json.fragment.components[i][element].end_bp;
      start_cv = json.fragment.components[i][element].start_cv;
      end_cv = json.fragment.components[i][element].end_cv;
    }
  }

  update = ego(json.fragment.id + "_update");
  if (json.error) {
    update.innerHTML = json.error;
  } else { 
    update.innerHTML = html;
  }
  update.style.display = 'block';
  title = ego(json.fragment.id + "_title");
  //hide_spinner(json.fragment.id);
  title.innerHTML = json.fragment.title;
  //alert(response.responseText);
  //alert(json.fragment.id);
  //init_view('f_1');
  //draw_single_red_box('f_1', start_cv, end_cv, start_bp, end_bp, start_px, end_px);
  //update_red_boxes();
  F = document.forms['panel_form'];
  F.appendChild(new_element('f_1_URL', '/Homo_sapiens/contigview?c=[[s]]:[[c]];w=[[w]]'));
  F.appendChild(new_element('f_1_bp_end', end_bp));
  F.appendChild(new_element('f_1_bp_start', start_bp));
  F.appendChild(new_element('f_1_flag', 'cv'));
  F.appendChild(new_element('f_1_px_end', end_px));
  F.appendChild(new_element('f_1_px_start', start_px));
  F.appendChild(new_element('f_1_visible', '1'));
  **/
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
