function populate_fragments() {
  var fragments = getElementsByClass("fragment");
  for (i = 0; i < fragments.length; i++) {
    fragment(fragments[i].innerHTML);
  }
}

function fragment(caller) {
  json = eval( '(' + caller + ')' );
  var data = "id=" + json.fragment.id + "&";
  data = data + "title=" + json.fragment.title + "&";
  for (i = 0; i < json.fragment.components.length; i++) {
    for (var element in json.fragment.components[i]) {
      data = data + "component_" + element + "=" + json.fragment.components[i][element] + "&";
    }
  }
  for (i = 0; i < json.fragment.params.length; i++) {
    for (var element in json.fragment.params[i]) {
      data = data + element + "=" + json.fragment.params[i][element] + "&";
    }
  }

  var url = "/" + json.fragment.species + "/populate_fragment";
  var ajax_panel = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: panel_loaded,
                           onLoading: panel_loading
                         });
}

function panel_loaded(response) {
  json = eval( '(' + response.responseText + ')' );
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
  title.innerHTML = json.fragment.title;
  //alert(start_bp);
  //alert(end_bp);
  init_view('f_1');
  draw_single_red_box('f_1', start_cv, end_cv, start_bp, end_bp, start_px, end_px);
  update_red_boxes();
  F = document.forms['panel_form'];
  alert(F.elements.length);
  F.appendChild(new_element('f_1_URL', '/Homo_sapiens/contigview?c=[[s]]:[[c]];w=[[w]]'));
  F.appendChild(new_element('f_1_bp_end', end_bp));
  F.appendChild(new_element('f_1_bp_start', start_bp));
  F.appendChild(new_element('f_1_flag', 'cv'));
  F.appendChild(new_element('f_1_px_end', end_px));
  F.appendChild(new_element('f_1_px_start', start_px));
  F.appendChild(new_element('f_1_visible', '1'));
  alert(F.elements.length);
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

function getElementsByClass(searchClass,node,tag) {
	var classElements = new Array();
	if ( node == null )
		node = document;
	if ( tag == null )
		tag = '*';
	var els = node.getElementsByTagName(tag);
	var elsLen = els.length;
	var pattern = new RegExp('(^|\\s)'+searchClass+'(\\s|$)');
	for (i = 0, j = 0; i < elsLen; i++) {
		if ( pattern.test(els[i].className) ) {
			classElements[j] = els[i];
			j++;
		}
	}
	return classElements;
}
