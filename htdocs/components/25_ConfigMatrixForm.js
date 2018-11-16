/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2018] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


Ensembl.Panel.ConfigMatrixForm = Ensembl.Panel.Configurator.extend({
  constructor: function (id, params) {
    this.base(id, params);
    Ensembl.EventManager.remove(id); // Get rid of all the Configurator events which we don't care about
  },
  
  init: function () {
    var panel = this;
    Ensembl.Panel.prototype.init.call(this); // skip the Configurator init - does a load of stuff that isn't needed here

    this.elLk.cell        = {};
    this.elLk.cell.container = $('div#cell-content', this.el);

    this.elLk.experiment        = {};
    this.elLk.experiment.container = $('div#experiment-content', this.el);

    this.elLk.buttonTab       = this.el.find("div.track-tab");
    this.elLk.trackPanel      = this.el.find(".track-panel");
    this.elLk.resultBox       = this.el.find(".result-box");
    this.elLk.filterList      = this.el.find("ul.result-list");
    this.elLk.filterButton    = this.el.find("button.filter");
    this.elLk.clearAll        = this.el.find("span.clearall");
    this.localStoreObj        = new Object();
    this.localStorageKey      = 'RegMatrix';
    this.elLk.lookup          = new Object();
    
    this.buttonOriginalWidth = this.elLk.filterButton.outerWidth();
    this.buttonOriginalHTML  = this.elLk.filterButton.html();

    panel.el.find("div#experiment-tab div.search-box").hide();

    $.ajax({
      url: '/Json/RegulationData/data?species='+Ensembl.species,
      dataType: 'json',
      context: this,
      success: function(json) {
        this.json_data = json;
        this.trackTab();
        this.populateLookUp();
        this.loadState();
        this.setDragSelectEvent();
      },
      error: function() {
        this.showError();
      }
    });
    
    this.elLk.buttonTab.on("click", function (e) { 
      var selectTab = panel.el.find(this).attr("id");
      panel.toggleTab(this, panel.el.find("div.track-menu"));
      panel.setDragSelectEvent();
    });
    
    this.clickSubResultLink();
    this.showHideFilters();
    this.clickCheckbox(this.elLk.filterList, 1);
    this.clearAll(this.elLk.clearAll);
    this.clickFilter(this.elLk.filterButton, this.el.find("div#track-config"));
  },

  getActiveTabContainer: function() {
    return $('div#cell-content.active, div#experiment-content.active', this.el);
  },
  getActiveTab: function() {
    return $('div#cell-content.active span.rhsection-id, div#experiment-content.active span.rhsection-id', this.el).html();
  },
  getActiveSubTab: function() {
    return $('div#cell-content.active .tab-content.active span.rhsection-id, div#experiment-content.active .tab-content.active span.rhsection-id', this.el).html();
  },

  populateLookUp: function() {
    var panel = this;
    // cell elements
    this.elLk.cell.ribbonBanner = $('.ribbon-banner .letters-ribbon .alphabet-div', this.elLk.cell.container);
    this.elLk.cell.tabContents = $('.ribbon-content li', this.elLk.cell.container);
    this.elLk.cell.haveSubTabs = false;

    // ExpType elements
    this.elLk.experiment.haveSubTabs = true;
    this.elLk.experiment.tabs = {}
    this.elLk.experiment.tabContents = {};
    var expTabs = $('.tabs.experiments div.track-tab', this.elLk.experiment.container);
    $.each(expTabs, function(i, el) {
      var k = $(el).attr('id').split('-')[0] || $(el).attr('id');
      panel.elLk.experiment.tabs[k] = el;
      var tabContentId = $('span.content-id', el).html();
      panel.elLk.experiment.tabContents[k] = $('div#' + tabContentId + ' li', panel.elLk.experiment.container);
    });
  },

  loadState: function() {
    var panel = this;
    this.loadingState = true;
    this.localStoreObj = this.getLocalStorage();
    if (!Object.keys(this.localStoreObj).length) return;

    // Apply cell first so that filter happens and then select all experiment types
    if (this.localStoreObj.cell) {
      $.each(this.localStoreObj.cell, function(k) {
        var el = panel.elLk.cell.tabContents.not(':not(.'+ k +')');
        panel.selectBox(el);
      });
    }
    if (this.localStoreObj.experiment) {
      $.each(this.localStoreObj.experiment, function(k) {
        var subTab = panel.elLk.lookup[k].subTab;
        var el = panel.elLk.experiment.tabContents[subTab].filter(function() {return $(this).hasClass(k)});
        panel.selectBox(el);
      });
    }

    panel.updateRHS();

    this.loadingState = false;
  },

  setDragSelectEvent: function() {
    var panel = this;
    var zone;

    if (!$('.tab-content.active .tab-content .ribbon-content', panel.el).length) {
      if (this.dragSelectCell) return;
      zone = '.tab-content.active .ribbon-content';
      this.dragSelectCell = new Selectables({
        elements: 'ul.letter-content li span',
        // selectedClass: 'selected',
        zone: zone,
        onSelect: function(el) {
          panel.selectBox(el.parentElement, 1);
        },
        stop: function() {
          panel.updateRHS();
        }
      });
    }
    else {
      if ($('.tab-content.active .tab-content.active .ribbon-content', panel.el).length) {
        zone = '.tab-content.active .tab-content.active .ribbon-content';
      }
      else {
        zone = '.tab-content.active .tab-content.active';
      }

      if (this.dragSelectExp && this.dragSelectExp[this.getActiveSubTab()]) return;
      this.dragSelectExp = this.dragSelectExp || {};
      this.dragSelectExp[this.getActiveSubTab()] = new Selectables({
        elements: 'li span, div.all-box',
        zone: zone,
        // selectedClass: 'selected',
        onSelect: function(el) {
          if($(el).hasClass('all-box')) {
            // Because select-all box is also included in the drag select zone
            // If selected, then trigger its click at the end of the dragSelect event
            // This is because onSelect event is fired on each (LI,DIV) elements
            this.selectAllClick = true;
            this.allBox = el;
          }
          else {
            panel.selectBox(el.parentElement);            
          }
        },
        stop: function(e) {
          if(this.selectAllClick) {
            $(this.allBox).click();
            this.selectAllClick = false;
          }
          else {
            panel.updateRHS();
          }
        }
      });      
    }
  },

  //function when click clear all link which should reset all the filters
  clearAll: function (clearLink) {
    var panel = this;
    
    clearLink.on("click",function(e){
      $.each(panel.el.find('div.result-box').find('li').not(".noremove"), function(i, ele){
        panel.selectBox(ele);
      });
    });
    
  },
  
  // Function to check divs that needs to have content to enable or disable apply filter button
  // Argument: ID of div to check for content
  enableFilterButton: function (content) {
    var panel = this;
    
    var total_div = $(content).length;
    var counter   = 0;

    $(content).each(function(i, el){
      if($(el).find('li').length && $(el).find('span.fancy-checkbox.selected').length) { 
        counter++;
      }
    });

    if(counter === total_div) {
      panel.el.find('button.filter').addClass('active');
      panel.el.find('li._configure').removeClass('disable');
    } else {
      panel.el.find('button.filter').removeClass('active');
      panel.el.find('li._configure').addClass('disable');
    }
  },
  
  //function to show/hide error message for empty track filters
  // Argument: containers where to listen for empty elements (Note: span error id should match container id with an underscore)
  trackError: function(containers) {
    var panel = this;

    $(containers).each(function(i, ele) {
        var error_class = "_" + $(ele).attr('id');
        if ($(ele).find('li').length && $(ele).find('span.fancy-checkbox.selected').length) {
            $("span." + error_class).hide();
        } else {
            $("span." + error_class).show();
        }
    });

  },

  // Function to update the current count in the right hand panel (can be adding/removing 1 or select all)
  // Argument: element/container object where current count is to be updated
  //           how much to add to the current value
  updateCurrentCount: function(key, selected, total) {
    var panel = this;
    if(key) {
      $('#'+key+' span.current-count', this.elLk.resultBox).html(selected);
      $('#'+key+' span.total', this.elLk.resultBox).html(total);
    }
  },

  // Function to select/unselect checkbox and removing them from the right hand panel (optional) and adding them to the right hand panel (optional)
  //Argument: container is an object where the checkbox element is
  //        : removeElement either 1 or 0 whether to remove element 
  //        : AddElement is either 1 or 0
  //        : allBox is Object of select all box, check if it needs to be on or off
  clickCheckbox: function (container, removeElement, addElement, allBox) {
    var panel = this;
    var itemListen = "li";
    if(container[0].nodeName === 'DIV') {
      itemListen = "";
    }
    //clicking checkbox
    $(container).off().on("click", itemListen, function(e) {
      panel.selectBox(this);
      panel.updateRHS($(this).data('item'));

      //check whether the select all box is on/off, if it is off and all filters are selected, then make it on and if it is on and all filters are not selected then make it off
      if(allBox && itemListen === "li"){
        if(container.find("span.fancy-checkbox.selected").length === container.find("span.fancy-checkbox").length) {
          allBox.find("span.fancy-checkbox").addClass("selected");
        } else {
          allBox.find("span.fancy-checkbox").removeClass("selected");
        }
      }
      e.stopPropagation();
    });  
  },
  
  updateRHS: function(item) {
    var panel = this;
    panel.updateSelectedTracksPanel(item);
    panel.activateTabs();
    panel.updateShowHideLinks(item);
    panel.setLocalStorage();
    panel.trackError('div#cell, div#experiment, div#source');
    panel.enableFilterButton('div#cell, div#experiment, div#source');
  },


  //Function to select filters and adding/removing them in the relevant panel
  selectBox: function(ele) {
    var panel = this;
    var selected = $('span.fancy-checkbox', ele).hasClass('selected');

    if($(ele).hasClass('all-box')) {
      // if (!selected) {
      //   $(ele).closest('.tab-content').find('li span.fancy-checkbox').addClass("selected");
      // }
      // else {
      //   $(ele).closest('.tab-content').find('li span.fancy-checkbox').removeClass('selected');
      // }
    }
    else {
      var item = $(ele).data('item');
      // Select/deselect elements from LH and RH panels. For that, get the elements from panel.el
      var itemElements = $('.' + item, panel.el);
      selected ? $(itemElements).find("span.fancy-checkbox").removeClass("selected") : $(itemElements).find("span.fancy-checkbox").addClass("selected");
      panel.filterData(item);
    }

    return;



    var item = $(ele).data('item');
    var rhsectionId = panel.elLk.lookup[item].subTab;

    //unselecting checkbox
    if($(ele).find("span.fancy-checkbox.selected").length){
      $(ele).find("span.fancy-checkbox").removeClass("selected");
      this.removeFromStore($(ele).data('item'), $(ele).data('parentTab'));
      var ele_class = $(ele).data('item');

      //removing element from right hand panel (selection panel) - optional
      if(removeElement && !ele.className.match("noremove")){
        //unselecting from left hand panel when unselecting/removing in right hand panel
        var lhsectionId = $(ele).closest("ul.result-list").find("span.lhsection-id").html();
        var allBoxId    = $(ele).find('span.allBox-id').html();

        panel.updateCurrentCount($(ele).parent().parent().find("div.count-container").find('span.current-count'), -1);
        panel.showHideLink($(ele).parent().parent()); //need to be after updateCurrentCount
        panel.el.find('div#'+lhsectionId+' li.'+ ele_class +' span.fancy-checkbox').removeClass("selected");
        ele.remove();
  
        //if select all box is selected, it needs to be unselected if one track is removed
        if(panel.el.find('div#'+allBoxId+' span.fancy-checkbox.selected').length) {
          panel.el.find('div#'+allBoxId+' span.fancy-checkbox').removeClass("selected");        
        }
      }
      //removing from right hand panel when unselecting in left hand panel
      if(addElement) {          
        panel.el.find('div#'+rhsectionId+' ul li.'+item).remove();
        panel.updateCurrentCount(panel.el.find('div#'+rhsectionId+' span.current-count'), -1);
        panel.showHideLink(panel.el.find('div#' + rhsectionId)); //need to be after updateCurrentCount
      }
      panel.filterData(ele_class);
    } else { //selecting checkbox
      if(addElement) {
        var allBoxid     = panel.elLk.lookup[item].parentTab.find('div.all-box').attr("id");

        panel.updateCurrentCount(panel.el.find('div#'+rhsectionId+' span.current-count'));
        panel.showHideLink(panel.el.find('div#' + rhsectionId)); //need to be after updateCurrentCount
        
        $(ele).clone().append('<span class="hidden allBox-id">'+allBoxid+'</span>').prependTo(panel.el.find('div#'+rhsectionId+' ul')).removeClass("noremove").addClass(item).find("span.fancy-checkbox").addClass("selected");
      }
      $(ele).find("span.fancy-checkbox").addClass("selected");
      panel.filterData(item);

      if ($(ele).data('filtercontainer')) {        
        !this.loadingState && this.addToStore(item); // Dont add to store while loading state from store
      }
    }
    panel.trackError('div#cell, div#experiment, div#source');
    panel.enableFilterButton('div#cell, div#experiment, div#source');
    panel.setLocalStorage();
  },


  updateSelectedTracksPanel: function(item) {
    var panel = this;
    var selectedElements = [];
    this.selectedTracksCount = {};
    this.totalSelected = 0;
    ['cell', 'experiment'].forEach(function(key) {
      var selectedLIs, allLIs;
      if (panel.elLk[key].haveSubTabs) {
        // If tab have subtabs
        $.each(panel.elLk[key].tabContents, function(subTab, lis) {
          selectedLIs = lis.has('.selected') || [];
          allLIs = lis.has('._filtered') || [];
          // In case _filtered class is not applied
          allLIs = allLIs.length || lis.filter(function() { return $(this).css('display') !== 'none' });

          // Storing counts of each tabs - selected and available,  to activate/deactivate tabs and ribbons
          panel.selectedTracksCount[subTab] = panel.selectedTracksCount[subTab] || {};
          panel.selectedTracksCount[subTab].selected = selectedLIs.length;
          panel.selectedTracksCount[subTab].available = allLIs.length;
          this.totalSelected  += selectedLIs.length;

          panel.updateCurrentCount(subTab, selectedLIs.length, allLIs.length);
          selectedLIs.length && selectedElements.push(selectedLIs);
        })

        // panel.selectedTracksCount[key] = panel.selectedTracksCount[key] || {};
        // panel.selectedTracksCount[key].selected = this.totalSelected;
        // panel.selectedTracksCount[key].selected = this.total_available;
      }
      else {
        selectedLIs = panel.elLk[key].tabContents.has('.selected') || [];
        allLIs = panel.elLk[key].tabContents.has('._filtered') || [];
        allLIs = allLIs.length || panel.elLk[key].tabContents.filter(function() { return $(this).css('display') !== 'none' });

        panel.selectedTracksCount[key] = panel.selectedTracksCount[key] || {};
        panel.selectedTracksCount[key].selected  = selectedLIs.length;
        panel.selectedTracksCount[key].available = allLIs.length;
        panel.totalSelected += selectedLIs.length;

        // update counts
        panel.updateCurrentCount(key, selectedLIs.length, allLIs.length);
        selectedLIs.length && selectedElements.push(selectedLIs);
      }
    });

    // update selected items (cloned checkboxes)
    var clones = {};
    $(selectedElements).each(function(i, el){
      var item = $(el).data('item');
      clones[item] = $(el).clone().removeClass('noremove');
    });
    panel.updateSelectedTracks(clones);

    // Update store
    var itemKeys = Object.keys(clones);
    !panel.loadingState && panel.addToStore(itemKeys); // Dont add to store while loading state from store
    panel.setLocalStorage();
  },

  // Update selected tracks on the RH panel
  updateSelectedTracks: function (clones) {
    var panel = this;
    // Remove all clones LIs before inserting new ones
    $('li:not(".noremove")', panel.elLk.filterList).remove();

    $.each(clones, function(k, clone) {
      var rhs_id = panel.elLk.lookup[k].subTab;
      $('#'+rhs_id+'.result-content ul', panel.el).append(clone);
    });
  },

  // Enable or disable tabs/ribbons and also show/hide RH panel title
  activateTabs: function() {
    var panel = this;

    $.each(panel.selectedTracksCount, function(key, count) {
      var tab_ele = $('.tabs #' + key + '-tab', panel.el.trackPanel);
      var rhs_ele = $('#'+key, panel.elLk.resultBox);

      if (count.available) {
        tab_ele.removeClass('inactive');
        rhs_ele.show();
      }
      else {
        tab_ele.addClass('inactive');
        rhs_ele.hide();
      }
    });


//     $('.ribbon-content', panel.el).each(function(i, el) {
//       var lettersRibbon = $(el).prev('.ribbon-banner').find('.letters-ribbon');

//       if (lettersRibbon.length) {
//         var alphaContent = $(el).find('.alphabet-content');
//         var parentTabId = $(el).closest('.tab-content').data('rhsection-id');

//         var tabBId = $('ul li', alphaContent[0]).data('filtercontainer');
//         var tabBSelected = $('#' + tabBId +' li span.selected', panel.elLk.trackPanel);

//         if (!tabBSelected.length && !this.totalSelected) {
//           $(el).not('.inactive') && $(lettersRibbon).removeClass('inactive');
//         }
//         else {
//           alphaContent.each(function(i, el) {
//             var ribbonClass = $(el).data('ribbon');
//             if (!$('ul li._filtered', el).length || !$(el).not('.inactive')) {
//               $(lettersRibbon).find('.'+ribbonClass).addClass('inactive');
//             }
//             else {
//               $(lettersRibbon).find('.'+ribbonClass).removeClass('inactive');              
//             }
//           });
//         }
//       }
//     })
// return;
  },

  setLocalStorage: function() {
    localStorage.setItem(this.localStorageKey, JSON.stringify(this.localStoreObj));
  },
  getLocalStorage: function() {
    return JSON.parse(localStorage.getItem(this.localStorageKey)) || {};
  },

  addToStore: function(items) {
    this.localStoreObj = {};
    if (!items.length) return;
    var panel = this;
    var parentTab;
    $.each(items, function(i, item) {
      parentTab = panel.elLk.lookup[item].parentTabId;
      panel.localStoreObj[parentTab] = panel.localStoreObj[parentTab] || {}
      panel.localStoreObj[parentTab][item] = 1;
    });
  },
  removeFromStore: function(item, lhs_section_id) {
    // Removal could happen from RHS or LHS. So section id need to passed as param
    if(lhs_section_id !== 'cell') {
      var tab = 'experiment'
      item && lhs_section_id && delete this.localStoreObj[tab][lhs_section_id][item];
    }
    else {
      item && lhs_section_id && delete this.localStoreObj[lhs_section_id][item];
    }
  },
  
  // Function to show a panel when button is clicked
  // Arguments javascript object of the button element and the panel to show
  clickFilter: function(clickButton, showPanel) {
    var panel = this;

    clickButton.on("click", function(e) {
      if(clickButton.hasClass("_edit") ) {
        clickButton.outerWidth(panel.buttonOriginalWidth).html(panel.buttonOriginalHTML).removeClass("_edit");
        panel.toggleTab(panel.el.find("div#browse-tab"), panel.el.find("div.tabs.track-menu"));
      } else if(clickButton.hasClass("active") ) {      
        panelId = showPanel.attr('id');
        var panelTab = panel.el.find("span:contains('"+panelId+"')").closest('div');
        panel.toggleTab(panelTab, panel.el.find("div.tabs.track-menu"));
        clickButton.addClass("_edit").outerWidth("70px").html("Edit");
      }
    });
    
  },
  
  //function to jump to tab based on the link
  clickSubResultLink: function() {
    var panel = this;
    panel.el.find('div.sub-result-link').on("click", function(e) {
      var tabId       = "div#" + panel.el.find(this).parent().attr("id") + "-tab";
      var contentId   = "div#" + panel.el.find(tabId).find("span.content-id").html();
      var parentTabId = panel.el.find(this).parent().find("span._parent-tab-id").html();

      panel.el.find(".track-tab.active").first().removeClass("active");
      panel.el.find(".tab-content.active").first().removeClass("active");

      //for now assuming there is only one parent tab, if there is more than one then we need to create for loop
      if(parentTabId){
        var parentTab       = "div#" + parentTabId;
        var parentContentId = "div#" + panel.el.find(parentTab).find("span.content-id").html();

        panel.el.find(parentContentId+" .track-tab.active").removeClass("active");
        panel.el.find(parentContentId+" .tab-content.active").removeClass("active");
        panel.el.find(parentTab).addClass("active");
        panel.el.find(parentContentId).addClass("active");

        //showing/hiding searchbox in the main tab
        if($(parentTab).find("div.search-box").length) {
          panel.el.find(".search-box").hide();
          $(parentTab).find("div.search-box").show();
        }
      }

      //showing/hiding searchbox in the main tab
      if($(tabId).find("div.search-box").length) {
        panel.el.find(".search-box").hide();
        $(tabId).find("div.search-box").show();
      }

      panel.el.find(tabId).addClass("active");
      panel.el.find(contentId).addClass("active");
    });
  },

  updateShowHideLinks: function() {
      var panel = this;

      $.each(panel.elLk.filterList, function(i, ul) {
        if (!$(ul).siblings("div.show-hide:visible").length && $('li', ul).length) {
          $(ul).siblings('._show').show();
        }
        else if ($(ul).siblings("div.show-hide:visible").length && $('li', ul).length === 0) {
          $(ul).siblings('._hide, ._show').hide();
        }
      })
  },

  // Function to show "show selected" or "Hide selected" link in right hand panel
  showHideLink: function(containerObj) {
      var panel = this;

      if (!containerObj.find("div.show-hide:visible").length && containerObj.find("ul.result-list li").length === 0) {
          containerObj.find("div._show").show();
      } else if (containerObj.find("div.show-hide:visible").length && parseInt(containerObj.find('span.current-count').html()) === 0) {
          containerObj.find("div._show, div._hide").hide();
          containerObj.find("ul.result-list").hide();
      }
  },

  //function to toggle filters in right hand panel when show/hide selected is clicked
  showHideFilters: function() {
      var panel = this;

      panel.el.find('div.show-hide').on("click", function(e) {
        console.log('show-hide click');
          panel.el.find(this).parent().find('div.show-hide, ul.result-list').toggle();
      });
  },


  //Function to select all filters in a specific panel
  // Arguments: container where all the filters to be selected are
  //          : select all box object
  selectAll: function (container, allBox) {
    var panel = this;
    
    allBox.on("click", function(){
      $.each(container.find('li'), function(i, ele) {
        //selecting all of them
        if(allBox.find("span.fancy-checkbox.selected").length){
          if(!$(ele).find("span.fancy-checkbox.selected").length){          
            panel.selectBox(ele);
          }          
        }
        else { //unselecting all of them
          if($(ele).find("span.fancy-checkbox.selected").length){          
            panel.selectBox(ele);
          } 
        }        
      });
    });
  },
  
  trackTab: function() {
    var panel = this;
    //showing and applying cell types
    var cellTypeContainer = panel.el.find("div#cell-content");
    var rhSectionId = cellTypeContainer.data('rhsection-id');
    this.displayFilter(Object.keys(panel.json_data.cell_lines).sort(), "div#cell-content", "alphabetRibbon", cellTypeContainer, rhSectionId);

    //showing experiment type tabs
    var experiment_html = '<div class="tabs experiments">';
    var content_html    = "";

    //sort evidence object
    Object.keys(panel.json_data.evidence).sort().forEach(function(key) {
        var value = panel.json_data.evidence[key];
        delete panel.json_data.evidence[key];
        panel.json_data.evidence[key] = value;
    });

    var count = 0;
    $.each(panel.json_data.evidence, function(key, item){
      var active_class = "";
      if(count === 0) { active_class = "active"; } //TODO: check the first letter that there is data and then add active class
      experiment_html += '<div class="track-tab '+active_class+'" id="'+key+'-tab">'+item.name+'<span class="hidden content-id">'+key+'-content</span></div>';
      content_html += '<div id="'+key+'-content" class="tab-content '+active_class+'" data-rhsection-id="'+ key +'""><span class="hidden rhsection-id">'+key+'</span></div>';
      count++;
    });
    experiment_html += '</div>';
    var expTabContainer = panel.el.find("div#experiment-content");
    expTabContainer.append(experiment_html).append(content_html);
    rhSectionId = expTabContainer.data('rhsection-id');
    
    //displaying the experiment types
    $.each(panel.json_data.evidence, function(key, ev){
      panel.displayFilter(ev.evidence_type, "div#"+key+"-content",ev.listType, expTabContainer, rhSectionId);
    })
    
    //adding experiment and cells relationship as data-attribute
    panel.addRelationData();

    //selecting the tab in experiment type
    this.el.find("div.experiments div.track-tab").on("click", function () {
      panel.toggleTab(this, panel.el.find("div.experiments"));
      panel.setDragSelectEvent();
    });    
    
  },
  
  // Function to toggle tabs and show the corresponding content which can be accessed by #id or .class
  // Arguments: selectElement is the tab that's clicked to be active or the tab that you want to be active (javascript object)
  //            container is the current active tab (javascript object)
  //            selByClass is either 1 or 0 - decide how the selection is made for the container to be active (container accessed by #id or .class)
  toggleTab: function(selectElement, container, selByClass) {
    var panel = this;

    if(!$(selectElement).hasClass("active") && !$(selectElement).hasClass("inactive")) {
      //showing/hiding searchbox in the main tab
      if($(selectElement).find("div.search-box").length) {
        panel.el.find(".search-box").hide();
        $(selectElement).find("div.search-box").show();
      }

      //remove current active tab and content
      var activeContent = container.find("div.active span.content-id").html();
      container.find("div.active").removeClass("active");
      if(selByClass) {
        container.find("div."+activeContent).removeClass("active");
      } else {
        panel.el.find("#"+activeContent).removeClass("active");
      }

      //add active class to clicked element
      var spanID = $(selectElement).find("span.content-id").html();
      $(selectElement).addClass("active");

      var activeLetterDiv = container.find('div.alphabet-div.active');

      if(selByClass) {
        activeAlphabetContentDiv = container.find("div."+spanID);
      } else {
        activeAlphabetContentDiv = panel.el.find("#"+spanID);
      }

      activeAlphabetContentDiv.addClass("active");

      // change offset position of active content same as the ribbon letter
      if(activeAlphabetContentDiv.hasClass('alphabet-content')) {
        activeAlphabetContentDiv.offset({left: activeLetterDiv.offset().left - 2});
      }
    }
  },

  //function to display filters (checkbox label), it can either be inside a letter ribbon or just list
  displayFilter: function(data, container, listType, parentTabContainer, parentRhSectionId) {
    var panel       = this;
    var ribbonObj   = {};
    var countFilter  = 0;

    if(listType && listType === "alphabetRibbon") {
      //creating obj with alphabet key (a->[], b->[],...)
      $.each(data, function(j, item) {
        var firstChar = item.charAt(0).toLowerCase();
        if(!ribbonObj[firstChar]) {
          ribbonObj[firstChar] = [];
          ribbonObj[firstChar].push(item);
        } else {
          ribbonObj[firstChar].push(item);
        }
      });
      panel.alphabetRibbon(ribbonObj, container, parentTabContainer, parentRhSectionId);
    } else  {
      var html = '<ul class="letter-content list-content">';
      var rhsection = panel.el.find(container).find('span.rhsection-id').html();

      $.each(data.sort(), function(i, item) {
        if(item) {
          var elementClass = item.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          html += '<li class="noremove '+ elementClass + '" data-parent-tab="' + rhsection + '" data-item="' + elementClass +'"><span class="fancy-checkbox"></span><text>'+item+'</text></li>';
        }
        countFilter++;
        panel.elLk.lookup[elementClass] = {
          parentTab: parentTabContainer,
          parentTabId: parentRhSectionId,
          subTab: rhsection
        };

      });
      html += '</ul>';
      html = '<div class="all-box list-all-box" id="allBox-'+$(container).attr("id")+'"><span class="fancy-checkbox"></span>Select all<text class="_num">('+countFilter+')</text></div>' + html; 
      panel.el.find(container).append(html);
      
      //updating available count in right hand panel
      panel.el.find('div#'+rhsection+' span.total').html(countFilter);

      //clicking select all checkbox
      panel.clickCheckbox(this.el.find(container+" div.all-box"));
      //selecting all filters
      panel.selectAll(this.el.find(container+" ul.letter-content"), this.el.find(container+" div.all-box"));
      
      //clicking checkbox for the filters
      // panel.clickCheckbox(this.el.find(container+" ul.letter-content"), 0, 1, this.el.find(container+" div.all-box"));
    }
  },
  
  //function to add cells and experiments in data-filter attribute which link the cells checkbox to the experiments checkbox and vice versa, use for filtering to show/hide cells/experiments
  addRelationData: function () {
    var panel = this;

    $.each(panel.json_data.cell_lines, function(key, data) {
      var cellClassName = key.replace(/[^\w\-]/g,'_');

      //add experiments attribute to cell lines
      var experimentsVal="";
      $.each(data, function(index, ele) {
        var experimentClassName = ele.evidence_type.replace(/[^\w\-]/g,'_');
        experimentsVal += ele.evidence_type+" ";
        
        //adding cells atribute to experiments
        var existingCells = panel.el.find("li."+experimentClassName).attr('data-filter');
        existingCells ?  panel.el.find("li."+experimentClassName).attr('data-filter', existingCells+" "+cellClassName) :  panel.el.find("li."+experimentClassName).attr('data-filter',cellClassName);
        if(!panel.el.find("li."+experimentClassName).attr('data-filtercontainer')){
          panel.el.find("li."+experimentClassName).attr('data-filtercontainer','cell-content');
        } 
      });
      //data-filter contains the classname that needs to be shown and data-filtercontainer is the id where elements to be shown are located
      panel.el.find("li."+cellClassName).attr('data-filter',experimentsVal).attr('data-filtercontainer','experiment-content');

    });
  },

  // Function that does internal filtering to show/hide cells/experiments based on a checkbox selection.
  // This will also do the activation/inactivation of tabs based on availability
  // Arguments: selected element item name
  filterData: function(item) {
    var panel = this;
    var eleObj = $('.' + item, panel.elLk.trackPanel);
    var tabBcontainerId = "#"+eleObj.attr("data-filtercontainer"); //get container where the contents to be filtered are located

    var tabAcontainer = $(panel.elLk.lookup[item].parentTab, panel.el);
    var tabB_LIs = panel.el.find(tabBcontainerId).find('li');
    var resetCount = 0;
    //show/hide elements, first hide all of them and then only show the one that needs to be shown
    if(eleObj.find(".fancy-checkbox").hasClass("selected")) { //if selecting checkbox
      tabB_LIs.hide();
      // panel.el.find(tabBcontainerId+" li span.fancy-checkbox").removeClass('selected');
 
      //first element selected
      if(tabAcontainer.find('li span.fancy-checkbox.selected').length === 1) {
        $.each(eleObj.attr("data-filter").split(" "), function(index, ele) {
          if(ele){
            // panel.el.find(tabBcontainerId+" li."+ele+' span.fancy-checkbox').addClass('selected');
            panel.el.find(tabBcontainerId+" li."+ele).addClass('_filtered').show();
          }
        });
      } else { //multiple checkbox selection
        $.each(tabAcontainer.find('li span.fancy-checkbox.selected'), function(i, box) {
          $.each(panel.el.find(box).closest("li").attr("data-filter").split(" "), function(l, ele) {
            if(ele){
              panel.el.find(tabBcontainerId+" li."+ele).addClass('_filtered').show();
            }
          });
        });
      }

      // Unselect any lis which went hidden after filtering
      tabB_LIs.not('._filtered').find('span.fancy-checkbox').removeClass('selected');

    } else { //unselecting checkbox, need to check if no element is selected, then show everything or else only show elements from selection
      if(!tabAcontainer.find('li span.fancy-checkbox.selected').length) { //last checkbox unselected, show everything
        tabB_LIs.removeClass('_filtered').show();
        resetCount = 1;
      } else { //more than 1 checkbox unselected
        tabB_LIs.removeClass('_filtered').hide();
        
        $.each(tabAcontainer.find('li span.fancy-checkbox.selected'), function(i, box) {
          $.each(panel.el.find(box).closest("li").attr("data-filter").split(" "), function(l, ele) {
            if(ele){
              panel.el.find(tabBcontainerId+" li."+ele).addClass('_filtered').show();
            }
          });
        });
      }
    }


    //update count in Right hand panel
    //first set everything to zero for the filtered content
    var mainRHSection = panel.el.find(tabBcontainerId).find("span.rhsection-id").html();
    
    // loop for each li to find out where the parent content is and update count
    $.each(panel.el.find(tabBcontainerId).find('span.rhsection-id'), function(d, ele3) {
      var rhsectionId = panel.el.find(ele3).html();
      var newCount    = 0;
      var parentTab   = panel.el.find(ele3).closest(".tab-content").find("li").data("parent-tab")+"-tab";

      if(panel.el.find("div#"+rhsectionId+".result-content").length) {
        var li_class = resetCount ? "" : "._filtered";  //if resetcount we need to get all li
        $.each(panel.el.find(tabBcontainerId+' li'+li_class), function(index, elem) {
          if(rhsectionId === panel.el.find(elem).closest("div.tab-content").find('span.rhsection-id').html()) {
            newCount++;
          } 
        });

        if(panel.el.find(ele3).closest(".tab-content").find("div.all-box text._num").length) {
          panel.el.find(ele3).closest(".tab-content").find("div.all-box text._num").html("("+newCount+")");
        }
        if(!newCount) {
          panel.el.find("div#"+parentTab).addClass("inactive");
          panel.el.find("div#"+rhsectionId+".result-content").hide();
        } else {
          //making sure rhsection is shown and remove inactive class
           panel.el.find("div#"+rhsectionId+".result-content").show();
          panel.el.find("div#"+parentTab).removeClass("inactive");          
        }

        //if there is alphabet ribbon, going through alphabet ribbon, activating and deactivating the one with/without elements
        if(panel.el.find(ele3).closest(".tab-content").find("div.ribbon-content div.alphabet-content").length) {
          var setActive = 0; //used to set active ribbon
          var activeCount = 0;
          panel.el.find(ele3).closest(".tab-content").find("div.letters-ribbon div.active").removeClass("active"); //removing existing active first
          panel.el.find(ele3).closest(".tab-content").find("div.alphabet-content.active").removeClass("active");

          $.each(panel.el.find(ele3).closest(".tab-content").find("div.ribbon-content div.alphabet-content"), function(i2, ele4) {
            var parentRibbon = panel.el.find(ele4).data("ribbon");

            if(panel.el.find(ele4).find("li._filtered").length) {
              activeCount++;
              //toggling tab for first active class adding active class to first alphabet with content in ribbon
              if(!panel.el.find(ele3).closest(".tab-content").find("div.letters-ribbon div.active").length){
                 panel.toggleTab(panel.el.find(ele3).closest(".tab-content").find("div."+parentRibbon), panel.el.find(ele3).closest(".tab-content"), 1);
              }
              panel.el.find(ele3).closest(".tab-content").find("div."+parentRibbon).removeClass("inactive"); //remove inactive class in case its present
            } else { //empty

              if(panel.el.find(ele4).find("li").length && resetCount) { //resetting everything
                panel.el.find(ele3).closest(".tab-content").find("div."+parentRibbon).removeClass("inactive"); // remove inactive from alphabet ribbon with content 
                panel.el.find(ele3).closest(".tab-content").find("div.rarrow").removeClass("inactive").addClass("active");
                panel.el.find("div#"+mainRHSection+" div.result-content").show(); //make sure all rhSection link/count are shown

                if(!panel.el.find(ele3).closest(".tab-content").find("div.letters-ribbon div.active").length){
                   panel.toggleTab(panel.el.find(ele3).closest(".tab-content").find("div."+parentRibbon), panel.el.find(ele3).closest(".tab-content"), 1);
                }                
              } else { //empty with no li at all
                panel.el.find(ele3).closest(".tab-content").find("div."+parentRibbon).addClass("inactive");
              }
            }
          });

          //disable rarrow and larrow if there is only one ribbon available
          if(activeCount === 1) {
            panel.el.find(ele3).closest(".tab-content").find("div.larrow, div.rarrow").addClass("inactive");
          } else {
            panel.el.find(ele3).closest(".tab-content").find("div.rarrow").addClass("active"); 
          }
        }
      }
    });
  },

  getStartEndActiveAlphabet: function(container) {
    var panel = this;
    var activeAlphabetElements = panel.el.find(container+' div.alphabet-div').not('.inactive');
    var activeLetterStart = $(activeAlphabetElements[0]).html().charAt(0);
    var activeLetterEnd   = $(activeAlphabetElements[activeAlphabetElements.length - 1]).html().charAt(0);
    return [activeLetterStart, activeLetterEnd];

  },

  // Function to create letters ribbon with left and right arrow (< A B C ... >) and add elements alphabetically
  // Arguments: data: obj of the data to be added with obj key being the first letter pointing to array of elements ( a -> [], b->[], c->[])
  //            Container is where to insert the ribbon
  alphabetRibbon: function (data, container, parentTabContainer, parentRhSectionId) {

    var panel = this;
    var html  = "";
    var content_html = "";
    var total_num = 0;
    var rhsection = panel.el.find(container).find('span.rhsection-id').html();

    //generate alphabetical order ribbon (A B C D ....)
    $.each(new Array(26), function(i) {
      var letter = String.fromCharCode(i + 97);
      var active_class = "";
      var letterHTML   = "";
      
      if(i === 0) { active_class = "active"; } //TODO: check the first letter that there is data and then add active class

      if(data[letter] && data[letter].length) {
        letterHTML = '<ul class="letter-content">';
        $.each(data[letter], function(i, el) {
          total_num++;
          var elementClass = el.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          letterHTML += '<li class="noremove ' + elementClass + '" data-parent-tab="' + rhsection + '" data-item="' + elementClass + '"><span class="fancy-checkbox"></span><text>'+el+'</text></li>';

          panel.elLk.lookup[elementClass] = {
            parentTab: parentTabContainer,
            parentTabId: parentRhSectionId,
            subTab: rhsection
          };
        });
        letterHTML += '</ul>';
      } else {
        active_class = "inactive";
      }
      
      html += '<div class="ribbon_'+letter+' alphabet-div '+active_class+'">'+letter.toUpperCase()+'<span class="hidden content-id">'+letter+'_content</span></div>';
      content_html += '<div data-ribbon="ribbon_'+letter+'" class="'+letter+'_content alphabet-content '+active_class+'">'+letterHTML+'</div>';
    });
    panel.el.find(container).append('<div class="all-box" id="allBox-'+$(container).attr("id")+'"><span class="fancy-checkbox"></span>Select all<text>(A-Z)</text></div><div class="cell-listing"><div class="ribbon-banner"><div class="larrow inactive">&#x25C0;</div><div class="alpha-wrapper"><div class="letters-ribbon"></div></div><div class="rarrow">&#x25B6;</div></div><div class="ribbon-content"></div></div>');
    panel.el.find(container+' div.letters-ribbon').append(html);
    panel.el.find(container+' div.ribbon-content').append(content_html);

    //updating available count in right hand panel
    panel.el.find('div#'+rhsection+' span.total').html(total_num);

    //clicking checkbox for each filter
    // panel.clickCheckbox(this.el.find(container+" ul.letter-content"), 0, 1, this.el.find(container+" div.all-box"));
    
    //clicking select all checkbox
    panel.clickCheckbox(this.el.find(container+" div.all-box"));
   
    //selecting all filters
    panel.selectAll(this.el.find(container+" div.ribbon-content"), this.el.find(container+" div.all-box"));
    
    //clicking the alphabet
    panel.elLk.alphabet = panel.el.find(container+' div.alphabet-div');      
    panel.elLk.alphabet.on("click", function(){
      if (!$(container, panel.el).hasClass('active')) {
        return;
      }
      $.when(
        panel.toggleTab(this, panel.el.find(container), 1)
      ).then(
        selectArrow()
      );
    });
    
    function selectArrow() {
      var activeLetters = panel.getStartEndActiveAlphabet(container)
      if(panel.el.find(container+' div.alphabet-div.active').html().match(activeLetters[0])) { 
        panel.el.find(container+' div.larrow').removeClass("active").addClass("inactive");
        panel.el.find(container+' div.rarrow').removeClass("inactive").addClass("active"); //just in case jumping from Z to A
      } else if(panel.el.find(container+' div.alphabet-div.active').html().match(activeLetters[1])) { 
        panel.el.find(container+' div.rarrow').removeClass("active").addClass("inactive");
        panel.el.find(container+' div.larrow').removeClass("inactive").addClass("active"); //just in case jumping from A to Z
      }else {
        panel.el.find(container+' div.larrow, div.rarrow').removeClass("inactive").addClass("active");
      }
    }
    
    //clicking the left and right arrow
    panel.elLk.arrows   = panel.el.find('div.rarrow, div.larrow', container);
    panel.elLk.arrows.on("click", function(e){
      if (!$(container, panel.el).hasClass('active')) {
        return; // run only for the active tab
      }

      // var availableRibbons = $(container, panel.elLk.trackPanel).find('.ribbon-banner .alphabet-div').not('.inactive');

      if(!this.className.match(/inactive/gi)) {
        panel.elLk.activeAlphabet = panel.el.find(container+' div.alphabet-div.active');
        if(this.className.match(/larrow/gi)) {
          //get currently selected letter, convert it to utf-16 number, ssubstract 1 to get previous letter number and then convert it to char; skipping letter with no content
          var prevLetter = ""; 
          for (var i = 1; i < 26; i++) {
            prevLetter =  String.fromCharCode(panel.elLk.activeAlphabet.html().charAt(0).toLowerCase().charCodeAt(0)- i);
            if(panel.el.find(container+" div."+prevLetter+"_content li").length) {
              break;
            }
          }

          $.when(
            panel.toggleTab(container+" div.ribbon_"+prevLetter, panel.el.find(container), 1)
          ).then(
            selectArrow()
          );

          if(panel.elLk.activeAlphabet.offset().left <= $(e.target).offset().left + 22) {
            var ribbon = panel.el.find(container+' div.letters-ribbon');
            ribbon.offset({left: ribbon.offset().left + 22});
            panel.el.find(container+" div."+prevLetter+"_content.alphabet-content").offset({left: panel.el.find(container+" div."+prevLetter+"_content.alphabet-content").offset().left + 22});
          }
        }

        if (this.className.match(/rarrow/gi)) {
          //get currently selected letter, convert it to utf-16 number add 1 to get next letter number and then convert it to char
          var nextLetter = "";
          for (var i = 1; i < 26; i++) {
            nextLetter =  String.fromCharCode(panel.elLk.activeAlphabet.html().charAt(0).toLowerCase().charCodeAt(0) + i);

            if(panel.el.find(container+" div."+nextLetter+"_content li").length) {
              break;
            }
          }

          $.when(
            panel.toggleTab(container+" div.ribbon_"+nextLetter, panel.el.find(container), 1)
          ).then(
            selectArrow()
          );

          var _nextletter = $("div.ribbon_"+nextLetter, panel.el.find(container));
          if(panel.elLk.activeAlphabet.offset().left  >= $(e.target).offset().left - 44) {
            ribbon = panel.el.find(container+' div.letters-ribbon');
            ribbon.offset({left: ribbon.offset().left - 22});
            panel.el.find(container+" div."+nextLetter+"_content.alphabet-content").offset({left: panel.el.find(container+" div."+nextLetter+"_content.alphabet-content").offset().left - 22});
          }
        }
      }
      
    });
  }
});
