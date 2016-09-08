// $Revision: 1.3 $

Ensembl.Panel.TaxonSelector = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id);
    this.urlParam  = 's';
    this.dataUrl   = params.dataUrl;
    // this.dataUrl   = '/taxon_tree_data.js';
    this.taxonTreeData = null;
    this.isBlast   = params.isBlast ? true : false ;
    this.imagePath = '/i/species/48/';
    this.division_json = {};
    if (params.selectionLimit) this.selectionLimit = params.selectionLimit;
    if (params.defaultKeys)    this.defaultKeys    = params.defaultKeys;
    if (params.entryNode)      this.entryNode      = params.entryNode;
        
    Ensembl.EventManager.register('modalPanelResize', this, this.resize);
    //Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    },
  
  init: function () {
    var panel = this;  
    panel.base();
    panel.elLk.form   = $('form', panel.el);
    panel.elLk.tree   = $('.taxon_selector_tree .vscroll_container', panel.el);
    panel.elLk.list   = $('.taxon_selector_list .vscroll_container ul', panel.el);
    panel.elLk.mastertree   = $('.taxon_tree_master', panel.el);
    panel.elLk.finder = $('.finder input', panel.el);
    panel.elLk.divisions = $('.species_division_buttons', panel.el);
    panel.elLk.breadcrumbs = $('.ss_breadcrumbs', panel.el);

    // override the default modal close handler
    if (this.isBlast) {
      $('.modal_close').unbind().bind('click', function () { 
        Ensembl.EventManager.trigger('modalClose', true);
        return panel.updateConfigurationBLAST();
      });
    } else {
      $('.modal_close').unbind().bind('click', function () { 
        return panel.updateConfiguration() 
      }); 
    }

    // FETCH TAXON DATA
    // This uses a $.getScript() instead of $.getJSON() because Firefox 3.x on KDE/Linux 
    // chokes when parsing the deeply nested JSON structure, giving the error: 
    // "InternalError: script stack space quota is exhausted".
    $(document).ajaxError(function(e, request, settings, exception){ alert(exception) });
    $.ajax({
      url: panel.dataUrl,
      async: false,
      dataType: 'JSON',
      success: function(data) {
        panel.taxonTreeData = data.json[0];
        panel.initAutoComplete();
        // Create initial breadcrumb (All division)
        panel.addBreadcrumbs();
        panel.createMenu(panel.taxonTreeData.children);
        // Populate default selected species on panel open
        panel.populateDefaultSpecies();
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.log('Error loading json: ', errorThrown);
        panel.elLk.tree.html('Couldn\'t load species tree');
      }
    });

    panel.resize();  
  },

  createMenu: function(arr) {
    var panel = this;
    var menu_arr = [];

    $.each(arr, function(i, child) {
      var a = $('<a/>', {
        class: 'division_button btn',
        text: child.title,
      });

      $(a).on('click', function(){
        var node = panel.getTree($(this).html(), panel.taxonTreeData);
        panel.addBreadcrumbs(node.title);
        if (child.is_submenu) {
          if (child.children) {
            panel.createMenu(child.children);
            panel.removeTree();
          }
        }
        else {
          panel.highlightElement(this);
          panel.displayTree(node.title, true);
        }
      });
      menu_arr.push(a);
    });
    panel.elLk.divisions.html(menu_arr);
  },

  highlightElement: function(ele) {
    $(ele).siblings().removeClass('active');
    $(ele).addClass('active');
  },

  addBreadcrumbs: function(key) {
    var panel = this;
    var node = panel.taxonTreeData;
    var breadcrumbs_li = [];
    // Get path
    var path = key && key !== 'All Divisions' ? panel.getPath(key, node) : node.title;
    var highlight = false;
    if (path) {
      path = path.split(',');
      $.each(path, function(i, val) {
        // Always highlight the last li
        highlight = (i === path.length - 1) ? true : false;
        breadcrumbs_li.push(panel.createListElement(val, highlight));
      });
    }
    panel.elLk.breadcrumbs.html(breadcrumbs_li);
  },

  getPath: function(key, node) {
    var path = "";
    var search = function(path, obj, target) {
      for (var k in obj) {
        if (obj.hasOwnProperty(k)) {

          if (obj[k].title === target) {
            if(obj[k].is_submenu) {
              return path + obj[k].title;
            }
            else {
              return path;
            }
          }
          else if (typeof obj[k] === "object") {
            if(obj.title) {
              path += obj.title + ",";
            }
            var result = search(path, obj[k], target);
            if (result)
              return result;
          }
        }
      }
      return false;
    }

    var path = search(path, node, key);
    path = path && path.replace(/(,$)/g, "")
    return path;
  },

  createListElement: function(li_text, highlight) {
    var panel = this;    
    var li = $('<li/>', {
      class: highlight ? 'active' : '',
    });

    var a = $('<a/>', {
      text: li_text,
      href: 'javascript:void(0);'
    }).appendTo(li);

    $(li).on('click', function() {
      var node = panel.getTree(li_text, panel.taxonTreeData);
      if (node.children) {
        panel.addBreadcrumbs(li_text);
        panel.removeTree();
        panel.createMenu(node.children);
      }
      else {
        panel.displayTree(node, true);
      }
    });
    return li;
  },

  initAutoComplete: function() {
    var panel = this;
    // AUTOCOMPLETE
    // Create a hidden dynatree with all nodes for search purpose
    panel.elLk.mastertree.dynatree({
      children: [panel.taxonTreeData]
    });

    panel.elLk.mastertree.hide();
    
    // get autocomplete data from tree
    var acTitles = [];
    var acKeys = [];

    panel.elLk.mastertree.dynatree("getRoot").visit(function(node){
      var search_text = node.data.title + ' (' + node.data.key + ')';
      acTitles.push(search_text);
      acKeys[node.data.title] = node.data.key;
      acKeys[node.data.key] = node.data.key;
    });
    
    var finder = panel.elLk.finder;
    finder.autocomplete({
      minLength: 3,
      classes: {
        "ui-autocomplete": "ss-autocomplete"
      },
      source: function(request, response) { response(panel.filterArray($.unique(acTitles), request.term)) }, 
      select: function(event, ui) {
        var isLeaf = panel.locateNode(acKeys[ui.item.value]);
        isLeaf && finder.val('');
      },
      open: function(event, ui) { $('.ui-menu').css('z-index', 999999999 + 1) } // force menu above modal
    }).focus(function(){ 
      // add placeholder text
      if($(this).val() == $(this).attr('title')) {
        finder.val('');
        finder.removeClass('inactive');
      } else if($(this).val() != '')  {
        finder.autocomplete('search');
      }
    }).blur(function(){
      // remove placeholder text
      finder.removeClass('invalid');
      finder.addClass('inactive');
      finder.val($(this).attr('title'));
    }).keyup(function(){
      // highlight invalid search strings
      if (finder.val().length >= 3) {
        var matches = panel.filterArray(acTitles, finder.val());
        if (matches && matches.length) {
          finder.removeClass('invalid');
        } else {
          finder.addClass('invalid');
        }
      } else {
       finder.removeClass('invalid');
      }
    }).data("ui-autocomplete")._renderItem = function (ul, item) {
      ul.addClass('ss-autocomplete');
      // highlight the term within each match
      var regex = new RegExp("(?![^&;]+;)(?!<[^<>]*)(" + $.ui.autocomplete.escapeRegex(this.term) + ")(?![^<>]*>)(?![^&;]+;)", "gi");
      item.label = item.label.replace(regex, "<span class='ss-ac-highlight'>$1</span>");
      return $("<li/>").data("ui-autocomplete-item", item).addClass('ss-ac-result-li').append("<a class='ss-ac-result'>" + item.label + "</a>").appendTo(ul);
    };
  },

  removeTree: function() {
    var panel = this;
    $(panel.elLk.tree).children().remove();
  },

  displayTree: function(taxon_key, locate) {
    var panel = this;
    var taxon_tree = panel.elLk.mastertree.dynatree("getTree").getNodeInTree(taxon_key);
    // TREE

    if (!taxon_tree || !taxon_tree.data.isFolder) { 
      console.log('master tree is null');
      return;
    }
    panel.elLk.tree.dynatree({
      // initAjax: {url: panel.dataUrl},
      children: [taxon_tree.toDict(true)],
      imagePath: panel.imagePath,
      checkbox: true,
      selectMode: 3,
      activeVisible: true,
      onSelect: function(flag, node) { panel.setSelection(flag, node) },
      onDblClick: function(node, event) { node.toggleSelect() },
      onKeydown: function(node, event) {
        if( event.which == 32 ) {
          node.toggleSelect();
          return false;
        }
      }
    });

    locate && panel.locateNode(taxon_key);
  },

  populateDefaultSpecies: function() {
    var panel = this;
    // Populate default selected species
    var treeObj = panel.elLk.mastertree.dynatree("getTree");
    if (panel.defaultKeys && panel.defaultKeys.length > 0) {
      // set selected nodes
      $.each(panel.defaultKeys, function(index, key) { 
        var node = treeObj.getNodeByKey(key);
        if (node) {
          node.select();      // tick it
          node.makeVisible(); // force parent path to be expanded
          panel.setSelection(true, node)
        }
      });

      // panel.locateNode(panel.defaultKeys[0])
    }
  },

  getTree: function(key, node) {
    var panel = this;
    
    var getTree = function(key, node, submenu) {

      if (node.title === key) {
        return node.isInternalNode ? node : true;
      }
      if (node.isFolder) {
        if (node.isInternalNode) {
          submenu = node;
        }

        for (var i in node.children) {
          var child = getTree(key, node.children[i], submenu);
          if (child) {
            return child === true ? submenu : child;
          }
        }
      }
      return false;
    };

    return getTree(key, node, node);
  },

  resize: function () {
    var newHeight = $(this.el).height() - 50;
    this.elLk.tree.parent('.content').height(newHeight);
    this.elLk.list.closest('.vscroll_container').height(newHeight - 40);      
  },
  
  getSelectedItems: function(tree = this.elLk.mastertree, preserveOrder) {
    var selectedNodes = tree.dynatree("getTree").getSelectedNodes();
    var items = $.map(selectedNodes, function(node){
      return node.data.isFolder ? null : {key: node.data.key, title: node.data.title, icon: node.data.icon};
    });
    if (!preserveOrder) {
      items.sort(function (a, b) {return a.title.toLowerCase().localeCompare(b.title.toLowerCase())});
    }
    return items;
  },
  
  setSelection: function(flag, node) {
    var panel = this;
    var items = [];
    // Get selected items from displayed subtree
    if(node.hasChildren()) {
      // If selected node is an internal node then get all its children
      items = node.getChildren();
    }
    else {
      // If a single node is selected, directly get the data from it
      items.push(node);
    }

    // Update mastertree according to the flag true/false = select/deselect
    $.each(items, function(index, item){
      panel.elLk.mastertree.dynatree("getTree").selectKey(item.data.key, flag);
    });

    // Remove current list
    $('li', panel.elLk.list).remove();

    var all_selected_items = panel.getSelectedItems(this.elLk.mastertree);
    $.each(all_selected_items, function(index, item){
      item.img_url = panel.imagePath + item.key + '.png';
      var species_img = item.img_url ? '<span class="selected-sp-img"><img src="'+ item.img_url +'"></span>' : '';
      var li = $('<li>' + species_img + '<span class="selected-sp-title">' + item.title + '</span><span class="remove"></span></li>').appendTo(panel.elLk.list);
      $('.remove', li).click(function(){panel.removeListItem($(this).parent())});
    });
  },
  
  locateNode: function(key) {
    var panel = this;
    var mastertree_node = panel.elLk.mastertree.dynatree("getTree").getNodeInTree(key);

    if (!mastertree_node.data.isFolder) {
      panel.setSelection(true, mastertree_node);
      return true;
    }

    var tree = panel.getTree(mastertree_node.data.title, panel.taxonTreeData);

    if (panel.elLk.tree.html()) {
      panel.displayTree(tree.title);
    }
    var node = panel.elLk.tree.dynatree("getTree").getNodeInTree(key);
    if (node) { 
      node.activate();
      // node.li.scrollIntoView();
    }
  },
  
  removeListItem: function(li) {
    var panel = this;
    var title = li.text();
    var selectedNodes = [];
    if (panel.elLk.tree.children().length) {
      selectedNodes = panel.elLk.tree.dynatree("getTree").getSelectedNodes();
    }
    else {
      selectedNodes = panel.elLk.mastertree.dynatree("getTree").getSelectedNodes();
    }
    
    if (selectedNodes.length <= 1) {
      panel.removeTree();
    }
    $.each(selectedNodes, function(index, node) {
      if (node.data.title == title) {
        node.toggleSelect();
        $(li).remove();
        return;
      }
    });
  },
  
  filterArray: function(array, term) {
    term = term.replace(/[^a-zA-Z0-9 ]/g, '').toUpperCase();
    var matcher = new RegExp( $.ui.autocomplete.escapeRegex(term), "i" );
    var matches = $.grep( array, function(value) {
      return value && matcher.test( value.replace(/[^a-zA-Z0-9 ]/g, '') );
    });
    matches.sort(function(a, b) {
      // give priority to matches that begin with the term
      var aBegins = a.toUpperCase().substr(0, term.length) == term;
      var bBegins = b.toUpperCase().substr(0, term.length) == term;
      if (aBegins == bBegins) {
        if (a == b) return 0;
        return a < b ? -1 : 1;
      }
      return aBegins ? -1 : 1;
    });
    return matches;   
  },   
  
  updateConfigurationBLAST: function() {
        var panel = this;
    var items = panel.getSelectedItems(this.elLk.mastertree);
    // if (panel.selectionLimit && items.length > panel.selectionLimit) {
    //     alert('Too many items selected.\nPlease select a maximum of ' + panel.selectionLimit + ' items.');
    //     return false;
    // } else {
        Ensembl.EventManager.trigger('updateTaxonSelection', items);
        return true;
    // }
  },
  
  updateConfiguration: function() {
    var panel = this;
    var items = panel.getSelectedItems(this.elLk.mastertree);

    if (panel.selectionLimit && items.length > panel.selectionLimit) {
    
      alert('Too many items selected.\nPlease select a maximum of ' + panel.selectionLimit + ' items.');
      return false;
    
    } else {     
      var html = '';
      for (var i = 0; i < items.length; i++) {
        html += '<input type="hidden" name="' + this.urlParam + '" value="' + items[i].key + '" />';
      }
      $(html).appendTo(this.elLk.form);
      this.elLk.form.submit();      
      alert('updating form')
      return true;
    }
  }

});

