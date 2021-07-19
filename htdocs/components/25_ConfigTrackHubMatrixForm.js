/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2021] EMBL-European Bioinformatics Institute
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


Ensembl.Panel.ConfigTrackHubMatrixForm = Ensembl.Panel.ConfigMatrixForm.extend({
  init: function () {
    var panel = this;

    this.base(arguments);
    Ensembl.EventManager.register('modalPanelResize', this, this.resize);
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('updateFromTrackLabel', this, this.updateFromTrackLabel);
    Ensembl.EventManager.register('modalOpen', this, this.modalOpen);

    //getting the node id from the panel url (menu=) to pass to ajax request to get imageconfig
    var clickedLink   = this.params.clickedLink.find('a');
    var clickedHref   = clickedLink.attr('href');

    var menu_match    = clickedHref.match(/menu=([^;&]+)/g);
    this.node_id      = menu_match[0].split("=")[1];
    var species_match = clickedHref.match(/th_species=([^;&]+)/g);
    var species_name  = species_match[0].split("=")[1];
    var menu_span_on  = clickedLink.siblings('.count').children('.on')[0];

    this.disableYdim = window.location.href.match("Regulation/Summary") ? 1 : 0;

    this.elLk.dx        = {};
    this.elLk.dx.container = $('div#dx-content', this.el);

    this.elLk.dy        = {};
    this.elLk.dy.container = $('div#dy-content', this.el);

    this.elLk.other_dimensions = {};

    this.elLk.buttonTab       = this.el.find("div.track-tab");    
    this.elLk.trackPanel      = this.el.find(".track-panel#track-content");
    this.elLk.matrixContainer = this.el.find('div.matrix-container');
    this.elLk.filterMatrix    = this.el.find('div.filterMatrix-container');
    this.elLk.filterTrackPanel   = this.el.find(".track-panel#filter-content");
    this.elLk.trackConfiguration = this.el.find(".track-panel#configuration-content");
    this.elLk.resultBox       = this.el.find(".result-box#selected-box");
    this.elLk.filterList      = this.el.find("ul.result-list");
    this.elLk.filterTrackBox  = this.el.find(".result-box#filter-box");
    this.elLk.configResultBox = this.el.find(".result-box#config-result-box");
    this.elLk.displayButton   = this.el.find("button.showMatrix");
    this.elLk.viewTrackButton = this.el.find("button.view-track-button");
    this.elLk.clearAll        = this.el.find("span.clearall");
    this.elLk.ajaxError       = this.el.find('span.error._ajax');
    this.localStoreObj        = new Object();
    this.localStorageKey      = this.node_id+'-TrackHubMatrix-' + Ensembl.species;
    this.elLk.lookup          = new Object();
    this.trackHub             = true;
    this.multiDimFlag         = 0;
    this.menuCountSpan        = menu_span_on;
    this.rendererSelectDropdown = this.el.find('div.track-popup .renderer-selection .renderers')

    this.buttonOriginalWidth = this.elLk.displayButton.outerWidth();
    this.buttonOriginalHTML  = this.elLk.displayButton.html();
    this.matrixLoadState     = true;
    this.json = {};
    this.searchTerms = {};


    // Mapping of renderer type and text to display in matrix popup
    this.rendererTextMap = {
      'normal' : 'Normal',
      'compact': 'Peaks',
      'signal' : 'Signal',
      'signal_feature' : 'Peaks & Signal',
      'as_alignment_nolabel' : 'Normal',
      'as_alignment_label' : 'Labels',
      'as_transcript_label' : 'Structure with labels',
      'as_transcript_nolabel' : 'Structure',
      'half_height' : 'Half height',
      'stack' : 'Stacked',
      'unlimited' : 'Stacked unlimited',
      'ungrouped' : 'Ungrouped',
      'coverage_with_reads' : 'Coverage',
      'histogram' : 'Histogram',
      'as_collapsed_nolabel' : 'Collapsed',
      'as_collapsed_label' : 'Collapsed with labels'
    };

    this.rendererConfig = {
      'bigbed': [ 'as_alignment_nolabel', 'as_alignment_label', 'as_transcript_nolabel', 'as_transcript_label', 'half_height', 'stack', 'unlimited', 'ungrouped' ],
      'bigwig': [ 'normal', 'compact', 'signal', 'signal_feature' ],
      'biggenepred': [ 'as_alignment_nolabel', 'as_alignment_label', 'as_collapsed_nolabel', 'as_collapsed_label', 'as_transcript_nolabel', 'as_transcript_label', 'half_height', 'stack', 'unlimited', 'ungrouped' ],
      'bigint': [ 'interaction' ],
      'bam': [ 'coverage_with_reads', 'unlimited', 'histogram' ],
      'vcf': [ 'as_alignment_nolabel', 'as_alignment_label', 'half_height', 'stack', 'unlimited', 'ungrouped', 'difference' ]
    };


    this.resize();
    panel.el.find("div#dy-tab div.search-box").hide();

    var url;
    if (panel.node_id.match(/Blueprint_Hub/)) {
      url = '/trackhubdata/'+panel.node_id+'.json';
    }
    else {
      url = '/Json/TrackHubData/data?th_species='+species_name+';menu='+panel.node_id+';ictype='+panel.params['image_config_type'];
    }

    $.ajax({
      url: url,
      dataType: 'json',
      context: this,
      async: false,
      success: function(data) {
        if(this.checkError(data)) {
          console.log("Fetching main trackhub data error....");
          return;
        } else {
          panel.elLk.ajaxError.hide();
        }
        this.rawJSON = data;
        this.buildJSON();
        $(this.el).find('div.spinner').remove();
        this.switchBreadcrumb();
        this.trackTab();
        this.populateLookUp();
        this.loadState();
        this.renameTrackButton();
        this.setDragSelectEvent();
        this.registerRibbonArrowEvents();
        this.addExtraDimensions();
        this.goToUserLocation();
        this.resize();
        this.selectDeselectAll();
      },
      error: function() {
        $(this.el).find('div.spinner').remove();
        this.showError();
        return;
      }
    });

    this.elLk.buttonTab.on("click", function (e) {
      var activeTab = panel.getActiveTab();
      if (e.target.nodeName !== 'INPUT' && e.currentTarget.id !== activeTab+'-tab') {
        if(panel.elLk.trackPanel.find('input[name="matrix_search"]').val()) {
          panel.elLk.trackPanel.find('input[name="matrix_search"]').val('');
          panel.elLk.searchCrossIcon.hide();
          panel.resetFilter(); // Reset filter on the active tab
        }
      }
      panel.toggleTab({'selectElement': this, 'container': panel.el.find("div.track-menu")});
      panel.resize();
    });

    this.clickSubResultLink();
    this.registerShowHideClickEvent();
    this.clickCheckbox(this.elLk.filterList);
    this.clearAll(this.elLk.clearAll);
    this.clearSearch();
    this.resetTracks();
    this.resetMatrix();
    this.registerResetFilterMatrixClickEvent();

    panel.el.on("click", function(e){
      //if not switch for setting on/off column/row/cell in cell popup
      if(!$(e.target).closest('.track-popup').length && panel.trackPopup) {
        panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off').removeClass("mClick");
        panel.trackPopup.hide();
      }

      if(!$(e.target).closest('ul.cell').length && panel.trackPopup) {
        panel.el.find('.renderer-selection div.renderers').removeClass('active');
      }

      if (!$(e.target).closest('.filter-rhs-popup').length) {
        $('.filter-rhs-popup', panel.elLk.filterTrackBox).hide();
      }
    });

    this.elLk.filterMatrix.on('scroll', function() {
      panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off').removeClass("mClick");
      panel.trackPopup.hide();
    });

    this.elLk.matrixContainer.on('scroll', function() {
      panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off').removeClass("mClick");
      panel.trackPopup.hide();
    });

    this.el.find('.view-track, .view-track-button, button.showMatrix').on('click', function() {
      if($(this).hasClass('_edit') || ($(this).hasClass('view-track') && !$(this).hasClass('inactive')) || ($(this).hasClass('view-track-button') && $(this).hasClass('active'))) {
        panel.addExtraDimensions();
        Ensembl.EventManager.trigger('modalClose');
      }
    });

    //this has to be after on click event to capture the button class before it gets changed
    this.clickDisplayButton(this.elLk.displayButton, this.el.find("li#track-display"));

    //multidimension trackhub: configure track display button on filter panel to go to final matrix
    this.clickDisplayButton(panel.el.find('button.filterConfigButton'), this.el.find("li#track-display"));

    // Search functionality
    this.elLk.trackPanel.find('input[name="matrix_search"]').on('input', function(e) {
      var inputText = $(this).val().trim();

      if(inputText) {
        panel.elLk.searchCrossIcon.show();
      }else {
        panel.elLk.searchCrossIcon.hide();
      }

      if (!panel.resetFilter(inputText,true)) {
        return;
      };

      var activeTabId = panel.getActiveTab();
      var re = new RegExp(inputText, "gi");
      var match = Object.keys(panel.elLk.lookup).filter(function(name) {
        return name.match(re) && panel.elLk.lookup[name].parentTabId === activeTabId;
      });

      $.each(panel.searchTerms, function(k, v) {
        if (k.match(re)) {
          match.push(v);
        }
      })

      var match_uniq = $.unique(match);

      if (match_uniq.length) {
        panel.elLk[activeTabId].container.find("span.search-error").hide();
        panel.elLk[activeTabId].container.find("div.selectall-container div.select-link, div.selectall-container div.divider").show();
        var classString = '.' + match_uniq.join(',.');
        var li_arr = panel.elLk.lookup[match_uniq[0]].parentTab.find('li').not(classString);
        $.each(li_arr, function(i, li) {
          if ($(li).css('display') !== 'none') {
            $(li).addClass('_search_hide').hide();
          }
        });
      }
      else {
        panel.elLk[activeTabId].container.find('li').addClass('_search_hide').hide();
        panel.elLk[activeTabId].container.find("span.search-error").show();
        panel.elLk[activeTabId].container.find("div.selectall-container div.select-link, div.selectall-container div.divider").hide();
      }
      panel.updateAvailableTabsOrRibbons(activeTabId, true);
    });

    if(this.disableYdim) {
      panel.el.find('h5.result-header._dyHeader, div#dy, div._dyMatrixHeader').hide();
      panel.el.find('button.reset-button._matrix').css("margin-top","0");
      panel.el.find('div#dy-tab').addClass("inactive").attr("title","No Experimental evidence is available for this view");
    } else {
      panel.el.find('h5.result-header._dyHeader, div#dy').show();
      panel.el.find('div#dy-tab').removeClass("inactive").attr("title", "");
    }
  },

  dropDown: function(panel, defaultVal) {
    this.dd = panel.rendererSelectDropdown;
    this.placeholder = this.dd.children('span');
    this.placeholder.html(panel.rendererTextMap[defaultVal]);
    this.opts = this.dd.find('ul.dropdown > li');
    this.opts.removeClass('selected');
    this.opts.each(function(i, li) {
      if($(li).hasClass(defaultVal)) {
        $(li).addClass('selected');
      }
    });
    this.val = '';

    var obj = this;

    obj.dd.off().on('click', function(event){
      $(this).toggleClass('active');
      return false;
    });

    obj.opts.off().on('click',function(){
      var opt = $(this);
      opt.siblings().removeClass('selected');
      opt.addClass('selected');
      obj.val = opt.children('i').attr('class');
      obj.placeholder.text(opt.text());
      panel.updateRenderer(obj.val);
    });
  },

  // Function to create the relationship between the different track
  buildJSON: function() {
    var panel = this;

    var dimX, dimY;
    var finalObj = {};
    var filterObj = {};
    var dimLabels = {};
    finalObj.extra_dimensions = []; //it needs to be in the json and empty so that code know there is no extra dimensions
    var storeObj = panel.getLocalStorage();
    var updateStore = false;
    this.initialLoad = 1; //this is used to load all the default/preset tracks on first

    //flag for multi dimensional trackhub
    if(Object.keys(panel.rawJSON.metadata.dimensions).length > 2) {
      panel.multiDimFlag = 1;
    };

    //Populating the dimensions and data for each dimension
    if($.isEmptyObject(finalObj.dimensions)) {
      //the dimensions have been flipped here so that it draws the x and y as x-axis and y-axis, cant change the drawMatrix code as too much changes are involved. Its not the right way but will do for now. In regulation matrix its the other way round. Confusing....
      dimX = panel.rawJSON.metadata.dimensions.y.key;
      dimY = panel.rawJSON.metadata.dimensions.x.key;

      finalObj.dimensions = [dimX,dimY];
      finalObj.data = {};
      finalObj.format = {};
      panel.elLk.lookup.dimensionFilter = {};
      //getting dimY data, assuming subgroup2 is always dimY
      var dimYData = {};
      $.each(Object.keys(panel.rawJSON.metadata.dimensions.x.values), function(index, value) {
        dimYData[value] = {name: value.replace("_", " ")};
      });

      var dimXData = {};
      var tempObj = {};    
      //getting dimX data and the relationship
      $.each(panel.rawJSON.tracks, function(i, track){
        var renderer, defaultState;
        if(track.display && track.display != "off") {
          renderer  =  track.display; //track.default_display is the default renderer for this track
        } else {
          renderer  =  track.defaultDisplay; //track.default_display is the default renderer for this track
        }

        var keyX      = track.subGroups[dimX];
        var keyY      = track.subGroups[dimY];
        
        //multi dimension work
        var fkey      = keyY + '_sep_' + keyX;
        var dimKey;
        $.each(track.subGroups, function(dimension, trackName){
          if (panel.multiDimFlag) {
            if (dimension !== dimX && dimension !== dimY && dimension !== 'view') {
              dimKey        = dimension + '_sep_' + track.subGroups[dimension];
              filterObj[fkey] = filterObj[fkey] || {};
              filterObj[fkey][track.id] = filterObj[fkey][track.id] || {};
              filterObj[fkey][track.id]["data"] = filterObj[fkey][track.id]["data"]  || {};
              filterObj[fkey][track.id]["data"][dimKey] = track.display === "off" ? "off" : "on";

              if (track.shortLabel) { filterObj[fkey][track.id]["shortLabel"] = track.shortLabel; }
              if (track.longLabel)  { filterObj[fkey][track.id]["longLabel"]  = track.longLabel;  }

              if(track.display && $.isEmptyObject(storeObj["other_dimensions"]) && panel.initialLoad) {
                updateStore = true;

                if($.isEmptyObject(panel.localStoreObj["other_dimensions"])) {
                  panel.localStoreObj["other_dimensions"] = {};
                  panel.localStoreObj["other_dimensions"][dimKey] = 1;
                }else {
                  panel.localStoreObj["other_dimensions"][dimKey] = 1;
                }
              }

              filterObj[fkey][track.id]["show"] = 1;

              // Populating lookup
              panel.elLk.lookup.dimensionFilter[dimKey] = panel.elLk.lookup.dimensionFilter[dimKey] || {};
              panel.elLk.lookup.dimensionFilter[dimKey][fkey] = panel.elLk.lookup.dimensionFilter[dimKey][fkey] || [];
              panel.elLk.lookup.dimensionFilter[dimKey][fkey].push(track.id);
            }
          }

          if(dimension !== dimY) { return; }

          if(track.display && track.display != "off" && $.isEmptyObject(storeObj["matrix"]) && panel.initialLoad ) {
            updateStore = true;
            defaultState = "track-on";
            finalObj.format[track.format.toLowerCase()] = finalObj.format[track.format.toLowerCase()]+1 || 1;
            if($.isEmptyObject(panel.localStoreObj["dx"])) {
              panel.localStoreObj["dx"] = {};
              panel.localStoreObj["dx"][keyX] = 1;
            }else {
              panel.localStoreObj["dx"][keyX] = 1;
            }
            if($.isEmptyObject(panel.localStoreObj["dy"])) {
              panel.localStoreObj["dy"] = {};
              panel.localStoreObj["dy"][trackName] = 1;
            }else {
              panel.localStoreObj["dy"][trackName] = 1;
            }
          }

          if(track.display === "off") {
            defaultState = "track-off"
          }
          dimXData[keyX] = dimXData[keyX] || [];
          if (panel.multiDimFlag) {
            if(!tempObj[fkey]) {
              defaultState = "track-on";
              dimXData[keyX].push({"dimension": dimension, "val": trackName, "defaultState": defaultState, "id": track.id, "renderer": renderer, "format": track.format.toLowerCase() });
              tempObj[fkey] = 1;
            }
          } else {
            dimXData[keyX].push({"dimension": dimension, "val": trackName, "defaultState": defaultState, "id": track.id, "renderer": renderer, "format": track.format.toLowerCase() });
          }

        });
      });

      finalObj.data[dimX] = {"name": dimX, "label": panel.rawJSON.metadata.dimensions.y.label.replace('_', ' '), "listType": "simpleList", "data": dimXData };
      finalObj.data[dimY] = {"name": dimY, "label": panel.rawJSON.metadata.dimensions.x.label.replace('_', ' '), "listType": "simpleList", "data": dimYData };
    }

    panel.initialLoad = 0; //initialLoad done
    if(updateStore) {
      panel.localStoreObj.matrix = panel.getLocalStorage().matrix  || {};
      panel.localStoreObj.filterMatrix = panel.getLocalStorage().filterMatrix  || {};
      //state management object for user location
      panel.localStoreObj.userLocation = panel.getLocalStorage().userLocation || {};
      panel.localStoreObj["reset_other_dimensions"] = panel.localStoreObj["other_dimensions"] || {};
      panel.localStoreObj["reset_dx"] = panel.localStoreObj["dx"]  || {};
      panel.localStoreObj["reset_dy"] =  panel.localStoreObj["dy"] || {};
      panel.setLocalStorage();
    }

    panel.elLk.filterMatrixObj = filterObj;
    panel.json = finalObj;

    //setting rendererkeys
    this.elLk.lookup.rendererKeys = [];
    $.each(panel.json.format, function(key, val) {
      $.each(panel.rendererConfig[key], function(i, renderer) {
        panel.elLk.lookup.rendererKeys.push(renderer);
      });
    });
  },

  //Function to check if ajax request return 404 (Because bad request are returned as success with header: 404)
  checkError: function(json) {
    var panel = this;

    if(json.header.status === '404'){
      panel.showError();
      return 1;
    } else {
      return 0;
    }
  },

  //Function to show error when ajax request failed
  showError: function() {
    var panel = this;

    panel.elLk.ajaxError.show();
  },

  // Redraw matrix as there may be updates to localStore
  // e.g. updateFromTrackLabel method may remove some tracks from the RID view.
  modalOpen: function() {
    if(!this.localStoreObj || $.isEmptyObject(this.localStoreObj.userLocation)) { return; }
    this.emptyMatrix();
    this.displayFilterMatrix();
    this.displayMatrix();
    this.toggleButton();
    this.goToUserLocation();
  },

  // Set reset = true if you do not want to reset offset position
  resetFilter: function (inputText, reset) {
    var panel = this;

    panel.getActiveTabContainer().find('li._search_hide').removeClass('_search_hide');
    panel.getActiveTabContainer().find("span.search-error").hide();
    panel.getActiveTabContainer().find("div.selectall-container div.select-link, div.selectall-container div.divider").show();

    var _filtered = panel.getActiveTabContainer().find('li._filtered');
    if (_filtered.length) {
      _filtered.show();
    }
    else {
      panel.getActiveTabContainer().find('li').show();
    }

    var activeTabId = panel.getActiveTab();
    panel.updateAvailableTabsOrRibbons(activeTabId, true, reset);

    if (inputText && inputText.length < 3) {
      return 0;
    }
    else {
      return 1;
    }
  },

  // Udpate available tabs or ribbons after filtering
  updateAvailableTabsOrRibbons: function(tabId, resetRibbon, resetFilter) {
    var panel = this;
    var tabLookup = panel.elLk[tabId];
    var dimension_name = panel[tabId];

    if (!tabLookup.haveSubTabs) {
      // Update selectAll
      panel.activateAlphabetRibbon(tabLookup.container, resetRibbon, resetFilter);
    }
    else {
      // For subtabs
      var currentActiveTabId;
      var availableTabsWithData = [];
      $.each(Object.keys(panel.elLk[tabId].tabs), function(i, key) {
        if (tabLookup.tabs[key]) {
          var tab_ele = tabLookup.tabs[key];
          if ($(tab_ele).hasClass('active')) {
            currentActiveTabId = key;
          }

          // $(tab_ele).removeClass('active')
          var tab_content_ele = $('#' + key + '-content', panel.el.trackPanel);
          var lis = tabLookup.tabContents[key];
          var flag = 0;

          $(tabLookup.tabs[key]).addClass('inactive');

          $('li', tab_content_ele).each(function(i, li) {
            if ($(li).css('display') !== 'none') {
              flag = 1;
              return false;
            }
          });

          if (flag == 1) {
            flag = 0;
            $(tabLookup.tabs[key]).removeClass('inactive');
            availableTabsWithData.push(key);
          }

          // Activate available letters if list type is alphabetRibbon
          if (panel.json.data[panel[tabId]].data[key].listType === 'alphabetRibbon') {
            panel.activateAlphabetRibbon(tab_content_ele, resetRibbon, resetFilter);
          }

          // var visible = $('li:visible', tab_content_ele);
          var count = 0;
          $('li', tab_content_ele).each(function(i, li) {
            if ($(li).css('display') !== 'none') {
              count++;
            }
          });
        }

      });

      // If any of the final available tabs have class "active" then leave. If not move it to the first available
      if (availableTabsWithData.length && currentActiveTabId) {
        if(!currentActiveTabId || availableTabsWithData.indexOf(currentActiveTabId) < 0) {
          // Move to first active tab
          panel.toggleTab({
            'selectElement': $(tabLookup.tabs[availableTabsWithData[0]]),
            'container': $(tabLookup.tabs[availableTabsWithData[0]]).parent(),
            'searchTriggered': true
          });
        }
      }
    }
  },

  activateAlphabetRibbon: function(alphabetContainer, resetRibbon, resetFilter) {
    var panel = this;
    var activeRibbon, activeRibbonClass;
    var flag = 0;

    var alphabetRibbonDivs = alphabetContainer.find('.ribbon-banner .alphabet-div');
    var alphabetRibbonContentDivs = alphabetContainer.find('.ribbon-content .alphabet-content');
    var selectedActiveRibbon = alphabetContainer.find('.ribbon-content .alphabet-content.active');

    $(alphabetRibbonDivs).removeClass('active').addClass('inactive');

    var li = alphabetContainer.find('li');

    var availableRibbonContainers = $(li).closest('.alphabet-content');
    var arr = {};

    $.each(availableRibbonContainers, function(i, ribbonContent) {
      $('li', ribbonContent).each(function(i, li) {
        if ($(li).css('display') !== 'none') {
          flag = 1;
          return false;
        }
      });
      if (flag == 1) {
        flag = 0;
        activeRibbonData = $(ribbonContent).data('ribbon');
        activeRibbonClass = '.' + activeRibbonData;
        activeRibbon = alphabetRibbonDivs.not(':not("'+activeRibbonClass+'")');
        activeRibbon.removeClass('inactive');
        arr[activeRibbonData] = activeRibbon;
      }
    });

    var currentlySelected = selectedActiveRibbon.data('ribbon');
    var obj = {'container': alphabetContainer, 'selByClass': 1, 'resetRibbonOffset': resetRibbon, 'searchTriggered': true}
    obj.resetFilter = resetFilter && true;

    if (arr[currentlySelected] && !resetFilter) {
      obj.selectElement = arr[currentlySelected];
      panel.toggleTab(obj);
    }
    else {
      // console.log('activating first available', alphabetContainer.attr('id'));
      obj.selectElement = arr[Object.keys(arr).sort()[0]];
      obj.searchTriggered = false;
      panel.toggleTab(obj);
    }

    // Activate arrows
    var activeAlphabets = panel.getActiveAlphabets(alphabetContainer);
    var larrow = alphabetContainer.find('.ribbon-banner .larrow');
    var rarrow = alphabetContainer.find('.ribbon-banner .rarrow');

    $(larrow, rarrow).removeClass('inactive active');
    if (activeAlphabets.length <= 0) {
      $(larrow).addClass('inactive');
      $(rarrow).addClass('inactive');
      return;
    }

    if ($(activeAlphabets[0]).hasClass('active')) {
      $(larrow).addClass('inactive');
      (activeAlphabets.length > 1) && $(rarrow).addClass('active');
    }
    else {
      $(larrow).removeClass('inactive').addClass('active');
    }

    if ($(activeAlphabets[activeAlphabets.length-1]).hasClass('active')) {
      $(rarrow).addClass('inactive');
      (activeAlphabets.length > 1) && $(larrow).addClass('active');
    }
    else {
      $(rarrow).removeClass('inactive').addClass('active');
    }
  },

  addExtraDimensions: function() {
    var panel = this;
    // Add extra columns data to lookup (for reg feats)
    if (panel.json.extra_dimensions) {
      panel.json.extra_dimensions.forEach(function(dim) {
        panel.elLk.lookup[dim] = panel.json.data[dim];
      });
    }
  },

  // Called by triggerSpecific from the parent Configurator panel.
  // Does not cause an AJAX request, just returns the diff data.
  updateConfiguration: function () {

    var panel  = this;
    var config = {};
    var key, prefix;
    var arr = [];

    //resetting filter box and content
    panel.elLk.searchCrossIcon.parent().find('input.configuration_search_text').val("");
    panel.resetFilter("", true);

    //store on which tab the user is on
    panel.localStoreObj.userLocation && panel.setUserLocation();

    // If no matrix available in localstore, that means user hasn't clicked on "Configure Display" button
    // In that case, call displayMatrix() to create the necessary localStore objects
    if (Object.keys(panel.localStoreObj).length <= 0 || !panel.localStoreObj.dx) {
      return {image_config: {}};
    }

    if (!panel.localStoreObj.matrix) {
      return;
    }

    if (!panel.multiDimFlag) {
      $.each(panel.localStoreObj.matrix, function (k, v) {
        if (k.match(/_sep_/)) {
          if (v.state) {
            key = '';
            arr = k.split('_sep_');
            // key = 'trackhub_' + panel.node_id + '_' + panel.elLk.lookup[arr[1]].label;
            config[v.id] = { renderer : v.state === 'track-on' ? v.renderer : 'off'};
            if (v.id && config[v.id].renderer !== 'off') {
              // Track key is a unique id for the track created by ImageConfigExtension/UserTracks
              // which is a combination of submenu_key(node_id) and track name;
              var trackId = v.id;
              config[trackId] = { renderer: v.renderer };
            }
          }
        }
      });
    }
    else {
      $.each(panel.localStoreObj.filterMatrix, function (k, v) {
        if (k.match(/_sep_/)) {
          $.each(panel.localStoreObj.filterMatrix[k].data, function (trackId, data) {
            config[trackId] = { renderer: (data.show && data.state == "on" && panel.localStoreObj.matrix[k].state !== 'track-off') ? panel.localStoreObj.matrix[k].renderer : 'off' };
          })
        }
      });
    }

    Ensembl.EventManager.trigger('changeMatrixTrackRenderers', config);

    $.extend(this.imageConfig, config);
    return { imageConfig: config, menu_id: this.node_id, matrix: 1 };
  },

  updateFromTrackLabel: function(update) {
    // Update the matrix when the track label popup functionality is triggered
    var panel  = this;
    var trackKey = update[0];
    var trackDisplay = update[1];
    if (!trackKey) { return; }

    var config = {};
    var section, epigenome;
    // Are we updating a regulatory feature?
    if (panel.localStoreObj.epigenomic_activity && trackKey.match(/^reg_feat/)) {
      section   = 'epigenomic_activity';
      epigenome = trackKey.split(/_/).pop();
    }
    // or a segmentation feature?
    else if (panel.localStoreObj.segmentation_features && trackKey.match(/^seg_Segmentation/)) {
      section   = 'segmentation_features';
      epigenome = trackKey.split(/_/).pop();
    }
    var trackName = section + '_sep_' + epigenome;

    // Update localStore with new settings
    if (trackDisplay == 'off') {
      panel.localStoreObj[section][section].state.on--;
      panel.localStoreObj[section][section].state.off++;
      panel.localStoreObj[section][trackName].state = 'track-off';
    }
    else {
      panel.localStoreObj[section][section].state.off--;
      panel.localStoreObj[section][section].state.on++;
      panel.localStoreObj[section][trackName].state = 'track-on';
      panel.localStoreObj[section][trackName].renderer = trackDisplay;
    }

    // Finally update the matrix
  },

  getNewPanelHeight: function() {
    return $(this.el).closest('.modal_content.js_panel').outerHeight() - 160;
  },

  resize: function() {
    var panel = this;
    if (Object.keys(panel.elLk).length <= 0) return;

    var panel_ht = panel.getNewPanelHeight();

    panel.elLk.resultBox.outerHeight(panel_ht);
    if (panel.elLk[this.getActiveTab()].haveSubTabs) {
      $.each(panel.elLk[this.getActiveTab()].tabContentContainer, function(tabName, tabContent) {
        var ul = $('ul', tabContent);
        ul.outerHeight(panel_ht - 170);
      });
      panel.elLk.trackPanel.find('.ribbon-content ul').outerHeight(panel_ht - 190);
    }
    else {
      panel.elLk.trackPanel.find('.ribbon-content ul').outerHeight(panel_ht - 140);
    }
    panel.elLk.dx.container.find('ul.list-content').height(panel_ht - 120);

    var rhs_height = $(this.el).find('div.result-box:visible').outerHeight();
    var new_ht = panel_ht - 160;
    if (rhs_height > panel_ht) {
      new_ht = rhs_height;
    }
    panel.elLk.matrixContainer.outerHeight(new_ht - 102);
    panel.elLk.filterMatrix.outerHeight(new_ht - 102);

  },

  getActiveTabContainer: function() {
    return $('div#dx-content.active, div#dy-content.active', this.el);
  },
  getActiveTab: function() {
    return $('div#dx-content.active span.rhsection-id, div#dy-content.active span.rhsection-id', this.el).html();
  },
  getActiveSubTab: function() {
    return $('div#dx-content.active .tab-content.active span.rhsection-id, div#dy-content.active .tab-content.active span.rhsection-id', this.el).html();
  },

  populateLookUp: function() {
    var panel = this;
    // cell elements
    this.elLk.dx.ribbonBanner = $('.ribbon-banner .letters-ribbon .alphabet-div', this.elLk.dx.container);
    this.elLk.dx.tabContents = panel.json.data[panel.dx].listType === 'alphabetRibbon' ? $('.ribbon-content li', this.elLk.dx.container) : $(' li', this.elLk.dx.container);
    this.elLk.dx.haveSubTabs = false;

    // ExpType elements
    this.elLk.dy.haveSubTabs = false;
    this.elLk.dy.tabs = {}
    this.elLk.dy.tabContents = panel.json.data[panel.dy].listType === 'alphabetRibbon' ? $('.ribbon-content li', this.elLk.dy.container) : $(' li', this.elLk.dy.container);
    panel.elLk.dy.tabContentContainer = {};
    var dyTabs = $('.tabs.dy div.track-tab', this.elLk.dy.container);
    $.each(dyTabs, function(i, el) {
      var k = $(el).attr('id').split('-')[0] || $(el).attr('id');
      panel.elLk.dy.tabs[k] = el;
      var contentId = '#'+k+'-content';
      panel.elLk.dy.tabContentContainer[k] = panel.elLk.dy.container.find(contentId);
      var tabContentId = $('span.content-id', el).html();
      panel.elLk.dy.tabContents[k] = $('div#' + tabContentId + ' li', panel.elLk.dy.container);
    });
  },

  loadState: function() {
    var panel = this;
    this.loadingState = true;
    this.localStoreObj = this.getLocalStorage();
    if (!Object.keys(this.localStoreObj).length) {
      this.loadingState = false;
      return;
    }

    // Apply cell first so that filter happens and then select all experiment types
    if (this.localStoreObj.dx) {
      var el;
      $.each(this.localStoreObj.dx, function(k) {
        el = panel.elLk.dx.tabContents.not(':not(.'+ k +')');
        panel.selectBox(el);
      });
      panel.filterData($(el).data('item'));
    }
    if (this.localStoreObj.dy) {
      var el, subTab;
      $.each(this.localStoreObj.dy, function(k) {
        //subTab = panel.elLk.lookup[k].subTab;
        el = panel.elLk.dy.tabContents.filter(function() {return $(this).hasClass(k)});
        panel.selectBox(el);
      });

      // If there were no celltypes selected then filter based on exp type
      !this.localStoreObj.dx && this.localStoreObj.dy && panel.filterData($(el).data('item'));
    }

    panel.updateRHS();

    this.loadingState = false;
  },

  //Rename track button to filter tracks if it is multidimensional trackhub
  renameTrackButton: function() {
    var panel = this;

    if(panel.multiDimFlag) {
      panel.el.find('button.showMatrix').outerWidth("110px").html("Filter tracks").removeClass("_edit").addClass("_filterButton");
    } else {
      panel.el.find('button.showMatrix').outerWidth(panel.buttonOriginalWidth).html(panel.buttonOriginalHTML).removeClass("_edit _filterButton");
    }
  },

  setUserLocation: function() {
    var panel = this;

    if (!panel.localStoreObj.userLocation) {
      return;
    }
    //get current active panel (either select tracks or matrix)
    panel.localStoreObj.userLocation.view = panel.elLk.breadcrumb.filter(".active").attr("id");
    if(panel.elLk.trackPanel.hasClass("active")) {
      panel.localStoreObj.userLocation.tab = panel.elLk.trackPanel.find("div.track-menu div.track-tab.active").attr("id");
    } else {
      panel.localStoreObj.userLocation.tab = "";
    }
    panel.setLocalStorage();
  },

  goToUserLocation: function() {
    var panel = this;

    if(!panel.localStoreObj || $.isEmptyObject(panel.localStoreObj.userLocation)) { return; }

    panel.toggleBreadcrumb(panel.localStoreObj.userLocation.view ? '#'+panel.localStoreObj.userLocation.view : "#track-select");
    if(panel.localStoreObj.userLocation.tab){
      panel.toggleTab({'selectElement': '#'+panel.localStoreObj.userLocation.tab, 'container': panel.el.find("div.track-menu")});
    }
  },

  setDragSelectEvent: function() {
    var panel = this;

    if (this.dragSelect) return;

    this.dragSelect = new Selectables({
      elements: 'li span',
      // selectedClass: 'selected',
      zone: '._drag_select_zone',
      onSelect: function(el) {
        panel.selectBox(el.parentElement, 1);
        this.el = el.parentElement;
      },
      stop: function() {
        var item = $(this.el).data('item');
        // Making sure if item is from the active tab
        if (item && panel.elLk.lookup[item].parentTabId === panel.getActiveTab()) {
          panel.filterData(item);
          panel.updateRHS();
        }
      }
    });
  },

  //function when click clear all link which should reset all the filters
  clearAll: function (clearLink) {
    var panel = this;

    clearLink.on("click",function(e){
      $.each(panel.elLk.resultBox.find('li').not(".noremove"), function(i, ele){
        panel.selectBox(ele);
      });
    });

  },

  clearSearch: function() {
    var panel = this;

    panel.elLk.searchCrossIcon = panel.elLk.buttonTab.find('span.search-cross-icon');

    panel.elLk.searchCrossIcon.click("on", function(){
      panel.getActiveTabContainer().find("span.search-error").hide();
      panel.getActiveTabContainer().find("div.selectall-container div.select-link, div.selectall-container div.divider").show();
      $(this).parent().find('input.configuration_search_text').val("");
      panel.resetFilter("", true);
      panel.elLk.searchCrossIcon.hide();
      panel.elLk.searchCrossIcon.parent().find('input').focus();
    });
  },

  // Function to check divs that needs to have content to enable or disable apply filter button
  // Argument: ID of div to check for content
  enableConfigureButton: function (content) {
    var panel = this;

    var total_div = panel.el.find(content).length;
    var counter   = 0;

    panel.el.find(content).each(function(i, el){
      if($(el).find('li').length && $(el).find('span.fancy-checkbox.selected').length) {
        counter++;
      }
    });

    if(counter === total_div) {
      panel.el.find('li.view-track').removeClass('inactive');
      panel.el.find('li._configure').removeClass('inactive');
      panel.elLk.displayButton.addClass('active');
    } else {
      panel.el.find('li.view-track').addClass('inactive');
      panel.el.find('li._configure').addClass('inactive');
      panel.elLk.displayButton.removeClass('active');
    }
  },

  //function to show/hide error message for empty track filters
  // Argument: containers where to listen for empty elements (Note: span error id should match container id with an underscore)
  trackError: function(containers) {
    var panel = this;
    var error = 0;

    panel.el.find(containers).each(function(i, ele) {
      var error_class = "_" + $(ele).attr('id');
      if ($(ele).find('li').length && $(ele).find('span.fancy-checkbox.selected').length) {
        var header = $(ele).prev(".result-header").data('header');
        $(ele).prev(".result-header").html(header).removeClass('error');
      } else {
        error = 1;
        var header = $(ele).prev(".result-header").data('header');
        $(ele).prev(".result-header").html('Please select ' + header).addClass('error');
      }
    });
    if(error) {
      panel.elLk.viewTrackButton.removeClass('active').addClass('inactive');
    } else {
      panel.elLk.viewTrackButton.removeClass('inactive').addClass('active');
    }
  },

  // Function to update the current count in the right hand panel (can be adding/removing 1 or select all)
  // Argument: element/container object where current count is to be updated
  //           how much to add to the current value
  updateCurrentCount: function(key, selected, total) {
    var panel = this;
    if(key) {
      panel.el.find('#'+key+' span.current-count', this.elLk.resultBox).html(selected);
      panel.el.find('#'+key+' span.total', this.elLk.resultBox).html(total);
    }
  },

  //function when clicking on the select all | deselect all link
  // it will either select all checkbox or unselect all checkbox and apply filtering where there is !no-filter
  selectDeselectAll: function() {
    var panel = this;

    panel.el.find('div.selectall-container div.select-link').on("click", function(e){
      var selected = $(this).hasClass('all-box');
      var _class   = '';

      if ($(this).closest('.tab-content').find('li._filtered').length) {
        _class = '._filtered';
      }

      var available_LIs = $(this).closest('.tab-content').find('li' + _class + ':not("._search_hide")');
      var availableFancyCheckBoxes = available_LIs.find('span.fancy-checkbox');

      if (selected) {
        availableFancyCheckBoxes.addClass("selected");
        available_LIs.addClass("_selected");
      }
      else {
        availableFancyCheckBoxes.removeClass('selected');
        available_LIs.removeClass("_selected");
      }

      // add 'selected: true/flase' to lookup
      available_LIs.map(function() {
        panel.elLk.lookup[$(this).data('item')].selected = selected;
      });

      var ele = available_LIs.data('item');
      panel.filterData(ele);
      panel.updateRHS();
      e.stopPropagation();
    });
  },

  // Function to select/unselect checkbox and removing them from the right hand panel (optional) and adding them to the right hand panel (optional)
  //Argument: container is an object where the checkbox element is
  clickCheckbox: function (container) {
    var panel = this;
    var itemListen = "li";
    if(container[0] && container[0].nodeName === 'DIV') {
      itemListen = "";
    }
    //clicking checkbox
    $(container).off().on("click", itemListen, function(e) {
      panel.selectBox(this);

      // If all LIs are removed then disable configuration tab and toggle to select tracks tab
      if ($(this).closest('ul.result-list').children('li').length > 1){
        // checking > 1 because the last li is still not removed at this point
        panel.removeFromMatrix($(this).data('item'));
      }
      else {
        panel.toggleButton();
        $(this).closest('.result-content').find('.sub-result-link').click();
      }

      var ele = $(this).data('item');

      panel.filterData(ele);
      panel.updateRHS();
      e.stopPropagation();
    });
  },

  removeFromMatrix: function(item) {
    var panel = this;
    if (!item) return;
    panel.elLk.trackConfiguration.find('.matrix-container .' + item + ', .matrix-container ._emptyBox_' + item).remove();
    var allStoreObjects = $.extend({}, panel.localStoreObj.matrix);

    $.each(panel.json.extra_dimensions,function(i, dim){
      $.extend(allStoreObjects, panel.localStoreObj[dim]);
    });

    // Update localStoreObj and local storage
    Object.keys(allStoreObjects).map(function(key) {
      if (key.match(item+'_sep_') || key.match('_sep_' + item)) {
        var storeObjKey = panel.itemDimension(key);
        //update other rows/columns in store when removing item
        var cellCurrState    = panel.localStoreObj[storeObjKey][key]["state"].replace("track-","");
        var cellCurrRenderer = panel.localStoreObj[storeObjKey][key]["renderer"];

        $.each(key.split("_sep_"),function(i, associatedEle){
          if(associatedEle != item) {
            var splitObjKey = panel.itemDimension(associatedEle);
            if(panel.localStoreObj[splitObjKey][associatedEle]["total"] > 0)  {
              panel.localStoreObj[splitObjKey][associatedEle]["total"] -= 1;
            }
            if(panel.localStoreObj[splitObjKey][associatedEle]["state"][cellCurrState] > 0) {
              panel.localStoreObj[splitObjKey][associatedEle]["state"][cellCurrState] -= 1;
              panel.localStoreObj[splitObjKey][associatedEle]["state"]["reset-"+cellCurrState] -= 1;
            }
            if(panel.localStoreObj[splitObjKey][associatedEle]["renderer"][cellCurrRenderer] > 0) {
              panel.localStoreObj[splitObjKey][associatedEle]["renderer"][cellCurrRenderer] -= 1;
              panel.localStoreObj[splitObjKey][associatedEle]["renderer"]["reset-"+cellCurrRenderer] -= 1;
            }

            //updating all selection
            if(panel.localStoreObj[splitObjKey]["allSelection"]["total"] > 0)  {
              panel.localStoreObj[splitObjKey]["allSelection"]["total"] -= 1;
            }
            if(panel.localStoreObj[splitObjKey]["allSelection"]["state"][cellCurrState] > 0) {
              panel.localStoreObj[splitObjKey]["allSelection"]["state"][cellCurrState] -= 1;
              panel.localStoreObj[splitObjKey]["allSelection"]["state"]["reset-"+cellCurrState] -= 1;
            }
            if(panel.localStoreObj[splitObjKey]["allSelection"]["renderer"][cellCurrRenderer] > 0) {
              panel.localStoreObj[splitObjKey]["allSelection"]["renderer"][cellCurrRenderer] -= 1;
              panel.localStoreObj[splitObjKey]["allSelection"]["renderer"]["reset-"+cellCurrRenderer] -= 1;
            }
          }
        });
        delete panel.localStoreObj[storeObjKey][key];
      }
    });
    delete panel.localStoreObj[panel.itemDimension(item)][item];

    panel.setLocalStorage();
  },

  updateRHS: function(item) {
    var panel = this;
    panel.updateSelectedTracksPanel(item);
    // panel.activateTabs();
    panel.updateShowHideLinks(panel.elLk.filterList);
    panel.setLocalStorage();
    panel.trackError('div#dx, div#dy');
    panel.enableConfigureButton('div#dx, div#dy');
    if (Object.keys(panel.localStoreObj).length > 0 && panel.localStoreObj.dx) {
      panel.emptyMatrix();
      panel.displayFilterMatrix();
      // This mehod is called here only to update localStorage so that if an epigenome is selected, users can still view tracks
      // If this becomes a performance issue, separate localStorage and matrix drawing in displayMatrix method
      panel.displayMatrix();
    }
  },
  
  updateLHMenu: function() {
    // update LH menu count
    var panel = this;
    var menuTotal = 0;
    var matrixObj = this.multiDimFlag ? panel.localStoreObj.filterMatrix : panel.localStoreObj.matrix;
    for (var column in matrixObj) {
      if (column.match('_sep_') && matrixObj[column]['state']) {
        if (this.multiDimFlag) {
          menuTotal+=matrixObj[column]['state'].on;
        }
        else {
          (matrixObj[column]['state'] === 'track-on') && menuTotal++;
        };
      }
    }
    $(panel.menuCountSpan).text(menuTotal);
  },

  //Function to select filters and adding/removing them in the relevant panel
  selectBox: function(ele) {
    var panel = this;
    var chkbox = $('span.fancy-checkbox', ele);
    var selected = chkbox.hasClass('selected');

    if($(ele).hasClass('all-box')) {
      var _class = '';
      if ($(ele).closest('.tab-content').find('li._filtered').length) {
        _class = '._filtered';
      }

      var available_LIs = $(ele).closest('.tab-content').find('li' + _class + ':not("._search_hide")');
      var availableFancyCheckBoxes = available_LIs.find('span.fancy-checkbox');

      if (!selected) {
        chkbox.addClass('selected');
        // var $(ele).closest('.tab-content').find('li span.fancy-checkbox');
        availableFancyCheckBoxes.addClass("selected");
        available_LIs.addClass("_selected");
      }
      else {
        chkbox.removeClass('selected')
        availableFancyCheckBoxes.removeClass('selected');
        available_LIs.removeClass("_selected");
      }

      // add 'selected: true/flase' to lookup
      available_LIs.map(function() {
        panel.elLk.lookup[$(this).data('item')].selected = !selected;

      });
    }
    else {

      var item = $(ele).data('item');
      panel.elLk.lookup[item].selected = !selected;

       // Select/deselect elements from LH and RH panels. For that, get the elements from panel.el
      var itemElements = $('.' + item, panel.el);
      if (selected) {
        $(itemElements).removeClass('_selected').find("span.fancy-checkbox").removeClass("selected");
      }
      else {
        $(itemElements).addClass('_selected').find("span.fancy-checkbox").addClass("selected");
      }
    }
  },


  updateSelectedTracksPanel: function(item) {
    var panel = this;
    var selectedElements = [];
    this.selectedTracksCount = {};
    this.totalSelected = 0;
    ['dx', 'dy'].forEach(function(key) {
      var selectedLIs, allLIs;
      if (panel.elLk[key].haveSubTabs) {
        // If tab have subtabs
        $.each(panel.elLk[key].tabContents, function(subTab, lis) {
          selectedLIs = lis.has('.selected') || [];
          allLIs = lis.has('._filtered') || [];
          _search_hide = lis.has('._search_hide') || [];

          // In case _filtered class is not applied
          // Add lis with _search_hide class. because all _search_hide lis will have display = 'none'
          allLIs = allLIs.length || lis.filter(function() { return $(this).css('display') !== 'none' || $(this).hasClass('_search_hide') });

          // Storing counts of each tabs - selected and available,  to activate/deactivate tabs and ribbons
          panel.selectedTracksCount[subTab] = panel.selectedTracksCount[subTab] || {};
          panel.selectedTracksCount[subTab].selected = panel.selectedTracksCount[subTab].selected || [];

          $(selectedLIs).map(function(){
            panel.selectedTracksCount[subTab].selected.push($(this).data('item'));
          })
          panel.selectedTracksCount[subTab].available = allLIs.length;
          panel.totalSelected  += selectedLIs.length;

          panel.updateCurrentCount(subTab, selectedLIs.length, allLIs.length);
          selectedLIs.length && selectedElements.push(selectedLIs);
        })
      }
      else {
        selectedLIs = panel.elLk[key].tabContents.has('.selected') || [];
        allLIs = panel.elLk[key].tabContents.has('._filtered') || [];

        // Add lis with _search_hide class. because all _search_hide lis will have display = 'none'
        allLIs = allLIs.length || panel.elLk[key].tabContents.filter(function() { return $(this).css('display') !== 'none' || $(this).hasClass('_search_hide') });
        panel.selectedTracksCount[key] = panel.selectedTracksCount[key] || {};
        panel.selectedTracksCount[key].selected = panel.selectedTracksCount[key].selected || [];
        $(selectedLIs).map(function(){
          panel.selectedTracksCount[key].selected.push($(this).data('item'));
        })
        panel.selectedTracksCount[key].available = allLIs.length;
        panel.totalSelected += selectedLIs.length;

        // update counts
        panel.updateCurrentCount(key, selectedLIs.length, allLIs.length);
        selectedLIs.length && selectedElements.push(selectedLIs);
      }
    });
    // update selected items (cloned checkboxes)
    var clones = {};
    $(selectedElements).each(function(i, arr){
      $(arr).each(function(k, el){
        var k = $(el).data('item');
        clones[k] = $(el).clone().removeClass('noremove _search_hide').show();
      });
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

  setLocalStorage: function() {
    localStorage.setItem(this.localStorageKey, JSON.stringify(this.localStoreObj));
    this.updateLHMenu();
  },
  getLocalStorage: function() {
    return JSON.parse(localStorage.getItem(this.localStorageKey)) || {};
  },

  // Function to add dx and dy items to store when the checkbox are clicked
  addToStore: function(items) {
    if (!items.length) return;
    var panel = this;
    var parentTab;

    //easier to reinitialise dx and dy to empty and then add item to it
    panel.localStoreObj.dx = {};
    panel.localStoreObj.dy = {};

    $.each(items, function(i, item) {
      parentTab = panel.elLk.lookup[item].parentTabId;
      panel.localStoreObj[parentTab] = panel.localStoreObj[parentTab] || {}
      panel.localStoreObj[parentTab][item] = 1;
    });
  },

  removeFromStore: function(item, lhs_section_id) {
    // Removal could happen from RHS or LHS. So section id need to passed as param
    if(lhs_section_id !== 'dx') {
      var tab = 'dy'
      item && lhs_section_id && delete this.localStoreObj[tab][lhs_section_id][item];
    }
    else {
      item && lhs_section_id && delete this.localStoreObj[lhs_section_id][item];
    }
    //TODO need to remove from matrix as well
  },

  // Function to show track configuration panel (matrix) when button is clicked
  // Arguments javascript object of the button element and the panel to show
  clickDisplayButton: function(clickButton, tabClick) {
    var panel = this;

    clickButton.on("click", function(e) {
      if(clickButton.hasClass("_edit")) {
        // Select Tracks panel
        panel.elLk.filterTrackBox.hide();
        panel.elLk.resultBox.show();
        panel.elLk.configResultBox.hide();
        panel.toggleTab({'selectElement': panel.el.find("li._configure"), 'container': panel.el.find("div.large-breadcrumbs")});
        panel.toggleButton();
      }else if(clickButton.hasClass("active") ) {
        // FilterTracks button click
        if(clickButton.hasClass("_filterButton")){
          panel.toggleTab({'selectElement': panel.el.find("li#track-filter"), 'container': panel.el.find("div.large-breadcrumbs")});
          panel.elLk.filterTrackBox.css('display', 'flex');
          panel.elLk.resultBox.hide();
          panel.elLk.configResultBox.hide();
          panel.toggleButton();
        } else {
          // Configuration button click
          if (panel.multiDimFlag) {
            panel.elLk.filterTrackBox.hide();
            panel.elLk.resultBox.hide();
            panel.elLk.configResultBox.show();
          }
          panel.toggleTab({'selectElement': tabClick, 'container': panel.el.find("div.large-breadcrumbs")});
          panel.toggleButton();
        }
      }
      panel.emptyMatrix();
      panel.displayFilterMatrix();
      panel.displayMatrix();
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

      //in case the track-content is not active, hide configuration panel first
      if(panel.el.find("div#configuration-content:visible").length){
        panel.toggleTab({'selectElement': panel.el.find("li._track-select"), 'container': panel.el.find("div.large-breadcrumbs")});
        panel.toggleButton();
      }

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

  updateShowHideLinks: function(filterList) {
      var panel = this;

      $.each(filterList, function(i, ul) {
        if (!$(ul).siblings("div.show-hide:visible").length && $('li', ul).length) {
          var _class =  $(ul).css('display') === 'none' ? '._show' : '._hide';
          $(ul).siblings(_class).show();
        }
        else if ($(ul).siblings("div.show-hide:visible").length && $('li', ul).length === 0) {
          $(ul).siblings('._hide, ._show').hide();
        }
      })
  },

  //function to toggle filters in right hand panel when show/hide selected is clicked
  registerShowHideClickEvent: function() {
    var panel = this;

    this.elLk.filterTrackBox.find('div.show-hide').off().on("click", function(e) {
      $(this).parent().find('div.show-hide, ul.result-list, ul.filterMatrix-list').toggle();
    });
    this.elLk.resultBox.find('div.show-hide').off().on("click", function(e) {
      panel.el.find(this).parent().find('div.show-hide, ul.result-list').toggle();
    });
    this.elLk.configResultBox.find('div.show-hide').off().on("click", function(e) {
      panel.el.find(this).parent().find('div.show-hide, ul.result-list').toggle();
    });
  },

  trackTab: function() {
    var panel = this;
    //showing and applying cell types
    var dxContainer = panel.el.find("div#dx-content");
    var rhSectionId = dxContainer.data('rhsection-id');
    panel.dx = panel.json.dimensions[0];
    panel.dy = panel.json.dimensions[1];
    var dx = panel.json.data[panel.dx];
    var dy = panel.json.data[panel.dy];

    this.displayCheckbox(
      {
        data: Object.keys(dx.data),
        container: "div#dx-content",
        listType: dx.listType,
        parentTabContainer: dxContainer,
        rhSectionId: rhSectionId,
        noFilter: true
      }
    );

    //displaying the Y dimension
    var dyContainer = panel.el.find("div#dy-content");
    rhSectionId = dyContainer.data('rhsection-id');

    if (dy.subtabs) {
      //showing experiment type tabs
      var dy_html = '<div class="tabs dy">';
      var content_html = "";

    //sort dy object
    Object.keys(dy.data).sort().forEach(function(key) {
        var value = dy.data[key];
        delete dy.data[key];
        dy.data[key] = value;
    });

    var count = 0;
    $.each(dy.data, function(key, item){
      var active_class = "";
      if(count === 0) { active_class = "active"; } //TODO: check the first letter that there is data and then add active class
      dy_html += '<div class="track-tab '+active_class+'" id="'+key+'-tab">'+item.name+'<span class="hidden content-id">'+key+'-content</span></div>';
      content_html += '<div id="'+key+'-content" class="tab-content '+active_class+'" data-rhsection-id="'+ key +'""><span class="hidden rhsection-id">'+key+'</span></div>';
      count++;
    });
    dy_html += '</div>';
    dyContainer.append(dy_html).append(content_html);

      // add checkboxes to each tab div
      $.each(dy.data, function(key, subTab){
        panel.displayCheckbox(
          {
            data: subTab.data,
            container: "div#"+key+"-content",
            listType: subTab.listType,
            parentTabContainer: dyContainer,
            rhSectionId: rhSectionId,
            noFilter: true,
            set: subTab.set
          }
        );
      });
    }
    else {
      this.displayCheckbox(
        {
          data: Object.keys(dy.data),
          container: "div#dy-content",
          listType: dy.listType,
          parentTabContainer: dyContainer,
          rhSectionId: rhSectionId,
          noFilter: true
        }
      );
    }

    //adding dimension Y and X relationship as data-attribute
    panel.addRelationData();

    //selecting the tab in experiment type
    this.el.find("div.dy div.track-tab").on("click", function () {
      panel.toggleTab({'selectElement': this, 'container': panel.el.find("div.dy")});
      panel.resize();
    });

  },

  // Function to toggle tabs and show the corresponding content which can be accessed by #id or .class
  // Arguments: selectElement is the tab that's clicked to be active or the tab that you want to be active (javascript object)
  //            container is the current active tab (javascript object)
  //            selByClass is either 1 or 0 - decide how the selection is made for the container to be active (container accessed by #id or .class)
  toggleTab: function(obj) {

    var selectElement = obj.selectElement;
    var container = obj.container;
    var selByClass = obj.selByClass;
    var resetRibbonOffset = obj.resetRibbonOffset;
    var searchTriggered = obj.searchTriggered;
    var noOffsetUpdate = obj.resetFilter;
    var panel = this;

    if(!$(selectElement).hasClass("active") && !$(selectElement).hasClass("inactive")) {
      //showing/hiding searchbox in the main tab
      if($(selectElement).find("div.search-box").length) {
        panel.el.find(".search-box").hide();
        $(selectElement).find("div.search-box").show();
      }

      //remove current active tab and content
      var activeContent = container.find(".active span.content-id").html();
      container.find(".active").removeClass("active");
      if(selByClass) {
        container.find("div."+activeContent).removeClass("active");
      } else {
        panel.el.find("#"+activeContent).removeClass("active");
      }

      //add active class to clicked element
      var spanID = $(selectElement).find("span.content-id").html();
      $(selectElement).addClass("active");

      if(selByClass) {
        activeAlphabetContentDiv = container.find("div."+spanID);
      } else {
        activeAlphabetContentDiv = panel.el.find("#"+spanID);
      }

      activeAlphabetContentDiv.addClass("active");


      // Move to the first available tab if current selected tab has gone inactive after filtering
      var contentId = $('.content-id', selectElement).html();
      var tabs = $('#'+contentId + ' .tabs div.track-tab', panel.elLk.trackPanel);
      if (tabs.length && !tabs.hasClass('active')) {
        if (tabs.not('.inactive').length) {
          var firstActiveTab = tabs.not('.inactive')[0];
          var contentId = $('.content-id', firstActiveTab).html();
          var firstActiveTabContent = $('#'+ contentId, panel.elLk.trackPanel);
          $(firstActiveTab).addClass('active');
          $(firstActiveTabContent).addClass('active');
        }
      }

      if (resetRibbonOffset) {
        $(selectElement).closest('.letters-ribbon').data({'reset': true});
      }

      activeAlphabetContentDiv = panel.elLk.trackPanel.find('div.ribbon-content .alphabet-content.active');
      $.each(activeAlphabetContentDiv, function(i, el) {
        var activeLetterDiv = $(el).closest('.tab-content').find('div.alphabet-div.active');

        // Reset is applied on filterData() if an offset reset is needed for the ribbon
        if ($(activeLetterDiv).closest('.letters-ribbon').data('reset') && ($(selectElement).hasClass('track-tab') || searchTriggered)  && !noOffsetUpdate) {
          var availableAlphabets = panel.getActiveAlphabets();
          var activeAlphabetDiv = availableAlphabets.filter(function(){return $(this).hasClass('active');});
          var activeAlphabetIndex = $(activeLetterDiv).parent().children().index(activeAlphabetDiv);
          var bannerOffset = $(activeLetterDiv).closest('.ribbon-banner').offset();

          // tab containing ribbon need to be visible to get the offset value.
          if ($(activeLetterDiv).closest('.ribbon-banner').closest('.tab-content').css('display') !== 'none') {
            var lettersSkipped = activeAlphabetIndex * 22;
            newOffset =  (bannerOffset.left - lettersSkipped + 10);
            $(activeLetterDiv).closest('.letters-ribbon').offset({left: newOffset});
            // Remove reset once the offset is applied.
            $(activeLetterDiv).closest('.letters-ribbon').removeData('reset');
          }
        }

        if (activeLetterDiv.offset() && !noOffsetUpdate) {
          // change offset positions of all letter content divs same as their respecitve ribbon letter div
          $(el).offset({left: activeLetterDiv.offset().left - 2});
        }
      });
    }
  },
  
  //function to show a different set of breadcrumbs for multidimensional trackhub
  switchBreadcrumb: function() {
      var panel = this;

      if(panel.multiDimFlag) {
        panel.el.find("div.large-breadcrumbs.twoDim").remove();
        panel.el.find("div.large-breadcrumbs.multiDim").show();
      } else {
        panel.el.find("div.large-breadcrumbs.twoDim").show();
        panel.el.find("div.large-breadcrumbs.multiDim").remove();
      }

      this.elLk.breadcrumb = this.el.find("div.large-breadcrumbs li");

      this.elLk.breadcrumb.on("click", function (e) {
        panel.toggleBreadcrumb(this);
        e.preventDefault();
        panel.resize();
      });
  },

  //function to change the tab in the breadcrumb and show the appropriate content
  toggleBreadcrumb: function(element) {
    var panel = this;

    if(!panel.el.find(element).hasClass('view-track')) { 
      panel.elLk.filterTrackBox.hide();
      panel.elLk.configResultBox.hide();
      panel.elLk.resultBox.show();
      panel.toggleTab({'selectElement': element, 'container': panel.el.find("div.large-breadcrumbs")});
    }
    panel.toggleButton();

    if(panel.el.find(element).attr('id') === 'track-filter' && !panel.el.find(element).hasClass('inactive')) {
      panel.elLk.filterTrackBox.css('display', 'flex');
      panel.elLk.configResultBox.hide();
      panel.elLk.resultBox.hide();
      panel.emptyMatrix();
      panel.displayFilterMatrix();
    }

    if(panel.el.find(element).attr('id') === 'track-display' && !panel.el.find(element).hasClass('inactive')) {
      if (panel.multiDimFlag) {
        panel.elLk.filterTrackBox.hide();
        panel.elLk.resultBox.hide();
        panel.elLk.configResultBox.show();
      }
      panel.emptyMatrix();
      panel.displayMatrix();
    }
  },

  toggleButton: function() {
    var panel = this;

    if(panel.el.find('div.track-configuration:visible').length){
      panel.elLk.resultBox.find('div.reset_track').hide();
      panel.el.find('button.showMatrix').removeClass("_filterButton").addClass("_edit").outerWidth("100px").html("View tracks");
    } else {
      panel.elLk.resultBox.find('div.reset_track').show();
      if(panel.multiDimFlag){
        panel.el.find('button.showMatrix').outerWidth("110px").html("Filter tracks").removeClass("_edit").addClass("_filterButton");
      } else {
        panel.el.find('button.showMatrix').outerWidth(panel.buttonOriginalWidth).html(panel.buttonOriginalHTML).removeClass("_edit _filterButton");
      }      
    }
  },

  createTooltipText: function(key, id) {
    if (key === undefined && id === undefined) return;

    if (this.elLk.filterMatrixObj[key] && this.elLk.filterMatrixObj[key][id]) {
      var shortLabel = this.elLk.filterMatrixObj[key][id].shortLabel ? this.elLk.filterMatrixObj[key][id].shortLabel : id;
      var longLabel = this.elLk.filterMatrixObj[key][id].longLabel ? this.elLk.filterMatrixObj[key][id].longLabel : id;
      tooltip = '<p><u>' + shortLabel + '</u></p><p>' + longLabel + '</p>';
    }
    else {
      tooltip = id;
    }
    return tooltip;
  },
  //function to display filters (checkbox label), it can either be inside a letter ribbon or just list
  displayCheckbox: function(obj) {

    var data = obj.data;
    var container = obj.container;
    var listType = obj.listType;
    var parentTabContainer = obj.parentTabContainer;
    var parentRhSectionId = obj.rhSectionId;
    var noFilter_allBox = obj.noFilter;
    var set = obj.set || '';

    var panel       = this;
    var ribbonObj   = {};
    var countFilter  = 0;

    if(listType && listType === "alphabetRibbon") {

      //creating obj with alphabet key (a->[], b->[],...)
      $.each(data.sort(), function(j, item) {
        var firstChar = item.charAt(0).toLowerCase();
        if(!ribbonObj[firstChar]) {
          ribbonObj[firstChar] = [];
          ribbonObj[firstChar].push(item);
        } else {
          ribbonObj[firstChar].push(item);
        }
      });
      panel.alphabetRibbon(ribbonObj, container, parentTabContainer, parentRhSectionId, noFilter_allBox, set);
      panel.updateAvailableTabsOrRibbons(panel.getActiveTab());
    } else  {
      var container = panel.el.find(container);
      var wrapper = '<div class="content-wrapper">';
      var html = '<div class="_drag_select_zone"> <ul class="list-content">';
      var rhsection = container.find('span.rhsection-id').html();
      data = data.sort();
      $.each(data, function(i, item) {
        if(item) {
          var _class = '';
          if (item.length > 15) {
            _class = ' _ht ';
          }
          var elementClass = item.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          html += '<li class="noremove '+ elementClass + _class + '" title="' + item + '" data-parent-tab="' + rhsection + '" data-item="' + elementClass +'"><span class="fancy-checkbox"></span><text>'+item+'</text></li>';
        }
        countFilter++;
        panel.elLk.lookup[elementClass] = {
          label: item,
          parentTab: parentTabContainer,
          parentTabId: parentRhSectionId,
          subTab: rhsection,
          selected: false,
          set: set || ''
        };

      });
      html += '</ul></div>';
      var wrapper_close = '</div>';
      html = wrapper + '<span class="hidden error search-error">No matches</span><div class="selectall-container"><div class="deselect-box select-link" id="deSelectBox-'+$(container).attr("id")+'">Deselect all</div><div class="divider">|</div><div class="all-box select-link" id="allBox-'+$(container).attr("id")+'">Select all</div></div>' + html + wrapper_close;
      container.append(html);

      // Adding the element itself to the lookup
      $.each(data, function(i, item) {
        if(item) {
          var elementClass = item.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          panel.elLk.lookup[elementClass].el = container.find("." + elementClass);
        }
      });

      //updating available count in right hand panel
      panel.el.find('div#'+rhsection+' span.total').html(countFilter);
      $(container).find('._ht').helptip({position: {at: 'center bottom-10'}});
    }
  },

  //function to add dx and dy in data-filter attribute which link the dx checkbox to the dy checkbox and vice versa, used for filtering to show/hide checkboxes
  addRelationData: function () {
    var panel = this;

    $.each(panel.json.data[panel.dx].data, function(key, dx_data) {
      var dx_className = key.replace(/[^\w\-]/g,'_');
      panel.elLk.lookup[dx_className].data = dx_data;
      //add dy attribute to dx
      var relClassNameString="";
      $.each(dx_data, function(index, el) {
        var relClassName = el.val.replace(/[^\w\-]/g,'_');
        relClassNameString += relClassName + " ";

        //adding cells atribute to experiments
        var relDataFilter = panel.el.find("li."+relClassName).attr('data-filter');
        relDataFilter ?  panel.el.find("li."+relClassName).attr('data-filter', relDataFilter+" "+dx_className) :  panel.el.find("li."+relClassName).attr('data-filter', dx_className);

        if(!panel.el.find("li."+relClassName).attr('data-filtercontainer')){
          panel.el.find("li."+relClassName).attr('data-filtercontainer', 'dx-content');
        }
      });
      //data-filter contains the classname that needs to be shown and data-filtercontainer is the id where elements to be shown are located
      panel.el.find("li."+dx_className).attr('data-filter', relClassNameString).attr('data-filtercontainer', 'dy-content');

    });
  },

  // Function that does internal filtering to show/hide other dimension's checkboxes based on a checkbox selection.
  // This will also do the activation/inactivation of tabs based on availability
  // Arguments: selected element item name
  filterData: function(item) {
    var panel = this;

    if (!item) return;

    var tabA_container = $(panel.elLk.lookup[item].parentTab, panel.el);
    var tabB_containerId = '#' + $('.' + item, panel.elLk.trackPanel).data('filtercontainer');
    var tabB_LIs = panel.el.find(tabB_containerId).find('li');

    var filters = {};
    tabA_container.find('li span.fancy-checkbox.selected').parent().map(function(){
      if ($(this).data('filter')) {
        $(this).data('filter').split(' ').map(function(f) {
          if (f!== '') {
            filters[f] = 1;
          }
        });
      }
    })

    // Hide all first and then show based on filters
    tabB_LIs.hide();

    var filters_class = '';
    // Create classees with all filters for selection below
    if (Object.keys(filters).length) {
      filters_class = 'li.' + Object.keys(filters).join(', li.');
      var tabB_currently_selected_lis = panel.elLk.trackPanel.find(tabB_containerId).find('li._selected');
      panel.elLk.trackPanel.find(tabB_containerId).find(filters_class).addClass('_filtered').show();
      $(tabB_currently_selected_lis).addClass('_filtered').show();

      // Unselect any lis which went hidden after filtering
      tabB_LIs.not('._filtered').find('span.fancy-checkbox').removeClass('selected');
    }
    else {
      // If no filters, then show all LIs in tabB
      tabB_LIs.removeClass('_filtered').show();
    }

    var resetCount = filters_class === '' ? 1 : 0;

    var tabToFilter = {
      'dx': 'dy',
      'dy': 'dx'
    }
    panel.updateAvailableTabsOrRibbons(tabToFilter[panel.elLk.lookup[item].parentTabId], true);
  },

  getActiveAlphabets: function(container) {
    var panel = this;
    container = container || this.getActiveTabContainer();
    return $(container).find('.ribbon-banner div.alphabet-div').not('.inactive');
  },

  // Function to create letters ribbon with left and right arrow (< A B C ... >) and add elements alphabetically
  // Arguments: data: obj of the data to be added with obj key being the first letter pointing to array of elements ( a -> [], b->[], c->[])
  //            Container is where to insert the ribbon
  alphabetRibbon: function (data, container, parentTabContainer, parentRhSectionId, noFilter_allBox, set) {

    var panel = this;
    var html  = "";
    var content_html = "";
    var total_num = 0;
    var container = panel.el.find(container);
    var rhsection = container.find('span.rhsection-id').html();

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
          var tip = panel.createTooltipText(el);
          letterHTML += '<li class="noremove ' + elementClass + '" data-parent-tab="' + rhsection + '" data-item="' + elementClass + '"><span class="fancy-checkbox"></span><text class="_ht _ht_delay" title="'+tip+'">'+el+'</text></li>';

          panel.elLk.lookup[elementClass] = {
            label: el,
            parentTab: parentTabContainer,
            parentTabId: parentRhSectionId,
            subTab: rhsection,
            selected: false,
            set: set
          };
        });
        letterHTML += '</ul>';
      } else {
        active_class = "inactive";
      }

      html += '<div class="ribbon_'+letter+' alphabet-div '+active_class+'">'+letter.toUpperCase()+'<span class="hidden content-id">'+letter+'_content</span></div>';
      content_html += '<div data-ribbon="ribbon_'+letter+'" class="'+letter+'_content alphabet-content '+active_class+'">'+letterHTML+'</div>';
    });
    var noFilterClass = noFilter_allBox ? 'no-filter' : '';
    container.append('<span class="hidden error search-error">No matches</span><div class="selectall-container"><div class="deselect-box select-link '+ noFilterClass +'" id="deSelectBox-'+$(container).attr("id")+'">Deselect all</div><div class="divider">|</div><div class="select-link all-box '+ noFilterClass +'" id="allBox-'+$(container).attr("id")+'">Select all</div></div><div class="cell-listing _drag_select_zone"><div class="ribbon-banner"><div class="larrow inactive">&#x25C0;</div><div class="alpha-wrapper"><div class="letters-ribbon"></div></div><div class="rarrow">&#x25B6;</div></div><div class="ribbon-content"></div></div>');

    container.find('div.letters-ribbon').append(html);
    container.find('div.ribbon-content').append(content_html);

    // Adding element itself to the lookup
    $.each(new Array(26), function(i) {
      var letter = String.fromCharCode(i + 97);
      if(data[letter] && data[letter].length) {
        $.each(data[letter], function(i, el) {
          total_num++;
          var elementClass = el.replace(/[^\w\-]/g,'_');//this is a unique name and has to be kept unique (used for interaction between RH and LH panel and also for cell and experiment filtering)
          panel.elLk.lookup[elementClass].el = container.find('.' + elementClass);
        });
      }
    });

    //updating available count in right hand panel
    panel.el.find('div#'+rhsection+' span.total').html(total_num);

    //clicking the alphabet
    var alphabet = container.find('div.alphabet-div');
    alphabet.on("mousedown", function(e){
      if (!$(container, panel.el).hasClass('active')) {
        return;
      }
      $.when(
        panel.toggleTab({'selectElement': this, 'container': container, 'selByClass': 1})
      ).then(
        panel.selectArrow(container)
      );
    });
  },

  selectArrow: function(container) {
    var panel = this;
    var activeAlphabets = panel.getActiveAlphabets(container);
    var startLetter = $(activeAlphabets.get(0)).html().charAt(0);
    var endLetter   = $(activeAlphabets.get(-1)).html().charAt(0);
    if (!activeAlphabets.length) return;

    if($('div.alphabet-div.active', container).html().match(startLetter)) {
      $('div.larrow', container).removeClass("active").addClass("inactive");
      $('div.rarrow', container).removeClass("inactive").addClass("active"); //just in case jumping from Z to A
    } else if($('div.alphabet-div.active', container).html().match(endLetter)) {
      $('div.rarrow', container).removeClass("active").addClass("inactive");
      $('div.larrow', container).removeClass("inactive").addClass("active"); //just in case jumping from A to Z
    }else {
      $('div.larrow, div.rarrow', container).removeClass("inactive").addClass("active");
    }
  },

  registerRibbonArrowEvents: function() {
    var panel = this;
    //clicking the left and right arrow
    panel.elLk.arrows   = $('div.rarrow, div.larrow', panel.elLk.trackPanel);
    panel.elLk.arrows.off().on("mousedown", function(e){
      container = $(e.target).closest('.tab-content');
      var ribbonBanner = container.find('.letters-ribbon');
      var ribbonContent = container.find('.ribbon-content');
      var availableAlphabets = panel.getActiveAlphabets(container);
      var activeAlphabetDiv = availableAlphabets.filter(function(){return $(this).hasClass('active');});
      var activeAlphabetIndex = availableAlphabets.index(activeAlphabetDiv);
      var activeAlphabet = activeAlphabetDiv.html().charAt(0).toLowerCase();
      var activeTabId = panel.getActiveTab() + '-tab';

      if (!$(container).hasClass('active') && !$('#' + activeTabId, panel.elLk.trackPanel).hasClass('active')) {
        return; // run only for the active tab
      }

      if(!this.className.match(/inactive/gi)) {
        if(this.className.match(/larrow/gi)) {
          if (!availableAlphabets[activeAlphabetIndex-1]) return;

          //get previous letter
          var prevLetter = $(availableAlphabets[activeAlphabetIndex-1]).html().charAt(0).toLowerCase();
          // Get total letters skipped to adjust offset (charcode(currentletter - prevLetter))
          var lettersSkipped = activeAlphabet.charCodeAt(0) - prevLetter.charCodeAt(0);

          $.when(
            panel.toggleTab({'selectElement': ribbonBanner.find("div.ribbon_"+prevLetter), 'container': container, 'selByClass': 1})
          ).then(
            panel.selectArrow(container)
          );

          var prevLetterDiv = ribbonBanner.find('.ribbon_'+prevLetter);

          if(prevLetterDiv.offset().left <= $(e.target).offset().left + 22) {
            ribbonBanner.offset({left: ribbonBanner.offset().left + (22 * lettersSkipped)});
            var prevletterContentDiv = ribbonContent.find("div."+prevLetter+"_content.alphabet-content");
            prevletterContentDiv.offset({left: prevletterContentDiv.offset().left + (22 * lettersSkipped)});
          }

          // Checking the distance of larrow and first alphabet
          if (ribbonBanner.find('.ribbon_a').offset().left > $(e.target).offset().left + 22) {
            panel.activateAlphabetRibbon(container, true);
          }
        }

        if (this.className.match(/rarrow/gi)) {
          if (!availableAlphabets[activeAlphabetIndex+1]) return;

          var nextLetter = $(availableAlphabets[activeAlphabetIndex+1]).html().charAt(0).toLowerCase();
          // Get total letters skipped to adjust offset (charcode(nextletter-currentletter))
          var lettersSkipped = nextLetter.charCodeAt(0) - activeAlphabet.charCodeAt(0);

          $.when(
            panel.toggleTab({'selectElement': ribbonBanner.find("div.ribbon_"+nextLetter), 'container': container, 'selByClass': 1})
          ).then(
            panel.selectArrow(container)
          );

          var nextLetterDiv = ribbonBanner.find('.ribbon_'+nextLetter);
          if(nextLetterDiv.offset().left  >= $(e.target).offset().left - 44) {
            ribbonBanner.offset({left: ribbonBanner.offset().left - (22 * lettersSkipped)});
            var nextletterContentDiv = ribbonContent.find("div."+nextLetter+"_content.alphabet-content");
            nextletterContentDiv.offset({left: nextletterContentDiv.offset().left - (22 * lettersSkipped)});
          }
        }
      }

    });
  },

  //function to find out which dimension dyItem belong to (used to know which state object to use; dimensions = matrix, extra_dimensions = array key)
  itemDimension: function(item){
    var panel = this;

    if(item.match("_sep_")){
      item = item.split("_sep_")[0];
    }
    if(panel.json.extra_dimensions && panel.json.extra_dimensions.indexOf(item) >= 0) {
      return panel.json.extra_dimensions[panel.json.extra_dimensions.indexOf(item)];
    }  else {
      return "matrix"; //object name for matrix state object
    }
  },

  // Function to show/update/delete matrix
  displayFilterMatrix: function() {
    var panel = this;

    if($.isEmptyObject(panel.localStoreObj)) { return; }

    panel.cleanFilterMatrixStore();

    panel.trackPopup = panel.el.find('div.track-popup');
    var xContainer   = '<div  class="xContainer">';

    //creating array of dy from lookup Obj. ; this will make sure the order is the same
    var dyArray = panel.localStoreObj.dy ? Object.keys(panel.localStoreObj.dy).sort() : [];
    var _class = '';
    // creating dy label on top of matrix
    $.each(dyArray, function(i, dyItem){ 
      var dyLabel = panel.elLk.lookup[dyItem] ? panel.elLk.lookup[dyItem].label : dyItem;
      if (dyLabel.length > 15) {
        _class = ' _ht ';
      }
      xContainer += '<div class="positionFix"><div class="rotate"><div class="overflow xLabel '+dyItem + _class + '" title="'+ dyLabel +'"><span>'+dyLabel+'</span></div></div></div>'; 
    });

    xContainer += "</div>";
    panel.el.find('div.filterMatrix-container').append(xContainer);

    var yContainer = '<div class="yContainer">';
    var boxContainer = '<div class="boxContainer">';
    //creating cell label with the boxes (number of boxes per row = number of experiments)
    if(panel.localStoreObj.dx && panel.localStoreObj.dy) {
      $.each(Object.keys(panel.localStoreObj.dx).sort(), function(i, cellName){
          var cellLabel    = panel.elLk.lookup[cellName].label || cellName;
          var _class = '';
          if (cellLabel.length > 15) {
            _class = ' _ht ';
          }
          yContainer += '<div class="yLabel '+ _class +'" title="'+ cellLabel +'"'+cellName+'"><span>'+cellLabel+'</span></div>';
          var rowContainer  = '<div class="rowContainer">'; //container for all the boxes/cells

          //drawing boxes
          $.each(dyArray, function(i, dyItem) {
            if (dyItem === '' && !panel.disableYdim && !panel.trackHub) {
              rowContainer += '<div class="xBoxes _emptyBox_'+cellName+'"></div>';
            }
            else {
              var boxState  = "";
              var offCount  = 0;
              var onCount   = 0;
              var dataClass = ""; //to know which cell has data
              var storeKey = dyItem + "_sep_" + cellName; //key for each cell, (dy_sep_dx)
              var totalCount = 0;
              var boxCountHTML = "";

              if(panel.localStoreObj["filterMatrix"] && panel.localStoreObj["filterMatrix"][storeKey]) {
                if(panel.localStoreObj["filterMatrix"][storeKey]["state"]["on"] === panel.localStoreObj["filterMatrix"][storeKey]["state"]["total"]) { 
                  boxState = "track-on";
                  boxCountHTML = '<span class="count">'+panel.localStoreObj["filterMatrix"][storeKey]["state"]["on"]+'</span>';
                } else {
                  var partialCount = panel.localStoreObj["filterMatrix"][storeKey]["state"]["total"] - panel.localStoreObj["filterMatrix"][storeKey]["state"]["off"];
                  boxState = (partialCount === 0) ? "partzero" : "partial";
                  boxCountHTML = '<span class="partialCount">'+partialCount+'</span><span class="count">'+panel.localStoreObj["filterMatrix"][storeKey]["state"]["total"]+'</span>';
                }
                dataClass = "_hasData";

                if(panel.localStoreObj["filterMatrix"][storeKey]["state"]["total"] === 0) {
                  boxState = "";
                  dataClass = "";
                }
              } else {
                //check if there is data or no data with cell and experiment (if experiment exist in cell object then data else no data )                      
                if(panel.elLk.filterMatrixObj[storeKey]) {
                  dataClass  = "_hasData";
                  panel.localStoreObj["filterMatrix"][storeKey] = panel.localStoreObj["filterMatrix"][storeKey] || {};

                  $.each(panel.elLk.filterMatrixObj[storeKey], function(cellKey, tracks){
                    if(tracks["show"] === 1) { totalCount += 1; }

                    $.each(tracks["data"], function(dimensionValue, state){
                      if(state === "off" && tracks["show"] === 1) { offCount++ };
                      if(state === "on" && tracks["show"] === 1)  { onCount++ };

                      panel.localStoreObj["filterMatrix"][storeKey]["data"] = panel.localStoreObj["filterMatrix"][storeKey]["data"] || {};
                      panel.localStoreObj["filterMatrix"][storeKey]["data"][cellKey] = panel.localStoreObj["filterMatrix"][storeKey]["data"][cellKey] || {};
                      panel.localStoreObj["filterMatrix"][storeKey]["data"][cellKey]["state"] = state;
                      panel.localStoreObj["filterMatrix"][storeKey]["data"][cellKey]["reset-state"] = state;
                      panel.localStoreObj["filterMatrix"][storeKey]["data"][cellKey]["show"] = tracks["show"];
                      panel.localStoreObj["filterMatrix"][storeKey]["data"][cellKey]["reset-show"] = tracks["show"];
  
                      // //setting count for all selection section
                      // panel.localStoreObj[dyStoreObjKey]["allSelection"]["total"] += 1;
                      // panel.localStoreObj[dyStoreObjKey]["allSelection"]["state"][boxState.replace("track-","")]++;
                      // panel.localStoreObj[dyStoreObjKey]["allSelection"]["state"]["reset-"+boxState.replace("track-","")]++;
                      return false;
                    });
                  });
                  if(onCount === totalCount) { 
                    boxState = "track-on";
                    boxCountHTML = '<span class="count">'+onCount+'</span>';
                  } else if(offCount === totalCount){
                    boxState = "track-off";
                    boxCountHTML = '<span class="count">0</span>';
                  } else {
                    var partialCount = totalCount - onCount;
                    boxState = (partialCount === 0) ? "partzero" : "partial";
                    boxCountHTML = '<span class="partialCount">'+partialCount+'</span><span class="count">'+totalCount+'</span>';
                  }

                  //setting localstore for each box state
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]                = panel.localStoreObj["filterMatrix"][storeKey]["state"] || {};
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]["total"]       = totalCount;
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]["reset-total"] = totalCount;
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]["on"]          = onCount;
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]["reset-on"]    = onCount;
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]["off"]         = offCount;
                  panel.localStoreObj["filterMatrix"][storeKey]["state"]["reset-off"]   = offCount;                  
                }
              }
              if(!dataClass) { boxCountHTML = ""; }
              rowContainer += '<div class="xBoxes matrix '+boxState+' '+dataClass+' '+cellName+' '+dyItem+' '+storeKey+'" data-track-x="'+dyItem+'" data-track-y="'+cellName+'" data-popup-type="_filterMatrix">'+boxCountHTML+'</div>';
            }
          });

          rowContainer += "</div>";
          boxContainer += rowContainer;
      });
    }
    yContainer += "</div>";
    boxContainer += "</div>";

    var yBoxWrapper = '<div class="yBoxWrapper">' + yContainer + boxContainer + '</div>';

    panel.el.find('div.filterMatrix-container').append(yBoxWrapper);

    // Setting width of xContainer and yBoxWrapper (32px width box times number of xlabels)
    var hwidth = (dyArray.length * 32);
    panel.el.find('div.filterMatrix-container .xContainer, div.filterMatrix-container .yBoxWrapper').width(hwidth);

    panel.cellClick('filter'); //opens popup
    // panel.filterMatrixCellClick(); //opens popup
    panel.setLocalStorage();

    // enable helptips
    panel.elLk.breadcrumb.filter(".active").attr("id") === 'track-filter' && this.elLk.filterMatrix.find('.xContainer ._ht').helptip({position: {at: 'left+10 bottom+76'}});
    panel.elLk.breadcrumb.filter(".active").attr("id") === 'track-filter' && this.elLk.filterMatrix.find('.yContainer ._ht').helptip({position: {at: 'center bottom-15'}});

    this.updateFilterMatrixRHS();

  },

  updateFilterMatrixRHS: function() {
    this.createFilterMatrixList();
    this.registerFilterListItemClickEvent();
    this.updateShowHideLinks(this.elLk.filterMatrixList);
    this.registerShowHideClickEvent();
  },

  cleanFilterMatrixStore: function() {
    // Clean filterMatrix using matrix data from localstore
    var panel = this;
    var filterObj = {};
    var newFilterMatrix = {};
    $.map(Object.keys(panel.localStoreObj.matrix), function(key){ if (key.match('_sep_')) { newFilterMatrix[key] = panel.localStoreObj.filterMatrix[key]; } });
    panel.localStoreObj.filterMatrix = newFilterMatrix;
  },

  createFilterMatrixList: function() {
    var panel = this;
    var localStorage = this.getLocalStorage();
    var availableFilters = {};
    var extraDimValToCellMap = {};
    var arr = [];
    $.each(Object.keys(localStorage.filterMatrix).sort(), function(i, key) {
      if (panel.elLk.filterMatrixObj[key]) {
        $.each(panel.elLk.filterMatrixObj[key], function(trackId, otherDimHash) {
          $.each(otherDimHash["data"], function(dimVal, display){
            arr = dimVal.split('_sep_');
            availableFilters[arr[0]] = availableFilters[arr[0]] || {};
            availableFilters[arr[0]][arr[1]] = 1;
            extraDimValToCellMap[dimVal] = extraDimValToCellMap[dimVal] || {};
            extraDimValToCellMap[dimVal]['cells'] = extraDimValToCellMap[dimVal]['cells'] || {};
            // extraDimValToCellMap[dimVal]['cells'][key] = 1;
            extraDimValToCellMap[dimVal].on = extraDimValToCellMap[dimVal].on || 0;
            extraDimValToCellMap[dimVal].off = extraDimValToCellMap[dimVal].off || 0;
            // Get count of ONs and OFFs
            localStorage.filterMatrix[key].data[trackId].state === 'on' ? extraDimValToCellMap[dimVal].on++ : extraDimValToCellMap[dimVal].off++;
            extraDimValToCellMap[dimVal].cells[key] = extraDimValToCellMap[dimVal].cells[key] || {};
            extraDimValToCellMap[dimVal].cells[key]['availableTracks'] = extraDimValToCellMap[dimVal].cells[key]['availableTracks'] || {};
            extraDimValToCellMap[dimVal].cells[key]['availableTracks'][trackId] = 1
          });
        });
      }
    });
    panel.elLk.extraDimValToCellMap = extraDimValToCellMap;

    var html = '';
    $.each(Object.keys(availableFilters).sort(), function(i, dim) {
      var values = availableFilters[dim];
      var dimSelected = "";
      var dim_html = "";
      values = Object.keys(values).sort();
      total  = values.length;
      var selectedCount = 0;
      var allSelected = "";     

      $.each(values, function(i, val) {
        var dimKey = dim+"_sep_"+val;
        if(panel.localStoreObj["other_dimensions"][dimKey] === 1) {
          dimSelected = "selected";
          selectedCount++;
        } else {
          dimSelected = "";
        }
        dim_html += '<li data-dim-val="'+ val +'" data-dim="'+dim+'" data-dim-key="'+dimKey+'"><div class="fm-count">('+ extraDimValToCellMap[dimKey].on + '/' + (extraDimValToCellMap[dimKey].off + extraDimValToCellMap[dimKey].on)  +')</div><text>' + val + '</text></li>';
      });

      allSelected = selectedCount === total ? "selected" : "";
      html +='\
          <div class="filterMatrix-content">\
            <div class="_show show-hide hidden"><img src="/i/closed2.gif" class="nosprite" /></div><div class="_hide show-hide hidden"><img src="/i/open2.gif" class="nosprite" /></div>\
            <h5 class="result-header">' + dim + '</h5>\
            <ul class="filterMatrix-list">';
      html += dim_html+'</ul></div>';
    });

    panel.elLk.filterTrackBox.find('.filter-content').html(html);
    panel.elLk.filterMatrixList= panel.elLk.filterTrackBox.find("ul.filterMatrix-list");
  },

  createFilterRHSPopup: function(event) {
    var panel = this;
    var data = $(event.currentTarget).data();
    var selected = {};
    var count = {
      state: {on: [], off: []},
      resetState: {on: [], off: []},
      total: []
    };
    // Popup radio button selection functionality (selecting Default in case all_on/off is same as default_on/off)
    $.each(Object.keys(panel.elLk.extraDimValToCellMap[data.dimKey].cells), function(i, cellKey) {
        if (panel.localStoreObj.filterMatrix[cellKey]) {
          $.each(panel.localStoreObj.filterMatrix[cellKey].data, function(trackId, onOffHash) {
            if (panel.elLk.extraDimValToCellMap[data.dimKey].cells[cellKey].availableTracks[trackId]) {
              (onOffHash.state === "on") && count.state.on.push(trackId);
              (onOffHash["reset-state"] === "on") && count.resetState.on.push(trackId);
              (onOffHash.state === "off") && count.state.off.push(trackId);
              (onOffHash["reset-state"] === "off") && count.resetState.off.push(trackId);
              count.total++;
            }
          })
        }
    });

    if (count.state.on.length === count.resetState.on.length &&
        count.state.off.length === count.resetState.off.length &&
        JSON.stringify(count.state.on) === JSON.stringify(count.resetState.on) &&
        JSON.stringify(count.state.off) === JSON.stringify(count.resetState.off)) {
          selected['default'] = 'checked';
    }
    else if (count.state.on.length === count.total  && count.state.off.length === 0) {
      selected['all_on'] = 'checked';
    }
    else if(count.state.off.length === count.total && count.state.on.length === 0) {
      selected['all_off'] = 'checked';
    }


    var popup = '\
      <div class="title">' + data.dimVal + '</div>\
      <div><input type="radio" name="filter_popup_selection" value="all-on" id="filter_popup_selection1"'+selected['all_on']+'><label for="filter_popup_selection1">All On</label></div>\
      <div><input type="radio" name="filter_popup_selection" value="all-off" id="filter_popup_selection2"'+selected['all_off']+'><label for="filter_popup_selection2">All Off</label></div>\
      <div><input type="radio" name="filter_popup_selection" value="default" id="filter_popup_selection3"'+selected['default']+'><label for="filter_popup_selection3">Default</label></div>';

    var pos = $(event.currentTarget).position();
    var offset = $(event.currentTarget).offset();
    panel.elLk.filterTrackBox.find('.filter-rhs-popup').html(popup).css({top: (pos.top + $('div.modal_content')[0].scrollTop) + 20, left: pos.left + $('div.modal_content')[0].scrollLeft}).show();
    panel.elLk.filterTrackBox.find('.filter-rhs-popup input').click($.proxy(function(e) {
      var opt = $(e.currentTarget).val();
      if(opt === "default") {
        panel.resetFilterMatrixToDefaults(data.dimKey);
      } else {
        $.each(Object.keys(panel.elLk.extraDimValToCellMap[data.dimKey].cells), function(i, v) {
          if (panel.localStoreObj.filterMatrix[v]) {
            var trackIds = Object.keys(panel.localStoreObj.filterMatrix[v].data);
            $.each(trackIds, function(i, trackId) {
              if (opt === "all-on") {
                panel.updateFilterMatrixStore(panel.localStoreObj.filterMatrix[v], v, "on", "off", 1)
              }
              else {
                panel.updateFilterMatrixStore(panel.localStoreObj.filterMatrix[v], v, "off", "on", 1)
              }
            });
          }
        });
      }

      panel.setLocalStorage();
      panel.emptyMatrix();
      panel.displayFilterMatrix();
    }, data));

    event.stopPropagation();

  },

  registerFilterListItemClickEvent: function() {
    var panel = this;
    $('li', panel.elLk.filterTrackBox).off().on('click', function(e) {
      panel.createFilterRHSPopup(e);

return;

      var currentState = $(this).find('span.fancy-checkbox').hasClass('selected') ? "on" : "off";
      var newState     = currentState === "on" ? "off" : "on";
      var showValue    = newState === "on" ? 1 : 0;
      var cellArray    = [];

      // Select/deslect all boxes for that dimension
      var fcb = $(this).children('span.fancy-checkbox');
      fcb.toggleClass('selected');
      var filterDimVal = $(this).data('dimVal');
      if ($(this).hasClass('all')) {
        if (fcb.hasClass('selected')) {
          $(this).siblings().each(function(i, sib) {
            $(sib).children('span.fancy-checkbox').removeClass('selected').addClass('selected');
            panel.localStoreObj["other_dimensions"][$(sib).data("dim-key")] = 1;
          });
        } else {
          $(this).siblings().each(function(i, sib) {
            $(sib).children('span.fancy-checkbox').removeClass('selected');
            delete panel.localStoreObj["other_dimensions"][$(sib).data("dim-key")];
          });
        }

        //Updating store and then update cell state
        //Get the cells that are affected by the change and update the store for each affected cell
        $.each(panel.elLk.lookup.dimensionFilter, function(dimKey, trackHash){
          $.each(trackHash, function(cellKey, trackArray){
            //console.log(cellKey);
            $.each(trackArray, function(i, trackId){
              //console.log(trackId);
              panel.updateFilterMatrixStore(panel.localStoreObj.filterMatrix[cellKey].data[trackId], cellKey, newState, currentState,0,showValue, 1);
            });
            cellArray.push(cellKey);
          });
        });         

        // All link click with filterDimVal as the dimension name (age, sex, etc.)

      } else {
        //Adding dimension in store
        if(newState === "on" ) {
          panel.localStoreObj["other_dimensions"][dimKey] = 1;
        } else {
          delete panel.localStoreObj["other_dimensions"][dimKey];
        }

        // Updating store and then update cell state
        //Get the cells that are affected by the change and update the store for each affected cell
        $.each(panel.elLk.lookup.dimensionFilter[dimKey], function(cellKey, trackArray){
          //console.log(cellKey);
          $.each(trackArray, function(i, trackId){
            panel.updateFilterMatrixStore(panel.localStoreObj.filterMatrix[cellKey].data[trackId], cellKey, newState, currentState,0,showValue);
          });
          cellArray.push(cellKey);
        }); 
        
        //check if all items are selected or not, to select All Checkbox
        if(Object.keys(panel.localStoreObj.other_dimensions).length === Object.keys(panel.elLk.lookup.dimensionFilter).length) {
          panel.elLk.filterMatrixList.find('li.all span.fancy-checkbox').removeClass('selected').addClass('selected');
        } else {
          panel.elLk.filterMatrixList.find('li.all span.fancy-checkbox').removeClass('selected');
        }
      }
      panel.setLocalStorage();
      panel.updateFilterMatrix(cellArray);

    });
  },

  registerFilterMatrixCellClickEvent: function() {
    var panel = this;
    $('li', panel.TrackPopupType).off().on('click', function(e) {
      // Select/deslect all boxes for that dimension
      var fcb = $(this).children('span.fancy-checkbox');
      fcb.toggleClass('selected');
      var clickedTrackId = $(this).data('track-id');
      if ($(this).hasClass('all')) {
        if (fcb.hasClass('selected')) {
          $(this).siblings().each(function(i, sib) {
            $(sib).children('span.fancy-checkbox').removeClass('selected').addClass('selected');
          });
        }
        else {
          $(this).siblings().each(function(i, sib) {
            $(sib).children('span.fancy-checkbox').removeClass('selected');
          });
        }
      }
      else {
        // panel.updateFilterMatrixRHS();
      }

    });
  },


  // Function to show/update/delete matrix
  displayMatrix: function() {
    var panel = this;

    if($.isEmptyObject(panel.localStoreObj)) { return; }

    panel.trackPopup = panel.el.find('div.track-popup');
    var xContainer   = '<div  class="xContainer">';

    //setting object of renderers used when initialising the localstore
    var rendererObj={};
    $.each(panel.elLk.lookup.rendererKeys, function(i, n){
      rendererObj[n] = 0;
      rendererObj["reset-"+n] = 0;
    });

    //creating array of dy from lookup Obj. ; this will make sure the order is the same
    var dyArray = panel.localStoreObj.dy ? Object.keys(panel.localStoreObj.dy).sort() : [];;

    // Add empty column
    //if(panel.localStoreObj.dy) { dyArray.unshift(''); }

    // Adding 2 extra regulatory features tracks to show by default
    if (panel.json.extra_dimensions) {
      panel.json.extra_dimensions.sort().reverse().forEach(function(k) {
        dyArray.unshift(k);
     })
    }

    // creating dy label on top of matrix
    $.each(dyArray, function(i, dyItem){
      var dyLabel = panel.elLk.lookup[dyItem] ? panel.elLk.lookup[dyItem].label : dyItem;
      var _class = '';
      if (dyLabel.length > 15) {
        _class = ' _ht ';
      }
      if (dyItem === '' && !panel.disableYdim && !panel.trackHub) {
        xContainer += '<div class="positionFix"><div class="rotate"><div class="overflow xLabel x-label-gap '+ _class +'" title="'+dyLabel+'"><span>'+dyLabel+'</span></div></div></div>'; 
      }
      else {
        if(!panel.localStoreObj[panel.itemDimension(dyItem)][dyItem]) {
          //initialising state obj for dyItem (column), value setup later
          panel.localStoreObj[panel.itemDimension(dyItem)][dyItem] = {"total": 0, "state": { "on": 0, "off": 0, "reset-on": 0, "reset-off": 0 }, "renderer": {}, "format": {} };
          Object.assign(panel.localStoreObj[panel.itemDimension(dyItem)][dyItem]["renderer"], rendererObj);
        }
        if(!panel.localStoreObj[panel.itemDimension(dyItem)]["allSelection"]) {
          //initialising state obj for dyItem (column), value setup later
          panel.localStoreObj[panel.itemDimension(dyItem)]["allSelection"] = {"total": 0, "state": { "on": 0, "off": 0, "reset-on": 0, "reset-off": 0 }, "renderer": {}, "format": {} };
          Object.assign(panel.localStoreObj[panel.itemDimension(dyItem)]["allSelection"]["renderer"], rendererObj);
        }

        if(panel.disableYdim) {
          if(dyItem === 'epigenomic_activity' || dyItem === 'segmentation_features'){
            // xContainer += '<div class="positionFix"><div class="rotate"><div class="overflow xLabel '+dyItem+'"><span class="_ht _ht_delay" title="'+ dyLabel +'">'+dyLabel+'</span></div></div></div>'; 
          }
        } else {
          xContainer += '<div class="positionFix"><div class="rotate"><div class="overflow xLabel '+ dyItem + _class +'" title="'+ dyLabel +'"><span>'+dyLabel+'</span></div></div></div>'; 
        }
      }
    });

    xContainer += "</div>";
    panel.el.find('div.matrix-container').append(xContainer);

    //initialising allSelection for matrix storage
    if(!panel.localStoreObj["matrix"]["allSelection"]) {
      //initialising state obj for dyItem (column), value setup later
      panel.localStoreObj["matrix"]["allSelection"] = {"total": 0, "state": { "on": 0, "off": 0, "reset-on": 0, "reset-off": 0 }, "renderer": {}, "format": {} };
      Object.assign(panel.localStoreObj["matrix"]["allSelection"]["renderer"], rendererObj);
    }

    var yContainer = '<div class="yContainer">';
    var boxContainer = '<div class="boxContainer">';
    //creating cell label with the boxes (number of boxes per row = number of experiments)
    if(panel.localStoreObj.dx && panel.localStoreObj.dy) {
      $.each(Object.keys(panel.localStoreObj.dx).sort(), function(i, cellName){
          var cellLabel    = panel.elLk.lookup[cellName].label || cellName;

          if(!panel.localStoreObj[panel.itemDimension(cellName)][cellName]) {
            if(panel.itemDimension(cellName) === "matrix") {
              panel.localStoreObj[panel.itemDimension(cellName)][cellName] = {"total": 0,"state": { "on": 0, "off": 0, "reset-on": 0, "reset-off": 0 }, "renderer": {}, "format": {} };
              Object.assign(panel.localStoreObj[panel.itemDimension(cellName)][cellName]["renderer"], rendererObj);
            }
          }
          var _class = '';
          if (cellName.length > 15) {
            _class = ' _ht ';
          }
          yContainer += '<div class="yLabel '+_class+'" title="'+cellLabel+'"'+cellName+'"><span>'+cellLabel+'</span></div>';
          var rowContainer  = '<div class="rowContainer">'; //container for all the boxes/cells

          //drawing boxes
          $.each(dyArray, function(i, dyItem) {
            if (dyItem === '' && !panel.disableYdim && !panel.trackHub) {
              rowContainer += '<div class="xBoxes _emptyBox_'+cellName+'"></div>';
            }
            else {
              var boxState  = "", boxDataRender = "";
              var dataClass = ""; //to know which cell has data
              var boxRenderClass = "";
              var storeKey = dyItem + "_sep_" + cellName; //key for identifying cell is joining experiment(x) and cellname(y) name with _sep_
              var renderer, rel_dimension, format;

              var cellStoreObjKey = panel.itemDimension(storeKey);
              var dyStoreObjKey   = panel.itemDimension(dyItem);
              var matrixClass     = cellStoreObjKey === "matrix" ? cellStoreObjKey : "";

              if(panel.localStoreObj[cellStoreObjKey][storeKey]) {
                boxState   = panel.localStoreObj[cellStoreObjKey][storeKey].state;
                boxDataRender  = panel.localStoreObj[cellStoreObjKey][storeKey].renderer;
                format = panel.localStoreObj[cellStoreObjKey][storeKey].format;
                boxRenderClass = "render-"+boxDataRender;
                dataClass = boxState ? "_hasData" : "";
              } else {
                //check if there is data or no data with cell and experiment (if experiment exist in cell object then data else no data )
                $.each(panel.json.data[panel.dx].data[cellLabel], function(cellKey, relation){
                  if(relation.val.replace(/[^\w\-]/g,'_').toLowerCase() === dyItem.toLowerCase()) {
                    rel_dimension  = relation.dimension;
                    renderer       = relation.renderer || panel.json.data[rel_dimension].renderer;
                    boxState       = relation.defaultState || panel.elLk.lookup[dyItem].defaultState; //on means blue bg, off means white bg
                    format         = relation.format || panel.elLk.lookup[dyItem].format;

                    //check for multidimension trackhub, if there is no track selected in filter matrix then cell has no data
                    if(panel.multiDimFlag && Object.keys(panel.localStoreObj.filterMatrix).length && (panel.localStoreObj.filterMatrix[storeKey].state.total === 0 || panel.localStoreObj.filterMatrix[storeKey].state.on === 0)) {
                      boxState = "";
                    }
       
                    dataClass      = boxState ? "_hasData" : "";
                    id             = relation.id;
                    boxDataRender  = renderer || panel.elLk.lookup[dyItem].renderer;
                    boxRenderClass = "render-" + boxDataRender; // peak-signal = peak_signal.svg, peak = peak.svg, signal=signal.svg

                    panel.localStoreObj[cellStoreObjKey][storeKey] = {"id": id, "state": boxState, "renderer": boxDataRender, "format": format,"reset-state": boxState, "reset-renderer": boxDataRender};

                    if(boxState) {
                      //setting count for all selection section
                      panel.localStoreObj[dyStoreObjKey]["allSelection"]["total"] += 1;
                      panel.localStoreObj[dyStoreObjKey]["allSelection"]["format"][format] = panel.localStoreObj[dyStoreObjKey]["allSelection"]["format"][format] + 1 || 1; //this is to know how many cells/tracks we have of the same format, shouldn't be changed
                      panel.localStoreObj[dyStoreObjKey]["allSelection"]["renderer"][boxDataRender] += 1;
                      panel.localStoreObj[dyStoreObjKey]["allSelection"]["renderer"]["reset-"+boxDataRender] += 1;
                      panel.localStoreObj[dyStoreObjKey]["allSelection"]["state"][boxState.replace("track-","")]++;
                      panel.localStoreObj[dyStoreObjKey]["allSelection"]["state"]["reset-"+boxState.replace("track-","")]++;

                      //setting count to update column state (dy)
                      panel.localStoreObj[dyStoreObjKey][dyItem]["total"] += 1;
                      panel.localStoreObj[dyStoreObjKey][dyItem]["renderer"][boxDataRender] += 1;
                      panel.localStoreObj[dyStoreObjKey][dyItem]["renderer"]["reset-"+boxDataRender] += 1;
                      panel.localStoreObj[dyStoreObjKey][dyItem]["state"][boxState.replace("track-","")]++;
                      panel.localStoreObj[dyStoreObjKey][dyItem]["state"]["reset-"+boxState.replace("track-","")]++;

                      //setting count to update row in matrix (dx)
                      panel.localStoreObj.matrix[cellName]["total"] += 1;
                      panel.localStoreObj.matrix[cellName]["renderer"][boxDataRender] += 1;
                      panel.localStoreObj.matrix[cellName]["renderer"]["reset-"+boxDataRender] += 1;                    
                      panel.localStoreObj.matrix[cellName]["state"][boxState.replace("track-","")]++;
                      panel.localStoreObj.matrix[cellName]["state"]["reset-"+boxState.replace("track-","")]++;
                    }
                    return;
                  }
                });
              }

              if(panel.disableYdim) {
                if(dyItem === 'epigenomic_activity' || dyItem === 'segmentation_features'){
                  rowContainer += '<div class="xBoxes '+boxState+' '+matrixClass+' '+boxRenderClass+' '+format+' '+dataClass+' '+cellName+' '+dyItem+'" data-track-x="'+dyItem+'" data-track-y="'+cellName+'" data-popup-type="column-cell" data-format="'+format+'"></div>';
                }
              } else {
                rowContainer += '<div class="xBoxes '+boxState+' '+matrixClass+' '+boxRenderClass+' '+format+' '+dataClass+' '+cellName+' '+dyItem+'" data-track-x="'+dyItem+'" data-track-y="'+cellName+'" data-popup-type="column-cell" data-format="'+format+'"></div>';
              }
            }
          });

          rowContainer += "</div>";
          boxContainer += rowContainer;
      });
    }
    yContainer += "</div>";
    boxContainer += "</div>";

    var yBoxWrapper = '<div class="yBoxWrapper">' + yContainer + boxContainer + '</div>';

    panel.el.find('div.matrix-container').append(yBoxWrapper);

    // Setting width of xContainer and yBoxWrapper (32px width box times number of xlabels)
    var hwidth = (dyArray.length * 32);
    panel.el.find('div.matrix-container .xContainer, div.matrix-container .yBoxWrapper').width(hwidth);

    panel.cellClick('config'); //opens popup
    panel.cleanMatrixStore(); //deleting items that are not present anymore
    panel.setLocalStorage();

    panel.multiDimFlag && panel.populateConfigTracksResultBox();

    // enable helptips
    panel.elLk.breadcrumb.filter(".active").attr("id") === 'track-display' && this.elLk.matrixContainer.find('.xContainer ._ht').helptip({position: {at: 'left+10 bottom+76'}});
    panel.elLk.breadcrumb.filter(".active").attr("id") === 'track-display' && this.elLk.matrixContainer.find('.yContainer ._ht').helptip({position: {at: 'center center'}});
  },

  populateConfigTracksResultBox: function() {
    var panel = this;
    var htmlContent = '';
    $.each(panel.localStoreObj.filterMatrix, function (k, v) {
      var content = '';
      if (k.match(/_sep_/)) {
        content += '<div class="header-wrapper"> <div class="_show show-hide hidden"><img src="/i/closed2.gif" class="nosprite" /></div><div class="_hide show-hide hidden"><img src="/i/open2.gif" class="nosprite" /></div>';
        content += '<h5 class="result-header">'+ k.replace('_sep_', ' - ') +'</h5>';
        content += '<ul class="result-list">';
        var flag = 0;
        $.each(panel.localStoreObj.filterMatrix[k].data, function (trackId, data) {
          if (data.show && data.state == "on") {
            flag = 1;
            content += '<li>'+ (panel.elLk.filterMatrixObj[k][trackId].shortLabel || trackId) +'</li>';
          }
        })
        content += '</ul></div>'
        if (flag === 1) htmlContent += content;
      }
    });

    panel.elLk.configResultBox.find('.config-result-box-content').html(htmlContent);
    panel.registerShowHideClickEvent();
    panel.updateShowHideLinks(panel.elLk.configResultBox.find('ul'));
  },

  emptyMatrix: function() {
    var panel = this;

    panel.el.find('div.matrix-container, div.filterMatrix-container').html('');
  },

  cleanMatrixStore: function() {
    var panel = this;

    var dimensionsArray = ["matrix"];
    var dyItems         =  $.extend({}, panel.localStoreObj.dy);
    $.map(panel.json.extra_dimensions, function(extraItem) {
      dyItems[extraItem] = 1;
    });

    $.each($.merge(dimensionsArray, panel.json.extra_dimensions), function(i,storeKey){
      $.each(panel.localStoreObj[storeKey], function(item, data) {
        if(!item.match("_sep_") && item != "allSelection") {
          if(!dyItems[item] && panel.localStoreObj.dx && !panel.localStoreObj.dx[item]) {
            panel.removeFromMatrix(item);
          }
        }
      });
    });
  },

  resetMatrix: function() {
    var panel = this;

    this.elLk.resetMatrixButton = panel.elLk.trackConfiguration.find('button.reset-button._matrix');

    this.elLk.resetMatrixButton.click("on", function() {
      panel.resetFunctionality();
    });
  },

  registerResetFilterMatrixClickEvent: function() {
    var panel = this;

    this.elLk.resetFilterMatrixButton = panel.elLk.filterTrackPanel.find('button.reset-button._filterMatrix');

    this.elLk.resetFilterMatrixButton.click("on", function() {
      panel.resetFilterMatrixToDefaults();
    });
  },

  resetFilterMatrixToDefaults: function(dimKey) {
      // e.g. dimKey = analysis_group_sep_CNAG
      var panel = this;
      var cellArray = [];
      if (dimKey) {
        $.each(Object.keys(panel.elLk.extraDimValToCellMap[dimKey].cells), function(i, v) {
          if (panel.localStoreObj.filterMatrix[v]) {
            update(v, panel.localStoreObj.filterMatrix[v]);
          }
        });
      }
      else {
        $.each(panel.localStoreObj.filterMatrix, function(cellKey, cellHash) {
          update(cellKey, cellHash);
        });

        panel.localStoreObj.other_dimensions = $.extend({}, panel.localStoreObj.reset_other_dimensions);
        panel.setLocalStorage();
        panel.updateFilterMatrix(cellArray);
        panel.updateFilterMatrixRHS();        
      }


      function update(cellKey, cellHash) {
        $.each(cellHash.data, function(trackId, statusHash){
            if(statusHash.state != statusHash["reset-state"] || statusHash.show != statusHash["reset-show"]){
              cellArray.push(cellKey);
              statusHash.state = statusHash["reset-state"];
              statusHash.show  = statusHash["reset-show"];
            }
        });
        cellHash.state.off   = cellHash.state["reset-off"];
        cellHash.state.on    = cellHash.state["reset-on"];
        cellHash.state.total = cellHash.state["reset-total"];

        //check if by resetting, there are on tracks selected then need to update final matrix
        var configCellState     = panel.localStoreObj.matrix[cellKey].state;
        var configCellFormat    = panel.localStoreObj.matrix[cellKey].format;
        var configCellRenderer  = panel.localStoreObj.matrix[cellKey].renderer;        
        if(cellHash.state["reset-total"] === 0 || cellHash.state["reset-on"] === 0) {
          //update matrix store (in all selection: minus count for current state and total count; set cell state)
          panel.localStoreObj.matrix.allSelection.state[configCellState.replace("track-","")] -= 1;
          panel.localStoreObj.matrix.allSelection.format[configCellFormat] -= 1;
          panel.localStoreObj.matrix.allSelection.renderer[configCellRenderer] -= 1;
          panel.localStoreObj.matrix.allSelection.total -= 1;
          panel.localStoreObj.matrix[cellKey].state = "";
        }
      }

  },

  resetFunctionality: function(stateOnly) {
    var panel = this;

    var allStoreObjects = $.extend({}, panel.localStoreObj.matrix);
    $.each(panel.json.extra_dimensions,function(i, dim){
      $.extend(allStoreObjects, panel.localStoreObj[dim]);
    });

    Object.keys(allStoreObjects).map(function(key) {
      var storeObjKey = panel.itemDimension(key);
      if(key.match("_sep_")) {
        var currentState    = allStoreObjects[key]["state"];
        var resetState      = allStoreObjects[key]["reset-state"];
        if(currentState) {
          if(!stateOnly) {
            var currentRenderer = allStoreObjects[key]["renderer"];
            var resetRenderer   = allStoreObjects[key]["reset-renderer"];
          }

          panel.elLk.matrixContainer.find('div.xBoxes.'+key.split("_sep_")[0]+'.'+key.split("_sep_")[1]).removeClass(currentState).addClass(resetState);
          panel.localStoreObj[storeObjKey][key]["state"] = resetState;

          if(!stateOnly){
            panel.elLk.matrixContainer.find('div.xBoxes.'+key.split("_sep_")[0]+'.'+key.split("_sep_")[1]).removeClass("render-"+currentRenderer).addClass("render-"+resetRenderer);
            panel.localStoreObj[storeObjKey][key]["renderer"] = resetRenderer;
          }
        }
      } else {
        panel.localStoreObj[storeObjKey][key]["state"]["on"]   = allStoreObjects[key]["state"]["reset-on"];
        panel.localStoreObj[storeObjKey][key]["state"]["off"]  = allStoreObjects[key]["state"]["reset-off"];

        if(!stateOnly) {
          $.each(panel.elLk.lookup.rendererKeys, function(rendererName, i){
            panel.localStoreObj[storeObjKey][key]["renderer"][rendererName] = allStoreObjects[key]["renderer"]["reset-"+rendererName];  
          });
        }

        //resetting all selection
        panel.localStoreObj[storeObjKey]["allSelection"]["state"]["on"] = panel.multiDimFlag ? allStoreObjects["allSelection"]["total"] : allStoreObjects["allSelection"]["state"]["reset-on"];
        if(!panel.multiDimFlag) {
          panel.localStoreObj[storeObjKey]["allSelection"]["state"]["off"] = allStoreObjects["allSelection"]["state"]["reset-off"];
        }

        if(!stateOnly) {
          $.each(panel.elLk.lookup.rendererKeys, function(i, rendererName) {
            panel.localStoreObj[storeObjKey]["allSelection"]["renderer"][rendererName] = allStoreObjects["allSelection"]["renderer"]["reset-"+rendererName];  
          });
        }
      }
    });
    panel.setLocalStorage();
  },

  resetTracks: function() {
    var panel = this;

    this.elLk.resetTrack = panel.elLk.resultBox.find('div.reset_track');

    this.elLk.resetTrack.click("on", function(e) {
      
      $.each(panel.elLk.resultBox.find('li').not(".noremove"), function(i, ele){
        panel.selectBox(ele);
        panel.filterData($(ele).data('item'));
      }); 
      panel.updateRHS();     

      // Apply cell first so that filter happens and then select all experiment types
      if (panel.localStoreObj.dx) {
        panel.localStoreObj.dx  = panel.localStoreObj.reset_dx;
        var el;
        $.each(panel.localStoreObj.dx, function(k) {
          el = panel.elLk.dx.tabContents.not(':not(.'+ k +')');
          panel.selectBox(el);
        });
        panel.filterData($(el).data('item'));
      }
      if (panel.localStoreObj.dy) {
        panel.localStoreObj.dy  = panel.localStoreObj.reset_dy;
        var el;
        $.each(panel.localStoreObj.dy, function(k) {
          el = panel.elLk.dy.tabContents.filter(function() {return $(this).hasClass(k)});
          panel.selectBox(el);
        });

        // If there were no celltypes selected then filter based on exp type
        !panel.localStoreObj.dx && panel.localStoreObj.dy && panel.filterData($(el).data('item'));
      }
      panel.setLocalStorage();
      panel.updateRHS();
      e.stopPropagation();
      panel.resetFilter("",true);
    });
  },

  buildMatrixPopup: function(format) {
    var panel = this;

    var ul = panel.el.find('div.track-popup ul._cell .cell-style .renderers ul');
    var defaultVal = 'Default';
    var r_opts = '';

    $.each(panel.rendererConfig[format], function(i, renderer){
      r_opts += '<li class="' + renderer + '"><i class="' + renderer + '"></i>' + panel.rendererTextMap[renderer] + '</li>';
    });
    ul.html(r_opts);
  },

  buildFilterMatrixPopup: function(key) {
    var panel = this;
    if (key ===  undefined || !panel.localStoreObj.filterMatrix || !panel.localStoreObj.filterMatrix[key]) return;
    var li_html = '';
    var ul = panel.el.find('div.track-popup._filterMatrix ul');
    var all_selected = panel.localStoreObj.filterMatrix[key].state.on === panel.localStoreObj.filterMatrix[key].state.total ? "selected" : "";
    
    //Make sense to only show All checkbox if there is more than 1 tracks to select
    if(Object.keys(panel.localStoreObj.filterMatrix[key].data).length > 1) {
      li_html += '<li class="all"><span class="fancy-checkbox all '+all_selected+'" data-cell="'+key+'"></span><text>All</text></li>';
    }

    $.each(panel.localStoreObj.filterMatrix[key].data, function(id, hash){
      var selected = hash.state === "on" ? "selected" : "";
      var shortLabel = panel.elLk.filterMatrixObj[key][id].shortLabel;
      if(hash.show === 1) {
        li_html += '<li data-track-id="' + id + '" class="_ht" title="'+ panel.createTooltipText(key,id) +'"><span class="fancy-checkbox '+selected+'" data-cell="'+key+'"></span><text>' + shortLabel + '</text></li>';
      }
    });
    ul.html(li_html);
    ul.parent().show();
  },

  cellClick: function(matrix) {
    var panel = this;

    panel.elLk.rowContainer = this.elLk.matrixContainer.find('div.rowContainer');
    panel.popupType      = "";
    panel.TrackPopupType = "";
    panel.xLabel         = "";
    panel.yLabel         = "";
    panel.xName          = "";
    panel.yName          = "";
    panel.boxObj         = "";

    panel.el.find('div.matrix-container div.xBoxes.track-on, div.matrix-container div.xBoxes.track-off, div.filterMatrix-container div.xBoxes').off().on("click", function(e){
      panel.el.find('div.matrix-container div.xBoxes.track-on.mClick, div.matrix-container div.xBoxes.track-off.mClick, div.filterMatrix-container div.xBoxes').removeClass("mClick");

      if(!$(this).hasClass('_hasData')) { return; }
      panel.trackPopup.hide();

      panel.boxObj          = $(this);
      panel.popupType       = $(this).data("popup-type"); //type of popup to use which is associated with the class name
      panel.TrackPopupType  = panel.el.find('div.track-popup.'+panel.popupType);
      panel.xName           = $(this).data("track-x");
      panel.yName           = $(this).data("track-y");
      panel.xLabel          = $(panel.elLk.rowContainer.find('div.xLabel.'+panel.xName));
      panel.yLabel          = $(panel.elLk.rowContainer.find('div.yLabel.'+panel.yName));
      panel.cellKey         = panel.xName+"_sep_"+panel.yName;
      panel.cellStateKey    = panel.itemDimension(panel.cellKey) || "";
      panel.dyStateKey      = panel.itemDimension(panel.yName) || "";
      panel.dxStateKey      = panel.itemDimension(panel.xName) || "";

      var key = panel.xName + '_sep_' + panel.yName;
      matrix === 'filter' ? panel.buildFilterMatrixPopup(key) : panel.buildMatrixPopup($(this).data("format"));

      var boxState  = panel.localStoreObj[panel.cellStateKey][panel.cellKey].state; //is the track on or off
      var boxRender = panel.localStoreObj[panel.cellStateKey][panel.cellKey].renderer; //is the track peak or signal or peak-signal
      var cellFormat = panel.localStoreObj[panel.cellStateKey][panel.cellKey].format; //Track format

      // check if all is on/off
      var allState = "";
      if(panel.localStoreObj[panel.dxStateKey]["allSelection"].state.on === panel.localStoreObj[panel.dxStateKey]["allSelection"].total) { allState = "track-on"; } 
      if(panel.localStoreObj[panel.dxStateKey]["allSelection"].state.off === panel.localStoreObj[panel.dxStateKey]["allSelection"].total) { allState = "track-off"; } 

      var allRender = "";
      $.map(panel.localStoreObj[panel.dxStateKey]["allSelection"]["renderer"], function(count, rendererType){
        if(!rendererType.match("reset-") && boxRender === rendererType && count === panel.localStoreObj[panel.dxStateKey]["allSelection"]['format'][cellFormat]) {
          allRender = true;
          return;
        }
      });

      $(this).addClass("mClick");

      //setting box/cell switch on/off
      if(boxState === "track-on") {
        panel.TrackPopupType.find('ul li label.switch input[name="cell-switch"]').prop("checked",true);
      } else {
        panel.TrackPopupType.find('ul li label.switch input[name="cell-switch"]').prop("checked",false);
      }

      //setting dropdown for cell renderer dropdown>>>>>
      if(boxRender) {
        panel.TrackPopupType.find('ul li input[name=cell-radio]._'+boxRender).prop("checked",true);
      } else {
        panel.TrackPopupType.find('ul li input[name=cell-radio]').prop("checked",false);
      }

      //setting all switch on/off
      if(allState === "track-on" || allState === "track-off") {
        panel.TrackPopupType.find('div input#all-cells-stateBox').prop("checked",true);
      } else {
        panel.TrackPopupType.find('div input#all-cells-stateBox').prop("checked",false);
      }

      //tick apply to all cells box
      if(allRender) {
        panel.TrackPopupType.find('input#apply_to_all').prop("checked",true);
      } else {
        panel.TrackPopupType.find('input#apply_to_all').prop("checked",false);
      }


      //center the popup on the box, get the x and y position of the box and then add half the length
      //populating the popup settings (on/off, peak, signals...) based on the data attribute value
      var scrollEle = matrix === 'config' ? $('div.matrix-container')[0] : $('div.filterMatrix-container')[0];
      panel.TrackPopupType.attr("data-track-x",$(this).data("track-x")).attr("data-track-y",$(this).data("track-y")).css({'top': ($(this)[0].offsetTop - $(scrollEle).scrollTop()) + 15, 'left': ($(this)[0].offsetLeft - $(scrollEle).scrollLeft()) + 15}).show();

      panel.popupFunctionality(matrix); //interaction inside popup
      e.stopPropagation();
      // Register filter matrix only when it is multi dimensional
      // panel.multiDimFlag && matrix === 'filter' && panel.registerFilterMatrixCellClickEvent();
      matrix === 'config' && new panel.dropDown(panel, boxRender);
      $('.track-popup._filterMatrix').find('._ht').helptip({position: {at: 'center bottom-15'}});
    });
  },

  // Function to update the filtermatrix store obj when selecting/unselecting checkboxes from popup or RHS
  //
  updateFilterMatrixStore: function(storeObj, cellKey, newState, currentState, all, showValue, allRHS) {
    var panel = this;

    if(all) { //clicking all in matrix popup
      $.each(storeObj.data, function(trackId, hash){
        hash.state = newState;
      });
      panel.localStoreObj.filterMatrix[cellKey].state[currentState] = 0;
      panel.localStoreObj.filterMatrix[cellKey].state[newState] = panel.localStoreObj.filterMatrix[cellKey].state.total;
    } else {
      if(showValue != undefined) { //show can be either 0 or 1 (when clicking element in RHS filter track)        
        if(allRHS){
          panel.localStoreObj.filterMatrix[cellKey].state[currentState] = 0;
          panel.localStoreObj.filterMatrix[cellKey].state.total = newState === "on" ? Object.keys(panel.localStoreObj.filterMatrix[cellKey].data).length : 0;
          panel.localStoreObj.filterMatrix[cellKey].state[newState] = newState === "on" ? Object.keys(panel.localStoreObj.filterMatrix[cellKey].data).length : 0;
        } else {
          if(showValue === 1) { //showing track and switching it on
            if(storeObj.state != "on") {
              panel.localStoreObj.filterMatrix[cellKey].state.total += 1;
              panel.localStoreObj.filterMatrix[cellKey].state["on"] += 1;
            }
          } else { //not showing track and switch it off
            if(storeObj.show === 1) { 
              panel.localStoreObj.filterMatrix[cellKey].state.total -= 1;
              panel.localStoreObj.filterMatrix[cellKey].state[storeObj.state] -= 1;
            }
          }
        }
        storeObj.show = showValue; // This has to be the last thing to do
      } else { //clicking element in matrix popup
        panel.localStoreObj.filterMatrix[cellKey].state[currentState] -= 1;
        panel.localStoreObj.filterMatrix[cellKey].state[newState] += 1;
      }
      storeObj.state = newState; // This has to be the last thing to do
    }
    //if no tracks selected or no tracks, it means final matrix cell will show no data, needs to update all selection count and cell state for final matrix
    var configCellState     = panel.localStoreObj.matrix[cellKey].state;
    var configCellFormat    = panel.localStoreObj.matrix[cellKey].format;
    var configCellRenderer  = panel.localStoreObj.matrix[cellKey].renderer;
    if(panel.localStoreObj.filterMatrix[cellKey].state.total === 0 || panel.localStoreObj.filterMatrix[cellKey].state.on === 0) {
      //update matrix store (in all selection: minus count for current state and total count; set cell state)
      panel.localStoreObj.matrix.allSelection.state[configCellState.replace("track-","")] -= 1;
      panel.localStoreObj.matrix.allSelection.state["reset-"+ configCellState.replace("track-","")] -= 1;
      panel.localStoreObj.matrix.allSelection.format[configCellFormat] -= 1;
      panel.localStoreObj.matrix.allSelection.renderer[configCellRenderer] -= 1;
      panel.localStoreObj.matrix.allSelection.renderer["reset-"+configCellRenderer] -= 1;
      panel.localStoreObj.matrix.allSelection.total -= 1;

      panel.localStoreObj.matrix[cellKey].state = "";
      panel.localStoreObj.matrix[cellKey]["reset-state"] = "";
    } else { // cell will be on in final matrix
      if(configCellState) { // if current cell matrix is on/off, update count accordingly
        panel.localStoreObj.matrix.allSelection.state[configCellState.replace("track-","")] -= 1;
        panel.localStoreObj.matrix.allSelection.state["reset-"+configCellState.replace("track-","")] -= 1;
        panel.localStoreObj.matrix.allSelection.state["on"] += 1;
        panel.localStoreObj.matrix.allSelection.state["reset-on"] += 1;
      } else { //cell had no data, need to update all counts (on, total, format, renderer)
        panel.localStoreObj.matrix.allSelection.format[configCellFormat] += 1;
        panel.localStoreObj.matrix.allSelection.renderer[configCellRenderer] += 1;
        panel.localStoreObj.matrix.allSelection.renderer["reset-"+configCellRenderer] += 1;
        panel.localStoreObj.matrix.allSelection.state["on"] += 1;
        panel.localStoreObj.matrix.allSelection.state["reset-on"] += 1;
        panel.localStoreObj.matrix.allSelection["total"] += 1;
      }
      panel.localStoreObj.matrix[cellKey].state = "track-on";
      panel.localStoreObj.matrix[cellKey]["reset-state"] = "track-on";
    }
    panel.setLocalStorage();
  },

  //function to update filte matrix cells (on/off/partial) and show the counts
  // Arguments: array of cells affected
  updateFilterMatrix: function(cellArray) {
    var panel = this;

    //updating just one cell
    $.each(cellArray, function(i, cellKey) {
      var boxState = "";
      var boxCountHTML = "";
      if(panel.localStoreObj["filterMatrix"][cellKey]["state"]["total"] === 0){
        boxState = "";
        boxCountHTML="";
      } else if(panel.localStoreObj["filterMatrix"][cellKey]["state"]["on"] === panel.localStoreObj["filterMatrix"][cellKey]["state"]["total"]) { 
        boxState = "_hasData track-on";
        boxCountHTML = '<span class="count">'+panel.localStoreObj["filterMatrix"][cellKey]["state"]["on"]+'</span>';
      } else if(panel.localStoreObj["filterMatrix"][cellKey]["state"]["off"]  === panel.localStoreObj["filterMatrix"][cellKey]["state"]["total"] ){
        boxState = "_hasData partzero";
        boxCountHTML = '<span class="partialCount">0</span><span class="count">'+panel.localStoreObj["filterMatrix"][cellKey]["state"]["total"]+'</span>';
      }else {
        var partialCount = panel.localStoreObj["filterMatrix"][cellKey]["state"]["total"] - panel.localStoreObj["filterMatrix"][cellKey]["state"]["off"];
        boxState = partialCount === 0 ? "_hasData partzero" : "_hasData partial";
        boxCountHTML = '<span class="partialCount">'+partialCount+'</span><span class="count">'+panel.localStoreObj["filterMatrix"][cellKey]["state"]["total"]+'</span>';
      }

      panel.elLk.filterMatrix.find('div.'+cellKey).removeClass("track-on track-off partial partzero _hasData").addClass(boxState).html(boxCountHTML);

    });
  },

  //function to update the store obj when clicking the on/off or renderers
  // Format is the cell format thats being updated
  updateTrackStore: function(storeObj, trackKey, newState, currentState, newRenderer, currentRenderer, format){
    var panel = this;

    var statusKey   = newState ? "state" : "renderer";
    var newValue    = newState ?  newState.replace("track-","") : newRenderer;
    var currValue   = currentState ?  currentState.replace("track-","") : currentRenderer;

    if(trackKey === "allSelection"){
      Object.keys(storeObj).filter(function(key){
        if(key.match("_sep_")){
          if(newRenderer) { //only for renderers we update cells with same format
            storeObj[key][statusKey] = storeObj[key]["format"] === format ?  newRenderer : storeObj[key][statusKey];
          } else {
            storeObj[key][statusKey] = newState ?  newState : newRenderer;
          }
        } else {
          $.each(storeObj[key][statusKey], function(keyName, count){
            if(newValue === keyName) {
              storeObj[key][statusKey][keyName] = storeObj[key]["total"];
            } else {
              if(!keyName.match("reset-")) { storeObj[key][statusKey][keyName] = 0; }
            }
          });
        }
      });
      panel.setLocalStorage();
      return;
    }
    var keyDim      = panel.itemDimension(trackKey);
    //console.log("STATUSKEY:"+statusKey+">>newValue>>"+newValue+">>TrackKey>>"+trackKey)

    //update cell in store obj and update count for affected row/column
    if(trackKey.match("_sep_")) {
      storeObj[statusKey] = newState ?  newState : newRenderer;

      var allUpdated = 0;

      $.each(trackKey.split("_sep_"), function(i, splitTrack){
        if(panel.localStoreObj[panel.dxStateKey][splitTrack][statusKey][newValue] < panel.localStoreObj[panel.dxStateKey][splitTrack]["total"]) {
          panel.localStoreObj[panel.dxStateKey][splitTrack][statusKey][newValue] += 1;
        }
        if(panel.localStoreObj[panel.dxStateKey][splitTrack][statusKey][currValue] > 0) {
          panel.localStoreObj[panel.dxStateKey][splitTrack][statusKey][currValue] -= 1;
        }

        //updating allSelection
        if(!allUpdated) {
          if(panel.localStoreObj[panel.dxStateKey]["allSelection"][statusKey][newValue] < panel.localStoreObj[panel.dxStateKey]["allSelection"]["total"]) {
            panel.localStoreObj[panel.dxStateKey]["allSelection"][statusKey][newValue] += 1;
          }
          if(panel.localStoreObj[panel.dxStateKey]["allSelection"][statusKey][currValue] > 0) {
            panel.localStoreObj[panel.dxStateKey]["allSelection"][statusKey][currValue] -= 1;
          }
          allUpdated = 1; //CAUTION HERE: the above only needs to be done once
        }
        if(keyDim != "matrix") { return false; }
      });

    } else {  //if it is row or column or allSelection, set new state/renderer type to total count and the previous state/renderer to 0, and for each affected row/column update the count
      $.each(storeObj[statusKey], function(rendererType, val){
        if(rendererType === newValue) {
          storeObj[statusKey][rendererType] = storeObj["total"];
        } else {
          if(!rendererType.match("reset-")) {
            storeObj[statusKey][rendererType] = 0;
          }
        }
      });

      //update each affected row or column state/renderer type(-1 from current, +1 for new)
      Object.keys(panel.localStoreObj[keyDim]).filter(function(key){
        //find associated track with the trackKey (only the one with _sep_)
        if(key.match(trackKey) && key.match("_sep_")) {
          //console.log("KEY>>>>"+key)
          //updating the associated one only not the trackKey (only do this for matrix)
          if(keyDim === "matrix") {
            $.grep(key.split("_sep_"), function(associatedEle, i){
              // console.log(keyDim+">>>>"+associatedEle);
              // console.log(panel.localStoreObj[keyDim][key][statusKey]);

              var cellCurrValue = panel.localStoreObj[keyDim][key][statusKey];
              var cellNewValue  = newState ? newState : newRenderer;
              cellCurrValue = cellCurrValue.replace("track-","");
              cellNewValue = cellNewValue.replace("track-","");

              if(associatedEle != trackKey && cellCurrValue != cellNewValue ) {
                if(panel.localStoreObj[keyDim][associatedEle][statusKey][newValue] < panel.localStoreObj[keyDim][associatedEle]["total"]) {
                  panel.localStoreObj[keyDim][associatedEle][statusKey][newValue] += 1;
                }
                if(panel.localStoreObj[keyDim][associatedEle][statusKey][cellCurrValue] > 0) {
                  panel.localStoreObj[keyDim][associatedEle][statusKey][cellCurrValue] -= 1;
                }

                //updating allSelection
                if(panel.localStoreObj[keyDim]["allSelection"][statusKey][newValue] < panel.localStoreObj[keyDim]["allSelection"]["total"]) {
                  panel.localStoreObj[keyDim]["allSelection"][statusKey][newValue] += 1;
                }
                if(panel.localStoreObj[keyDim]["allSelection"][statusKey][cellCurrValue] > 0) {
                  panel.localStoreObj[keyDim]["allSelection"][statusKey][cellCurrValue] -= 1;
                }
              }
            });
          }
          //updating each cell in the store
          panel.localStoreObj[keyDim][key][statusKey] = newState ? newState : newRenderer;
        }
      });
    }
    panel.setLocalStorage();
  },

  //function to handle functionalities inside popup (switching off track or changing renderer) and updating state (localstore obj)
  //Argument: Object of the cell/box clicked
  popupFunctionality: function(matrix) {
    var panel = this;

    //Filter matrix popup functionality
    if(matrix === "filter") {
      panel.TrackPopupType.find('li').off().on("click", function(e){
        // Select/deslect all boxes for that dimension
        var fcb = $(this).children('span.fancy-checkbox');
        fcb.toggleClass('selected');
        var clickedTrackId = $(this).data('track-id');
        if ($(this).hasClass('all')) {
          if (fcb.hasClass('selected')) {
            $(this).siblings().each(function(i, sib) {
              $(sib).children('span.fancy-checkbox').removeClass('selected').addClass('selected');
            });
          }
          else {
            $(this).siblings().each(function(i, sib) {
              $(sib).children('span.fancy-checkbox').removeClass('selected');
            });
          }
        }

        var cellKey      = fcb.data("cell");
        var currentState = fcb.hasClass('selected') ? "off" : "on";
        var newState     = currentState === "on" ? "off" : "on";

        if($(this).find('span.fancy-checkbox.all').length){ //all checkbox
          panel.updateFilterMatrixStore(panel.localStoreObj.filterMatrix[cellKey], cellKey, newState, currentState, 1 );
        } else {
          var trackId       = $(this).data("track-id");
          panel.updateFilterMatrixStore(panel.localStoreObj.filterMatrix[cellKey].data[trackId], cellKey, newState, currentState );
          // check if all checkbox is on, select "all" checkbox
          if(panel.localStoreObj.filterMatrix[cellKey].state.total === panel.localStoreObj.filterMatrix[cellKey].state.on) {
            panel.TrackPopupType.find('ul span.fancy-checkbox.all').addClass("selected");
          } else {
            panel.TrackPopupType.find('ul span.fancy-checkbox.all').removeClass("selected");
          }
        }
        panel.updateFilterMatrix([cellKey]);
        panel.updateFilterMatrixRHS();
      });
      //tick apply renderers to all cell box
      panel.TrackPopupType.find('input#apply_to_all').off().on("click", function(e) {
        if(e.currentTarget.checked){ //only if the box is tick then update all
          panel.updateRenderer(panel.TrackPopupType.find('div#dd.renderers ul.dropdown li.selected i').attr('class'), $(this));
        }      
        e.stopPropagation();
      });      
    } else {

      //choosing toggle button - column-switch/row-switch/cell-switch
      //if column is off, set data-track-state to track-off in xLabel, if row is off, set data-track-state to track-off in yLabel, if cell is off set data-track-state to track-off in xBox
      //update localstore obj
      panel.TrackPopupType.find('ul li label.switch input[type=checkbox]').off().on("click", function(e) {
        var switchName    = $(this).attr("name");
        var trackState    = $(this).is(":checked") ? "track-on" : "track-off";
        var currentState  = trackState === "track-on"  ? "track-off" : "track-on";

        if(switchName === "cell-switch") { //cell-switch
          panel.boxObj.removeClass(currentState).addClass(trackState);//update bg for cells

          //update localstore for cell and equivalent rows/columns
          var trackComb = panel.xName+"_sep_"+panel.yName;
          panel.updateTrackStore(panel.localStoreObj[panel.dxStateKey][trackComb], trackComb, trackState, currentState);

          // State data would be either inside localStoreObj.matrix or localStoreObj.<other_dimentions>
          if (panel.localStoreObj[panel.dyStateKey][panel.yName]) {
            yNameData = panel.localStoreObj[panel.dyStateKey][panel.yName];
          }

          if (panel.localStoreObj[panel.dyStateKey][panel.xName]) {
            xNameData = panel.localStoreObj[panel.dyStateKey][panel.xName];
          }
          else if (panel.localStoreObj[panel.xName][panel.xName]) {
            xNameData = panel.localStoreObj[panel.xName][panel.xName];
          }

          //if all cells state checkbox is ticked, means apply the same state to all of the cells
          if(panel.TrackPopupType.find('div.all-cells-state input[name=all-cells]').is(":checked")){
            //update bg for all cells in the row belonging to matrix only and also switch cell off
            panel.elLk.rowContainer.find('div.xBoxes.matrix._hasData.'+currentState).removeClass(currentState).addClass(trackState);
    
            //update localstore for whole matrix
            panel.updateTrackStore(panel.localStoreObj[panel.dxStateKey], "allSelection", trackState, currentState);   
          } else {
            // Checked if by switching this one cell all cells are on/off means tick all cell checkbox
            if(panel.localStoreObj[panel.dyStateKey]["allSelection"] && (panel.localStoreObj[panel.dyStateKey]["allSelection"].state.on === panel.localStoreObj[panel.dyStateKey]["allSelection"].total || panel.localStoreObj[panel.dyStateKey]["allSelection"].state.off === panel.localStoreObj[panel.dyStateKey]["allSelection"].total) ) {
              panel.TrackPopupType.find('div input#all-cells-stateBox').prop("checked",true);
            } else {
              // not sure we want to do this, thats basically overwriting user selection
              //panel.TrackPopupType.find('div input#all-cells-stateBox').prop("checked",false);
            }
          }          
        }
        e.stopPropagation();
      });

      // choosing all cells radio button (on/off)
      panel.TrackPopupType.find('div.all-cells-state input[name=all-cells]').off().on("click", function(e) {
        if(!$(this).is(":checked")) { return ; } //dont do anything if it is unchecking box
        
        var cellSwitchVal = panel.TrackPopupType.find('ul li label.switch input[name="cell-switch"]').is(":checked") ? "on" : "off";
        var trackState    = "track-"+cellSwitchVal;
        var currentState  = trackState === "track-on"  ? "track-off" : "track-on";

        //update bg for all cells in the row belonging to matrix only and also switch cell off
        panel.elLk.rowContainer.find('div.xBoxes.matrix._hasData.'+currentState).removeClass(currentState).addClass(trackState);

        //update localstore for whole matrix
        panel.updateTrackStore(panel.localStoreObj[panel.dxStateKey], "allSelection", trackState, currentState);    
      });

      //reset track state (all cells)
      panel.TrackPopupType.find('div.reset_track_state').click("on", function() {
        panel.resetFunctionality(1);

        //switching off/on cell switch after resetting
        var cellState = panel.localStoreObj[panel.dxStateKey][panel.xName+"_sep_"+panel.yName]["reset-state"].replace("track-","");
        panel.TrackPopupType.find('ul li label.switch input[name="cell-switch"]').prop("checked", cellState === "on" ? true : false);

        // Checked All cells on radio button if after resetting all are on
        if(panel.localStoreObj[panel.dyStateKey]["allSelection"] && (panel.localStoreObj[panel.dyStateKey]["allSelection"].state.on === panel.localStoreObj[panel.dyStateKey]["allSelection"].total || panel.localStoreObj[panel.dyStateKey]["allSelection"].state.off === panel.localStoreObj[panel.dyStateKey]["allSelection"].total) ) {
          panel.TrackPopupType.find('div input#all-cells-stateBox').prop("checked",true);
        } else {
          panel.TrackPopupType.find('div input#all-cells-stateBox').prop("checked",false);
        }
      });      

    }
  },

  updateRenderer: function(renderClass, clickedEle) {
    var panel         = this;
    var currentRender = panel.localStoreObj.matrix[panel.cellKey].renderer;
    var trackFormat        = panel.localStoreObj.matrix[panel.cellKey].format;
    // var dimension     = radioName === "column-radio" ? panel.xName : panel.yName;
    var storeObjKey   = panel.itemDimension(panel.xName);

    // change cell renderer only via dropdown    
    //updating the render class for the cell
    panel.boxObj.removeClass("render-"+currentRender).addClass("render-"+renderClass);

    //update localstore
    panel.updateTrackStore(panel.localStoreObj[storeObjKey][panel.cellKey], panel.cellKey, "", "", renderClass, currentRender);

    if ((clickedEle && clickedEle.attr('id') === "apply_to_all") || (!clickedEle && panel.TrackPopupType.find('input#apply_to_all:checked').length)){
      //panel.TrackPopupType.find('ul li input[name$=-radio]._'+renderClass).prop("checked", true);

      panel.elLk.matrixContainer.find('div.xBoxes._hasData.matrix.'+trackFormat).removeClass(function(index, className){ return (className.match (/(^|\s)render-\S+/g) || []).join(' ');}).addClass("render-"+renderClass);

      panel.updateTrackStore(panel.localStoreObj[storeObjKey], "allSelection", "", "", renderClass, currentRender, trackFormat);
    }

    //check if by changing this one cell, all cells in the whole matrix are same, then update all renderer accordingly
    if(panel.localStoreObj[panel.dyStateKey]["allSelection"].renderer[renderClass] === panel.localStoreObj[panel.dyStateKey]["allSelection"]["format"][trackFormat]){
      panel.TrackPopupType.find('input#apply_to_all').prop("checked", true);
    } else {
      panel.TrackPopupType.find('input#apply_to_all').prop("checked", false);
    }
  }
});
