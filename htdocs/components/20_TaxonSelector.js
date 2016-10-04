// $Revision: 1.3 $

Ensembl.Panel.TaxonSelector = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id);
    this.dataUrl   = params.dataUrl;
    // this.dataUrl   = '/taxon_tree_data.js';
    this.taxonTreeData = null;
    this.imagePath = '/i/species/48/';
    this.lastSelected = new Object;

    this.selectionLimit = params.selectionLimit || 25;
    this.defaultKeys = new Array();
    if (params.defaultKeys)     this.defaultKeys     = params.defaultKeys;
    if (params.entryNode)       this.entryNode       = params.entryNode;
    if (params.caller)          this.caller          = params.caller;
    if (params.allOptions)      this.allOptions      = params.allOptions;
    if (params.includedOptions) this.includedOptions = params.includedOptions;
    if (params.multiselect)     this.multiSelect     = params.multiselect;
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
    // panel.elLk.count.html('(' + panel.getCurrentSelectionCount() + '/' + panel.selectionLimit +')');
    panel.elLk.count.html(panel.getCurrentSelectionCount());
    panel.elLk.count.removeClass('warn');

    var curr_count = panel.getCurrentSelectionCount();
    if (curr_count == 0) {
      panel.disableButton(true);
      return false;
    }
    if (curr_count > panel.selectionLimit) {
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
    panel.elLk.tree.html('')
    panel.elLk.list.html('')
    if (panel.taxonTreeData) {
      panel.initAutoComplete();
      // Create initial breadcrumb (All division)
      panel.addBreadcrumbs();
      panel.createMenu(panel.taxonTreeData.children);
      // Populate default selected species on panel open
      panel.populateDefaultSpecies();
    }

    this.elLk.list.sortable({
      containment: this.elLk.list.parent(),
      stop: function(event, ui) {
        panel.startSort();
      }
    });
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

      $(a).on('click', function(){
        var node = panel.getTree($(this).html(), panel.taxonTreeData);
        panel.addBreadcrumbs(node.title);
        if (child.is_submenu) {
          if (child.children) {
            panel.createMenu(child.children);
            panel.hideTree();
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
    var path = key && !key.match(/All Divisions|All Alignments/i) ? panel.getPath(key, node) : node.title;
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
      'class': highlight ? 'active' : ''
    });

    var a = $('<a/>', {
      text: li_text,
      href: 'javascript:void(0);'
    }).appendTo(li);

    $(li).on('click', function() {
      var node = panel.getTree(li_text, panel.taxonTreeData);
      if (node.children) {
        panel.addBreadcrumbs(li_text);
        panel.hideTree();
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
        acKeys[search_text] = node.data.key;
        acKeys[node.data.key] = node.data.key;
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
        var isLeaf = panel.locateNode(acKeys[ui.item.value], true);
        if (isLeaf && !panel.multiSelect) {
          var node = panel.elLk.tree.dynatree("getTree").getSelectedNodes();
          panel.lastSelected = node.data;
        }
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

    panel.elLk.tree.dynatree({
      // initAjax: {url: panel.dataUrl},
      children: [taxon_tree.toDict(true)],
      imagePath: panel.imagePath,
      checkbox: true,
      selectMode: (panel.caller === 'Compara_Alignments') ? 1 : 3,
      activeVisible: true,
      onSelect: function(flag, node) {
        if (!panel.multiSelect) {
          // Update last selected item for single select
          panel.lastSelected = flag ? node.data : null;
          panel.disableButton(!flag);
          return;
        }
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

    locate && panel.locateNode(taxon_key);
  },

  populateDefaultSpecies: function() {
    var panel = this;
    // Populate default selected species
    var treeObj = panel.elLk.mastertree.dynatree("getTree");
    if (panel.defaultKeys && panel.defaultKeys.length > 0) {
      // set selected nodes
      $.each(panel.defaultKeys.reverse(), function(index, key) { 
        var node = treeObj.getNodeByKey(key);
        if (node) {
          node.select();      // tick it
          node.makeVisible(); // force parent path to be expanded
          panel.setSelection(node, true)
        }
      });
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

  getSubMenuTree: function(key, node) {
    var panel = this;
    
    var getSubMenuTree = function(key, node, submenu) {

      if (node.title === key) {
        return node.is_submenu ? node : true;
      }
      if (node.isFolder) {
        if (node.is_submenu) {
          submenu = node;
        }

        for (var i in node.children) {
          var child = getSubMenuTree(key, node.children[i], submenu);
          if (child) {
            return child === true ? submenu : child;
          }
        }
      }
      return false;
    };

    return getSubMenuTree(key, node, node);
  },

  resize: function () {
    var newHeight = $(this.el).height() - 80;
    this.elLk.tree.parent('.content').height(newHeight);
    this.elLk.list.closest('.vscroll_container').height(newHeight - 40);
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
          icon  : node.data.icon,
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
        results[results.length] = node;
      }
      return results;
    }
    return getAllLeaves(node);
  },

  setSelection: function(node, flag) {
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

    $.each(items, function(index, item){
      // Update mastertree according to the flag true/false = select/deselect
      panel.elLk.mastertree.dynatree("getTree").selectKey(item.data.key, flag);
      if (flag) {
        if (!$('li.'+item.data.key, panel.elLk.list).length) {
          var img_filename = item.data.key + '.png';
          item.data.img_url = item.data.icon.replace('\/16\/', '\/48\/');
          var species_img = item.data.img_url ? '<span class="selected-sp-img"><img src="'+ item.data.img_url +'"></span>' : '';

          $('<li/>', {
            'class': item.data.key
          })
          .data(item.data)
          .append(species_img, '<span class="selected-sp-title">' + item.data.title + '</span><span class="remove">x</span>')
          .prependTo(panel.elLk.list);
        }
      }
      else {
        if($('li.'+item.data.key, panel.elLk.list).length) {
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
    if (!mastertree_node.data.isFolder && panel.multiSelect) {
      panel.setSelection(mastertree_node, true);
    }

    var subtree = panel.getTree(mastertree_node.data.title, panel.taxonTreeData);
    var parent_tree = panel.getSubMenuTree(subtree.title, panel.taxonTreeData);
    panel.createMenu(parent_tree.children, subtree.title)
    panel.addBreadcrumbs(parent_tree.title);
    panel.displayTree(subtree.title);

    var node = panel.elLk.tree.dynatree("getTree").getNodeInTree(key);
    node && node.activate();
    node && select && node.select();
      // node.li.scrollIntoView();
  },
  
  removeListItem: function(li) {
    var panel = this;
    var title = $('.selected-sp-title', li).text();
    var selectedNodes = [];
    selectedNodes = panel.elLk.mastertree.dynatree("getTree").getSelectedNodes();

    $.each(selectedNodes, function(index, node) {
      if (node.data.title == title) {
        // If tree displayed and remove item available in the tree then toggle select
        if ($('ul', panel.elLk.tree).length) {
          tree_node = panel.elLk.tree.dynatree("getTree").getNodeInTree(title)
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
    if (panel.multiSelect) {
      var tree = this.elLk.mastertree;
      // console.log('updateconf',tree)
      items = panel.getSelectedItems(tree, true);
    }
    else {
      items = [this.lastSelected];
    }

    if (panel.caller === 'Blast') {
      Ensembl.EventManager.trigger('updateTaxonSelection', items);
    }
    else if (panel.caller === 'Compara_Alignments') {
      Ensembl.EventManager.trigger('updateAlignmentSpeciesSelection', items[0]);
    }
    else if (panel.caller === 'Multi') {
      var params = [];
      var currSelArr = new Array();
      for (var i = 0; i < items.length; i++) {
        if (items[i]) {
          params.push('s' + (i + 1) + '=' + items[i].key);
          currSelArr.push(items[i].key);
        }
      }

      if (!panel.approveSelection(currSelArr)) {
        return false;
      }

      var url = this.elLk.form.attr('action').replace(/[s,r]\d+=.*(;)?/,'');
      Ensembl.redirect(url + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + params.join(';')));
      
    }
    return true;
  },

  // Check if there was any change in the selection. If not, then do nothing.
  approveSelection: function(currSel) {
    return currSel.join(',') !== this.defaultKeys.join(',');
  }
  
});

