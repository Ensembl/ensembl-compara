// $Revision: 1.3 $

Ensembl.Panel.TaxonSelector = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id);
    this.dataUrl        = params.dataUrl;
    this.taxonTreeData  = null;
    this.imagePath      = Ensembl.speciesImagePath;
    this.lastSelected   = null;
    this.activeTreeKey  = '';
    this.selectionLimit = params.selectionLimit;
    this.defaultSpecies    = new Array();
    this.multiHash      = {};

    if (params.defaultSpecies)  this.defaultSpecies     = params.defaultSpecies;
    if (params.referer_action)  this.referer_action  = params.referer_action;
    if (params.referer_type)    this.referer_type    = params.referer_type;
    if (params.allOptions)      this.allOptions      = params.allOptions;
    if (params.includedOptions) this.includedOptions = params.includedOptions;
    if (params.multiselect)     this.multiSelect     = parseInt(params.multiselect);
    if (params.align)           this.alignId         = params.align;
    if (params.alignLabel)      this.alignLabel      = params.alignLabel.replace(/\s/g, '_');
    this.isCompara = (this.referer_action === 'Compara_Alignments');
    Ensembl.EventManager.register('modalPanelResize', this, this.resize);
  },
  
  init: function () {
    var panel = this;
    panel.base();
    panel.elLk.form       = $('form', panel.el);
    panel.elLk.tree       = $('.taxon_selector_tree .vscroll_container', panel.el);
    panel.elLk.list       = $('.taxon_selector_list .vscroll_container ul', panel.el);
    panel.elLk.buttons    = $('.ss-buttons', panel.el);
    panel.elLk.mastertree = $('.taxon_tree_master', panel.el);
    panel.elLk.finder     = $('.finder input', panel.el);
    panel.elLk.divisions  = $('.species_division_buttons', panel.el);
    panel.elLk.breadcrumbs= $('.ss_breadcrumbs', panel.el);
    panel.elLk.count      = $('.taxon_selector_list .ss-count', panel.el);
    panel.elLk.msg        = $('.ss-msg span', panel.el);

    panel.elLk.finder.focus();
    // override the default modal close handler
    $('.modal_close').hide();
    $('.modal_close').unbind().bind('click', function () { 
      Ensembl.EventManager.trigger('modalClose', true);
      return panel.updateConfiguration();
    });

    $('#ss-reset', panel.elLk.buttons).click(function() {
      return panel.resetConfiguration();
    });

    $('#ss-cancel', panel.elLk.buttons).click(function() {
      Ensembl.EventManager.trigger('modalClose', true);
    });

    $('#ss-submit', panel.elLk.buttons).click(function() {
      Ensembl.EventManager.trigger('modalClose', true);
      return panel.updateConfiguration();
    });

    // FETCH TAXON DATA
    // This uses a $.getScript() instead of $.getJSON() because Firefox 3.x on KDE/Linux 
    // chokes when parsing the deeply nested JSON structure, giving the error: 
    // "InternalError: script stack space quota is exhausted".
    $(document).ajaxError(function(e, request, settings, exception){ console.log(exception) });
    $.ajax({
      url: panel.dataUrl,
      async: false,
      dataType: 'JSON',
      success: function(data) {
        if (data.json[0]) {
          panel.taxonTreeData = data.json[0];
          panel.initialize();
        }
      },
      error: function(jqXHR, textStatus, errorThrown) {
        console.log('Error loading json: ', errorThrown);
        panel.elLk.tree.html('Couldn\'t load species tree');
      }
    });

    panel.resize();
    panel.updateCount();
  },

  updateCount: function() {
    var panel = this;
    panel.elLk.count.html(panel.getCurrentSelectionCount());
    panel.elLk.count.removeClass('warn');

    var curr_count = panel.getCurrentSelectionCount();
    if (curr_count == 0) {
      panel.disableButton(true);
      return false;
    }
    if (panel.selectionLimit && curr_count > panel.selectionLimit) {
      panel.elLk.msg.html('Selection limit of ' + panel.selectionLimit + ' species exeeded!')
                    .show();
      panel.elLk.count.addClass('warn');
      panel.disableButton(true);
      return false;
    }else {
      panel.elLk.msg.hide();
    }

    panel.disableButton(false);
  },

  resetConfiguration: function() {
    var panel = this;
    panel.initialize();
  },

  getCurrentSelectionCount: function() {
    return $('li', this.elLk.list).length || 0;
  },

  initialize: function() {
    var panel = this;
    this.elLk.tree.html('');
    this.elLk.list.html('');
    this.updateCount();
    if (this.taxonTreeData) {
      this.initAutoComplete();
      // Create initial breadcrumb (All division)
      this.addBreadcrumbs();
      this.createMenu(this.taxonTreeData.children);
      // Populate default selected species on panel open
      this.defaultSpecies && this.populateDefaultSpecies();
      this.isCompara && this.createMultipleAlignmentsHash();
    }

    this.elLk.list.sortable({
      containment: this.elLk.list.parent(),
      start: function(event, ui) {
        $(ui.item).addClass('ss-drag-active')
      },
      stop: function(event, ui) {
        $(ui.item).removeClass('ss-drag-active')
        panel.startSort();
      }
    });
  },

  createMultipleAlignmentsHash: function() {
    var panel = this;
    this.multiHash = {};

    $.each(this.taxonTreeData.children, function(i, m) {
      if (m.key === 'Multiple') {
        $.each(m.children, function(i, c) {
          panel.multiHash[c.key] = {};
          $.each(c.children, function(i, item) {
            panel.multiHash[c.key][item.key] = 'yes';
          });
        });
      }
    });
  },

  updateMultipleAlignmentsHash: function (node, flag) {
    var panel = this;
    var sel = !flag ? 'yes' : 'off';
    this.multiHash[node.parent.data.key] = !this.multiHash[node.parent.data.key] && {};
    this.multiHash[node.parent.data.key][node.data.key] = sel;
  },

  startSort: function() {
    return true;
  },

  createMenu: function(arr, highlight_title) {
    var panel = this;
    var menu_arr = [];

    $.each(arr, function(i, child) {
      var hl_class = '';
      if (child.title === highlight_title) {
        hl_class = 'active'
      }
      var a = $('<a/>', {
        'class': 'division_button btn ' + hl_class,
        text: child.title
      });

      $(a).off().on('click', function(){
        var node = panel.elLk.mastertree.dynatree("getTree").getNodeInTree(child.key);
        // Crate breadcrumbs if node has submenu in it
        node.data.is_submenu && panel.addBreadcrumbs(node);
        if (child.is_submenu) {
          if (child.children) {
            panel.createMenu(child.children);
            panel.hideTree();
          }
        }
        else {
          panel.highlightElement(this);
          panel.displayTree(node.data.title, true);
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

  addBreadcrumbs: function(node) {
    var panel = this;

    if (!node) {
      node = panel.elLk.mastertree.dynatree("getRoot").getChildren()[0];
      if (!node) return;
    }

    var breadcrumbs_li = [];
    // Get path
    var path = node.getKeyPath(false, 'key');
    var highlight = false;
    if (path) {
      path = path.split('/');
      $.each(path, function(i, val) {
        // Always highlight the last li
        if (val) {
          highlight = (i === path.length - 1 ) ? true : false;
          breadcrumbs_li.push(panel.createListElement(val, highlight));
        }
      });
    }
    panel.elLk.breadcrumbs.html(breadcrumbs_li);
  },

  getPath: function(node) {
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

  createListElement: function(key, highlight) {
    var panel = this;
    var li = $('<li/>', {
      'class': highlight ? 'active' : ''
    });

    var node = panel.elLk.mastertree.dynatree("getTree").getNodeInTree(key);

    var a = $('<a/>', {
      text: node.data.title,
      href: 'javascript:void(0);'
    }).appendTo(li);

    $(li).on('click', function() {
      if (node.data.children) {
        panel.addBreadcrumbs(node);
        panel.hideTree();
        panel.createMenu(node.data.children);
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
      // var search_text = node.data.isFolder ? node.data.title : node.data.title + ' (' + node.data.key + ')';
      // acTitles.push(search_text);

      // Exclude submenu on search as a quick fix
      if (!node.data.is_submenu && node.data.searchable) {
        var search_text = '';
        if (node.data.isFolder) {
          search_text = node.data.title;
        }
        else {
          if (node.data.title === node.data.key) {
            search_text = node.data.title;
          }
          else {
            search_text = node.data.title + ' (' + node.data.key + ')';
          }
        }

        acTitles.push(search_text);
        // acTitles.push(node.data.title);
        // acTitles.push(node.data.key);
        acKeys[search_text] = {
          key: node.data.key,
          multi: node.parent.data.key === 'Multiple'
        };
        acKeys[node.data.key] = {
          key: node.data.key,
          multi: node.parent.data.key === 'Multiple'
        };
      }
    });
    
    var finder = panel.elLk.finder;
    finder.autocomplete({
      minLength: 3,
      classes: {
        "ui-autocomplete": "ss-autocomplete"
      },
      source: function(request, response) { response(panel.filterArray($.unique(acTitles), request.term)) }, 
      select: function(event, ui) {
        // Reload Dynatree so that the tree is reloaded (checkbox reset) on selecting a multi node via search
        acKeys[ui.item.value].multi && panel.elLk.mastertree.dynatree('getTree').reload();
        panel.locateNode(acKeys[ui.item.value].key, panel.activeTreeKey === 'Multiple');

        if (!panel.multiSelect) {
          var node = panel.elLk.tree.dynatree("getTree").getSelectedNodes();
          if (node.length && panel.activeTreeKey !== 'Multiple') {
            panel.lastSelected = node[0];
          }
        }
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

  hideTree: function() {
    var panel = this;
    $(panel.elLk.tree).children().hide();
  },

  displayTree: function(taxon_key, locate) {
    var panel = this;
    var taxon_tree = panel.elLk.mastertree.dynatree("getTree").getNodeInTree(taxon_key);
    // TREE

    if (!taxon_tree || !taxon_tree.data.isFolder) { 
      console.log('master tree is null');
      return;
    }

    var mode = ((panel.isCompara && taxon_key !== 'Multiple') || (!panel.isCompara && !this.multiSelect)) ? 1 : 3;
    panel.elLk.tree.dynatree({
      // initAjax: {url: panel.dataUrl},
      children: [taxon_tree.toDict(true)],
      imagePath: panel.imagePath,
      checkbox: true,
      selectMode: mode,
      activeVisible: true,
      onSelect: function(flag, node) {

        if (panel.isCompara && taxon_key === 'Multiple') {
          var alignment_selected;
          // Select Multiple alignment label node as alignment_selected.
          if (!node.data.isFolder && node.parent.data.key !== 'Multiple') {
            alignment_selected = node.parent;
            panel.updateMultipleAlignmentsHash(node, flag);
          }
          else {
            alignment_selected = node;
          }

          if (panel.lastSelected && panel.lastSelected.data &&
              panel.lastSelected.data.key !== alignment_selected.data.key) {
              panel.setSelection(node, flag, true, true);
          }
          else {
            panel.setSelection(node, flag);
          }

          panel.lastSelected = alignment_selected;
          return;
        }
        else if (!panel.multiSelect) {
          // Update last selected item for single select
          panel.lastSelected = flag ? node : null;
          panel.setSelection(node, flag, true, true);
          return;
        }

        panel.disableButton(!flag);
        panel.setSelection(node, flag);
      },
      onDblClick: function(node, event) { node.toggleSelect() },
      onKeydown: function(node, event) {
        if( event.which == 32 ) {
          node.toggleSelect();
          return false;
        }
      }
    });

    this.activeTreeKey = taxon_key;
    // locate && panel.locateNode(taxon_key);
  },

  populateDefaultSpecies: function() {
    var panel = this;
    // Populate default selected species
    var treeObj = panel.elLk.mastertree.dynatree("getTree");
    var multipleAlign = panel.isCompara && panel.alignLabel;
    var node;
    var species; // Species to locate and show by default

    if (panel.defaultSpecies && panel.defaultSpecies.length > 0) {
      // set selected nodes
      $.each(panel.defaultSpecies.reverse(), function(index, _key) { 
        node = treeObj.getNodeByKey(_key);
        species = _key;
        if (!node) {
          sp = _key.match(/(.*)--\w+$/);
          if (sp && sp[1]) {
            node = treeObj.getNodeInTree(sp[1]);
            species = sp[1];
          }
        }

        if (node) {
          node.select();      // tick it
          !multipleAlign && node.makeVisible(); // force parent path to be expanded
          panel.setSelection(node, true);
          panel.lastSelected = (panel.isCompara && panel.alignLabel) ? treeObj.getNodeByKey(panel.alignLabel) : node;
        }
      });

      // Locate multiple alignment with label instead of species name as one species may be found in different EPO alignments
      multipleAlign ? panel.locateNode(panel.alignLabel) : panel.locateNode(species);
    }
  },

  getTree: function(node, type) {
    var panel = this;

    type = type || 'isInternalNode';

    while (node.parent) {
      if (node.data[type]) {
        return node;
      }
      node = node.parent;
    }

    return false;
  },

  getNodeFromTaxonTree: function(key, node) {
    var panel = this;
    
    var getTree = function(key, node, submenu) {

      if (node.key === key) {
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
    var newHeight = $(this.el).height() - 80;
    this.elLk.tree.parent('.content').height(newHeight);
    this.elLk.list.closest('.vscroll_container').height(newHeight - 29);
  },
  
  getSelectedItems: function(tree) {

    if (!tree) {
      tree = this.elLk.mastertree;
    }
    var selectedNodes = this.elLk.mastertree.dynatree("getTree").getSelectedNodes();
    var items = new Array();
    var items_hash = {};
    $.each(selectedNodes, function(i, node) {
      if (!node.data.isFolder) {
        items_hash[node.data.title] = {
          key   : node.data.key,
          title : node.data.title,
          img_url  : node.data.img_url,
          value : node.data.value
        };
      }
    });

    $.each($('li', this.elLk.list), function(i, li) {
      items.push(items_hash[$('.selected-sp-title', this).text()]);
    });

    return items;
  },
  
  getAllLeaves: function(node) {
    var results = [];
    function getAllLeaves(node) {
      if (!!node.childList) {
        for (var child in node.childList) {
          getAllLeaves(node.childList[child]);
        }
      } else {
        if (node.data.unselectable !== 1) {
          results[results.length] = node;
        }
      }
      return results;
    }
    return getAllLeaves(node);
  },

  setSelection: function(node, flag, resetMasterTree, resetSelectedList) {
    var panel = this;
    var items = new Array();

    // Get selected items from displayed subtree
    if(node.hasChildren()) {
      // If selected node is an internal node then get all its children
      items = panel.getAllLeaves(node);
    }
    else {
      // If a single node is selected, directly get the data from it
      items.push(node);
    }

    if (resetMasterTree) {
      if (panel.isCompara && panel.activeTreeKey === 'Multiple') {
        panel.elLk.mastertree.dynatree('getTree').visit(function(node) {
          node && node.select(false)
        });
        panel.elLk.tree.dynatree("getTree").visit(function(node) {
          node && node.select(false)
        })
        // Select the checkbox after resetting all only if it is multiple alignment
        node.select(flag);
      }
      else {
        panel.elLk.mastertree.dynatree('getTree').reload();
      }
    }

    resetSelectedList && panel.elLk.list.children().remove();

    $.each(items, function(index, item){
      // Update mastertree according to the flag true/false = select/deselect
      panel.elLk.mastertree.dynatree("getTree").selectKey(item.data.key, flag);
      if (flag) {
        if (!$('li.' + CSS.escape(item.data.key), panel.elLk.list).length) {
          var img_filename = (item.data.special_type ?  item.data.special_type : item.data.key) + '.png';
          item.data.img_url = item.data.img_url || (panel.imagePath + img_filename);

          var species_img = '<span class="selected-sp-img"><img src="' + item.data.img_url +'"></span>';

          $('<li/>', {
            'class': item.data.key
          })
          .data(item.data)
          .append(species_img, '<span class="selected-sp-title">' + item.data.title + '</span><span class="remove">x</span>')
          .prependTo(panel.elLk.list);
        }
      }
      else {
        if($('li.' + CSS.escape(item.data.key), panel.elLk.list).length) {
          $.each($('li', panel.elLk.list), function(i, li) {
            if ($(li).data('key') === item.data.key) {
              $(li).remove();
            }
          });          
        }
      }
    });
    $('li span.remove', panel.elLk.list).off().on('click', function(){
      panel.removeListItem($(this).parent());
      panel.updateCount();
    });

    panel.updateCount();
    $('h2', panel.elLk.taxon_selector_list).removeClass('active').addClass('active');
  },

  disableButton: function(bool) {
    $('#ss-submit', this.elLk.buttons).attr('disabled', bool);
    !bool ? $('#ss-submit', this.elLk.buttons).addClass('active') : $('#ss-submit', this.elLk.buttons).removeClass('active');
  },
  
  locateNode: function(key, select) {
    var panel = this;
    var mastertree_node = panel.elLk.mastertree.dynatree("getTree").getNodeInTree(key);

    if (!mastertree_node) return;

    if (!mastertree_node.data.isFolder) {
      var reset_tree = (panel.isCompara || !this.multiSelect);
      panel.setSelection(mastertree_node, true, reset_tree, reset_tree);
    }

    var subtree;
    if (panel.isCompara) {
      // Locate 
      // pw_subtree = panel.getTree(mastertree_node.data.title, panel.taxonTreeData);
    }

    var tree = panel.getTree(mastertree_node, 'isInternalNode');
    var submenu_tree = panel.getTree(mastertree_node, 'is_submenu');

    if (submenu_tree) {
      panel.createMenu(submenu_tree.data.children, tree.data.title)
      panel.addBreadcrumbs(submenu_tree);
    }
    
    panel.displayTree(tree.data.title);

    var node = panel.elLk.tree.dynatree("getTree").getNodeInTree(key);
    node && node.activate();
    node && !node.data.isFolder && select && node.select();
    if (!this.isCompara) {
      this.lastSelected = node;
    }
  },
  
  removeListItem: function(li) {
    var panel = this;

    var key = $(li).attr('class');
    if (key == '') {
      return;
    }

    var selectedNodes = [];
    selectedNodes = panel.elLk.mastertree.dynatree("getTree").getSelectedNodes();

    $.each(selectedNodes, function(index, node) {
      if (node.data.key == key) {
        // If tree displayed and remove item available in the tree then toggle select
        if ($('ul', panel.elLk.tree).length) {
          tree_node = panel.elLk.tree.dynatree("getTree").getNodeInTree(key)
          tree_node && tree_node.toggleSelect();
        }
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
      // Bring any references on top of the list
      if (a.match(/reference/i)) return -1;
      if (b.match(/reference/i)) return 1;

      if (aBegins == bBegins) {
        if (a == b) return 0;
        return a < b ? -1 : 1;
      }
      return aBegins ? -1 : 1;
    });
    return matches;
  },   
  
  updateConfiguration: function() {
    var panel = this;
    // var tree  = (panel.multiSelect) ? this.elLk.mastertree : this.elLk.tree;
    var items = new Array();
    var multipleAlignment = (this.activeTreeKey === 'Multiple');

    if (this.isCompara) {
      // For multiple alignment, it needs the node object to see which species are turned on and off
      items = this.lastSelected ? [ this.lastSelected ] : [];
    }
    else {
      if (this.multiSelect) {
        var tree = this.elLk.mastertree;
        items = this.getSelectedItems(tree);
      }
      else {
        items = this.lastSelected ? [ this.lastSelected.data ] : [];
      }
    }

    if (!items.length) {
      return false;
    }

    var currSelArr = new Array();

    for (var i = 0; i < items.length; i++) {
      if (this.isCompara) {
        items[i] && currSelArr.push(items[i].data.key);
      }
      else {
        items[i] && currSelArr.push(items[i].key);
      }
    }

    if (!panel.approveSelection(currSelArr)) {
      return false;
    }

    if (this.referer_type === 'Tools') {
      Ensembl.EventManager.trigger('updateTaxonSelection', items);
    }
    else if (this.isCompara) {
      var sel_alignment = items[0];
      if (multipleAlignment) {
        Ensembl.EventManager.trigger('updateMultipleAlignmentSpeciesSelection', sel_alignment);
      }
      else {
        Ensembl.EventManager.trigger('updateAlignmentSpeciesSelection', sel_alignment);
      }
    }
    else if (panel.referer_action === 'Multi') { //Region Comparison
      var params = [];
      for (var i = 0; i < items.length; i++) {
        items[i] && params.push('s' + (i + 1) + '=' + items[i].key);
      }

      var url = this.elLk.form.prop('action').replace(/[s,r]\d+=.*(;)?/,'');
      Ensembl.redirect(url + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + params.join(';')));
      
    }
    return true;
  },

  // Check if there was any change in the selection. If not, then do nothing.
  approveSelection: function(currSel) {
    return currSel.length && this.defaultSpecies && currSel.join(',') !== this.defaultSpecies.join(',');
  }
  
});

