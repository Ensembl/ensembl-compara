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
    //Ensembl.EventManager.register('mouseUp',              this, this.dragStop);
    //Ensembl.EventManager.register('updateConfiguration',  this, this.updateConfiguration);
    //Ensembl.EventManager.register('changeColumnRenderer', this, this.changeColumnRenderer);
    Ensembl.EventManager.register('modalPanelResize',     this, this.setScrollerSize);
  },
  
  init: function () {
    var panel = this;
    
    Ensembl.Panel.prototype.init.call(this); // skip the Configurator init - does a load of stuff that isn't needed here

    this.elLk.cellPanel       = this.el.find("div#cell-panel");
    this.elLk.experimentPanel = this.el.find("div#experiment-panel");
    this.elLk.buttonTab       = this.el.find("div.track-tab");
    this.elLk.contentTab      = this.el.find("div.tab-content");
    this.elLk.filterList      = this.el.find("ul.result-list");
    this.elLk.filterButton    = this.el.find("button.filter");
    this.elLk.clearAll        = this.el.find("span.clearall");
    
    this.buttonOriginalWidth = this.elLk.filterButton.outerWidth();
    this.buttonOriginalHTML  = this.elLk.filterButton.html();

    panel.el.find("div#experiment-tab div.search-box").hide();

    $.ajax({
      url: '/Json/RegulationData/data?species='+Ensembl.species,
      dataType: 'json',
      context: this,
      success: function(json) {
         panel.json_data = json;
         panel.trackTab();
      },
      error: function() {
        this.showError();
      }
    });
    
    this.elLk.buttonTab.on("click", function (e) { 
      var selectTab = panel.el.find(this).attr("id");
      
      panel.toggleTab(this, panel.el.find("div.track-menu"));
      
      //if button is Edit and then browse track tab or search track tab is clicked then change it to Apply Filters
      //if button is Apply filters and it is active and then track configuration tab is shown then change it to Edit
      // if(selectTab === 'search-tab' || selectTab === 'browse-tab')
      // {
        // if(panel.elLk.filterButton.hasClass("_edit")) {
          // panel.elLk.filterButton.removeClass("_edit").outerWidth(panel.buttonOriginalWidth).html(panel.buttonOriginalHTML);
        // }
      // } else if (selectTab === 'config-tab' && !panel.elLk.filterButton.hasClass("_edit") && panel.elLk.filterButton.hasClass("active")) {
        // panel.elLk.filterButton.addClass("_edit").outerWidth("70px").html("Edit");
      // }
    });
    
    panel.clickSubResultLink();
    panel.showHideFilters();
    panel.clickCheckbox(this.elLk.filterList, 1);
    panel.clearAll(this.elLk.clearAll);
    panel.clickFilter(panel.elLk.filterButton, panel.el.find("div#track-config"));    
  },
  
  //function when click clear all link which should reset all the filters
  clearAll: function (clearLink) {
    var panel = this;
    
    clearLink.on("click",function(e){
      $.each(panel.el.find('div.result-box').find('li').not(".noremove"), function(i, ele){
        panel.selectBox(ele, 1, 0);
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
  updateCurrentCount: function(currentElObj, number) {
    var panel = this;

    number = number ? number : 1;

    if(currentElObj.length) {
      var add_num = parseInt(currentElObj.html()) + number;
      currentElObj.html(add_num);
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
    $(container).on("click", itemListen, function(e) {
      panel.selectBox(this, removeElement, addElement);

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
  
  //Function to select filters and adding/removing them in the relevant panel
  selectBox: function(ele, removeElement, addElement) {
    var panel = this;
    if($(ele).find("span.fancy-checkbox.selected").length){
      $(ele).find("span.fancy-checkbox").removeClass("selected");

      //removing element from right hand panel (selection panel) - optional
      if(removeElement && !ele.className.match("noremove")){
        //unselecting from left hand panel when unselecting/removing in right hand panel
        var lhsectionId = $(ele).closest("ul.result-list").find("span.lhsection-id").html();
        var allBoxId    = $(ele).find('span.allBox-id').html();

        panel.updateCurrentCount($(ele).parent().parent().find("div.count-container").find('span.current-count'), -1);
        panel.showHideLink($(ele).parent().parent()); //need to be after updateCurrentCount
        panel.el.find('div#'+lhsectionId+' li.'+$(ele).attr('class')+' span.fancy-checkbox').removeClass("selected");
        ele.remove();
  
        //if select all box is selected, it needs to be unselected if one track is removed
        if(panel.el.find('div#'+allBoxId+' span.fancy-checkbox.selected').length) {
          panel.el.find('div#'+allBoxId+' span.fancy-checkbox').removeClass("selected");        
        }
      }
      //removing from right hand panel when unselecting in left hand panel
      if(addElement) {          
        var rhsectionId = $(ele).closest("div.tab-content.active").find('span.rhsection-id').html();
        var elementClass = $(ele).find('text').html().replace(/[^\w\-]/g,'_');
        panel.el.find('div#'+rhsectionId+' ul li.'+elementClass).remove();
        panel.updateCurrentCount(panel.el.find('div#'+rhsectionId+' span.current-count'), -1);
        panel.showHideLink(panel.el.find('div#' + rhsectionId)); //need to be after updateCurrentCount
      }
    } else {
      if(addElement) {
        var rhsectionId  = $(ele).closest("div.tab-content.active").find('span.rhsection-id').html();
        var elementClass = $(ele).find('text').html().replace(/[^\w\-]/g,'_');
        var allBoxid     = $(ele).closest("div.tab-content.active").find('div.all-box').attr("id");

        panel.updateCurrentCount(panel.el.find('div#'+rhsectionId+' span.current-count'));
        panel.showHideLink(panel.el.find('div#' + rhsectionId)); //need to be after updateCurrentCount
        
        $(ele).clone().append('<span class="hidden allBox-id">'+allBoxid+'</span>').prependTo(panel.el.find('div#'+rhsectionId+' ul')).removeClass("noremove").addClass(elementClass).find("span.fancy-checkbox").addClass("selected");
      }
      $(ele).find("span.fancy-checkbox").addClass("selected");
    }
    panel.trackError('div#cell, div#experiment, div#source');
    panel.enableFilterButton('div#cell, div#experiment, div#source');
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
      var tabId 		  = "div#" + panel.el.find(this).parent().attr("id") + "-tab";
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

  //function to show "show selected" or "Hide selected" link in right hand panel
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
            panel.selectBox(ele, 0, 1);
          }          
        }
        else { //unselecting all of them
          if($(ele).find("span.fancy-checkbox.selected").length){          
            panel.selectBox(ele, 0, 1);
          } 
        }        
      });
    });
  },
  
  trackTab: function() {
    var panel = this;
    
    //showing and applying cell types
    this.displayFilter(Object.keys(panel.json_data.cell_lines).sort(), "div#cell-type-content", "alphabetRibbon");

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
      content_html += '<div id="'+key+'-content" class="tab-content '+active_class+'"><span class="hidden rhsection-id">'+key+'</span></div>';
      count++;
    });
    experiment_html += '</div>';
    panel.el.find("div#experiment-type-content").append(experiment_html).append(content_html);
    
    //displaying the experiment types
    $.each(panel.json_data.evidence, function(key, ev){
      panel.displayFilter(ev.evidence_type, "div#"+key+"-content",ev.listType);
    })
    
    //selecting the tab in experiment type
    this.el.find("div.experiments div.track-tab").on("click", function () {
      panel.toggleTab(this, panel.el.find("div.experiments"));
    });    
    
  },
  
  // Function to toggle tabs and show the corresponding content which can be accessed by #id or .class
  // Arguments: selectElement is the tab that's clicked to be active or the tab that you want to be active (javascript object)
  //            container is the current active tab (javascript object)
		//            selByClass is either 1 or 0 - decide how the selection is made for the container to be active (container accessed by #id or .class)
		toggleTab: function(selectElement, container, selByClass) {
      var panel = this; 

      if(!$(selectElement).hasClass("active") ) {
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
  displayFilter: function(data, container, listType) {
    var panel       = this;
    var ribbonObj   = {};
    var countFilter  = 0;

    if(listType && listType === "alphabetRibbon") {
      //creating obj with alphabet key (a->[], b->[],...)
      $.each(data, function(j, item) {
        var firstChar = item.charAt(0).toLowerCase();
        if(!ribbonObj[firstChar]) {
          ribbonObj[firstChar] = [];
        } else {
          ribbonObj[firstChar].push(item);
        }
      });
      panel.alphabetRibbon(ribbonObj, container);
    } else  {
      var html = '<ul class="letter-content list-content">';
      $.each(data.sort(), function(i, item) {
        if(item) {
          var elementClass = item.replace(/[^\w\-]/g,'_');          
          html += '<li class="noremove '+elementClass+'"><span class="fancy-checkbox"></span><text>'+item+'</text></li>';
        }
        countFilter++;
      });
      html += '</ul>';
      html = '<div class="all-box list-all-box" id="allBox-'+$(container).attr("id")+'"><span class="fancy-checkbox"></span>Select all<text>('+countFilter+')</text></div>' + html; 
      panel.el.find(container).append(html);
      
      //updating available count in right hand panel
      var rhsection = panel.el.find(container).find('span.rhsection-id').html();
      panel.el.find('div#'+rhsection+' span.total').html(countFilter);

      //clicking select all checkbox
      panel.clickCheckbox(this.el.find(container+" div.all-box"));
      //selecting all filters
      panel.selectAll(this.el.find(container+" ul.letter-content"), this.el.find(container+" div.all-box"));
      
      //clicking checkbox for the filters
      panel.clickCheckbox(this.el.find(container+" ul.letter-content"), 0, 1, this.el.find(container+" div.all-box"));
    }
  },
  
  // Function to create letters ribbon with left and right arrow (< A B C ... >) and add elements alphabetically
  // Arguments: data: obj of the data to be added with obj key being the first letter pointing to array of elements ( a -> [], b->[], c->[])
  //            Container is where to insert the ribbon
  alphabetRibbon: function (data, container) {
    var panel = this;
    var html  = "";
    var content_html = "";
    var total_num = 0;
    
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
          var elementClass = el.replace(/[^\w\-]/g,'_');          
          letterHTML += '<li class="noremove '+elementClass+'"><span class="fancy-checkbox"></span><text>'+el+'</text></li>';
        });
        letterHTML += '</ul>';
      } else {
        active_class = "inactive";
      }
      
      html += '<div class="ribbon_'+letter+' alphabet-div '+active_class+'">'+letter.toUpperCase()+'<span class="hidden content-id">'+letter+'_content</span></div>';
      content_html += '<div class="'+letter+'_content alphabet-content '+active_class+'">'+letterHTML+'</div>';
    });
    panel.el.find(container).append('<div class="all-box" id="allBox-'+$(container).attr("id")+'"><span class="fancy-checkbox"></span>Select all<text>(A-Z)</text></div><div class="cell-listing"><div class="ribbon-banner"><div class="larrow inactive">&#x25C0;</div><div class="alpha-wrapper"><div class="letters-ribbon"></div></div><div class="rarrow">&#x25B6;</div></div><div class="ribbon-content"></div></div>');
    panel.el.find(container+' div.letters-ribbon').append(html);
    panel.el.find(container+' div.ribbon-content').append(content_html);

    //updating available count in right hand panel
    var rhsection = panel.el.find(container).find('span.rhsection-id').html();
    panel.el.find('div#'+rhsection+' span.total').html(total_num);

    //clicking checkbox for each filter
    panel.clickCheckbox(this.el.find(container+" ul.letter-content"), 0, 1, this.el.find(container+" div.all-box"));
    
    //clicking select all checkbox
    panel.clickCheckbox(this.el.find(container+" div.all-box"));
   
    //selecting all filters
    panel.selectAll(this.el.find(container+" div.ribbon-content"), this.el.find(container+" div.all-box"));
    
    //clicking the alphabet
    panel.elLk.alphabet = panel.el.find(container+' div.alphabet-div');      
    panel.elLk.alphabet.on("click", function(){
      $.when(
        panel.toggleTab(this, panel.el.find(container), 1)
      ).then(
        selectArrow()
      );
    });
    
    function selectArrow() {
      if(panel.el.find(container+' div.alphabet-div.active').html().match(/^A/)) { 
        panel.el.find(container+' div.larrow').removeClass("active").addClass("inactive");
        panel.el.find(+container+' div.rarrow').removeClass("inactive").addClass("active"); //just in case jumping from Z to A
      } else if(panel.el.find(container+' div.alphabet-div.active').html().match(/^Z/)) { 
        panel.el.find(container+' div.rarrow').removeClass("active").addClass("inactive");
        panel.el.find(container+' div.larrow').removeClass("inactive").addClass("active"); //just in case jumping from A to Z
      }else {
        panel.el.find(container+' div.larrow, div.rarrow').removeClass("inactive").addClass("active");
      }
    }
    
    //clicking the left and right arrow
    panel.elLk.arrows   = panel.el.find(container+' div.rarrow, div.larrow');
    
    panel.elLk.arrows.on("click", function(e){
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
