// $Revision: 1.3 $

Ensembl.Panel.TaxonSelector = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id);
    this.urlParam = 's';
    this.dataUrl  = params.dataUrl;
    this.isBlast  = params.isBlast ? true : false ;
    
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
        panel.elLk.list   = $('.taxon_selector_list .vscroll_container', panel.el);
        panel.elLk.finder = $('.finder input', panel.el);
   
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
    $.getScript(panel.dataUrl, function() {
        
        // TREE
        // console.log(taxonTreeData);
        panel.elLk.tree.dynatree({
                //initAjax: {url: panel.dataUrl},
                children: taxonTreeData,
                checkbox: true,
                selectMode: 3,
                activeVisible: true,
                onSelect: function() { panel.setSelection() },
                onDblClick: function(node, event) { node.toggleSelect() },
                onKeydown: function(node, event) {
                    if( event.which == 32 ) {
                        node.toggleSelect();
                        return false;
                    }
                }
            });  
            
            var treeObj = panel.elLk.tree.dynatree("getTree");
            
            if (panel.defaultKeys && panel.defaultKeys.length > 0) {
            // set selected nodes      
            $.each(panel.defaultKeys, function(index, key) { 
                var node = treeObj.getNodeByKey(key);
                if (node) {
                    node.select();      // tick it
                    node.makeVisible(); // force parent path to be expanded
              }
            });
            } 
            
            var selected = panel.getSelectedItems(true);
            if (selected.length) {
              panel.locateNode(selected[0].key);
              panel.setSelection();
            } else if (panel.entryNode) {
            panel.locateNode(panel.entryNode);
        }
        
            // AUTOCOMPLETE
            
            // get autocomplete data from tree
            var acTitles = [];
            var acKeys = [];
            panel.elLk.tree.dynatree("getRoot").visit(function(node){
              acTitles.push(node.data.title);
              acKeys[node.data.title] = node.data.key;
            });
            
            var finder = panel.elLk.finder;
            finder.autocomplete({
          minLength: 3,
          source: function(request, response) { response(panel.filterArray(acTitles, request.term)) }, 
          select: function(event, ui) { panel.locateNode(acKeys[ui.item.value]) },
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
          // highlight the term within each match
          var regex = new RegExp("(?![^&;]+;)(?!<[^<>]*)(" + $.ui.autocomplete.escapeRegex(this.term) + ")(?![^<>]*>)(?![^&;]+;)", "gi");
          item.label = item.label.replace(regex, "<strong>$1</strong>");
          return $("<li></li>").data("ui-autocomplete-item", item).append("<a>" + item.label + "</a>").appendTo(ul);
        };
        });  

        panel.resize();  
  },
  
  resize: function () {
        var newHeight = $(this.el).height() - this.elLk.tree.position().top;
        this.elLk.tree.height(newHeight - 49);
        this.elLk.list.height(newHeight - 12);      
  },
  
  getSelectedItems: function(preserveOrder) {
    var selectedNodes = this.elLk.tree.dynatree("getTree").getSelectedNodes()
    var items = $.map(selectedNodes, function(node){
          return node.data.isFolder ? null : {key: node.data.key, title: node.data.title, img_url: node.data.img_url};
        });
    if (!preserveOrder) {
      items.sort(function (a, b) {return a.title.toLowerCase().localeCompare(b.title.toLowerCase())});
    }
    return items;
  },
  
  setSelection: function() {
    var panel = this;
    var items = panel.getSelectedItems();
    
      $('li', panel.elLk.list).remove();
      $.each(items, function(index, item){
                item.img_url = '/i/species/16/' + item.key.charAt(0).toUpperCase() + item.key.substr(1) + '.png';
                var species_img = item.img_url ? '<span class="selected-sp-img"><img src="'+ item.img_url +'"></span>' : '';
                console.log(item);
                var li = $('<li>' + species_img + '<span class="selected-sp-title">' + item.title + '</span><span class="remove"></span></li>').appendTo(panel.elLk.list);
                $('.remove', li).click(function(){panel.removeListItem($(this).parent())});
        });
  },
  
  locateNode: function(key) {
    var node = this.elLk.tree.dynatree("getTree").getNodeByKey(key);
        if (node) { 
            node.activate();
            node.li.scrollIntoView();
    }
  },
  
  removeListItem: function(li) {
        var panel = this;
        var title = li.text();
        var selectedNodes = panel.elLk.tree.dynatree("getTree").getSelectedNodes();
        
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
      return matcher.test( value.replace(/[^a-zA-Z0-9 ]/g, '') );
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
    var items = panel.getSelectedItems();
    if (panel.selectionLimit && items.length > panel.selectionLimit) {
        alert('Too many items selected.\nPlease select a maximum of ' + panel.selectionLimit + ' items.');
        return false;
    } else {
        Ensembl.EventManager.trigger('updateTaxonSelection', items);
        return true;
    }
  },
  
  updateConfiguration: function() {
    var panel = this;
    var items = panel.getSelectedItems();

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