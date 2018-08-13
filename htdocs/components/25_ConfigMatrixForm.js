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

    this.elLk.browseTrack  = this.el.find("div#browse-track");
    this.elLk.buttonTab    = this.el.find("div.track-tab");
    this.elLk.contentTab   = this.el.find("div.tab-content");
    this.elLk.trackList    = this.el.find("ul.result-list");
    this.elLk.filterButton = this.el.find("button.filter");
    
    this.buttonOriginalWidth = this.elLk.filterButton.outerWidth();
    this.buttonOriginalHTML  = this.elLk.filterButton.html();

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
      
      // if button is Edit and then browse track tab or search track tab is clicked then change it to Apply Filters
      // if button is Apply filters and it is active and then track configuration tab is shown then change it to Edit
      if(selectTab === 'search-tab' || selectTab === 'browse-tab')
      {
        if(panel.elLk.filterButton.hasClass("_edit")) {
          panel.elLk.filterButton.removeClass("_edit").outerWidth(panel.buttonOriginalWidth).html(panel.buttonOriginalHTML);
        }s
      } else if (selectTab === 'config-tab' && !panel.elLk.filterButton.hasClass("_edit") && panel.elLk.filterButton.hasClass("active")) {
        panel.elLk.filterButton.addClass("_edit").outerWidth("70px").html("Edit");
      }
    });
    
    panel.clickCheckbox(this.elLk.trackList, 1);
    panel.clickFilter(panel.elLk.filterButton, panel.el.find("div#track-config"));
  },
  
  // Function to check divs that needs to have content to enable or disable apply filter button
  // Argument: ID of div to check for content
  enableFilterButton: function (content) {
    var panel = this;
    
    if(panel.el.find(content).find('li').length) {
      panel.el.find('button.filter').addClass('active');
    } else {
      panel.el.find('button.filter').removeClass('active');
    }
  },
  
  // Function to select/unselect checkbox and removing them from the right hand panel (optional) and adding them to the right hand panel (optional)
  clickCheckbox: function (container, removeElement, addElement) {
    var panel = this;

    var itemListen = "li";
    if(container[0].nodeName === 'DIV') {
      itemListen = "";
    }

    //clicking checkbox
    $(container).on("click", itemListen, function(e) {
      console.log(itemListen);
       if($(this).find("span.fancy-checkbox.selected").length){
        $(this).find("span.fancy-checkbox").removeClass("selected");
        
        //removing element from right hand panel (selection panel) - optional
        if(removeElement && !this.className.match("noremove")){
          //unselecting from left hand panel when unselecting/removing in right hand panel
          var lhsectionId = $(this).closest("ul.result-list").find("span.lhsection-id").html();
          panel.el.find('div#'+lhsectionId+' li.'+$(this).attr('class')+' span.fancy-checkbox').removeClass("selected");;
          this.remove();
        }
        //removing from right hand panel when unselecting in left hand panel
        if(addElement) {          
          var rhsectionId = $(this).closest("div.tab-content.active").find('span.rhsection-id').html();
          var elementClass = $(this).find('text').html().replace(/[^\w\-]/g,'_');
          panel.el.find('div#'+rhsectionId+' ul li.'+elementClass).remove();
        }
      } else {
        if(addElement) {
          var rhsectionId = $(this).closest("div.tab-content.active").find('span.rhsection-id').html();
          var elementClass = $(this).find('text').html().replace(/[^\w\-]/g,'_');
          $(this).clone().prependTo(panel.el.find('div#'+rhsectionId+' ul')).removeClass("noremove").addClass(elementClass).find("span.fancy-checkbox").addClass("selected");
        }
        $(this).find("span.fancy-checkbox").addClass("selected");
      }
      panel.enableFilterButton('div#cell, div#experiment, div#source');
      e.stopPropagation();
    });  
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
  
  trackTab: function() {
    var panel = this;
    
    this.elLk.browseTrack.append('<div class="tabs cells"><div class="cell-label">Track filters</div><div class="track-tab active">Cell type<span class="content-id">cell-type-content</span></div><div class="track-tab">Experiment type<span class="content-id">experiment-type-content</span></div><div class="track-tab">Source<span class="content-id">source-content</span></div></div><div id="cell-type-content" class="tab-content active"><span class="rhsection-id">cell</span></div><div id="experiment-type-content" class="tab-content"><span class="rhsection-id">experiment</span></div><div id="source-content" class="tab-content">Source contents....<span class="rhsection-id">source</span></div>');

    //selecting the tab in track filters
    this.elLk.cellTab = this.el.find("div.cells div.track-tab");
    this.elLk.cellTab.on("click", function () { 
      panel.toggleTab(this, panel.el.find("div.cells"));
    });
    
    //showing and applying cell types
    this.displayTrack(Object.keys(panel.json_data.cell_lines).sort(), "div#cell-type-content", "alphabetRibbon");

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
      experiment_html += '<div class="track-tab '+active_class+'">'+item.name+'<span class="content-id">'+key+'-content</span></div>';     
      content_html += '<div id="'+key+'-content" class="tab-content '+active_class+'"><span class="rhsection-id">experiment</span></div>';
      count++;
    });
    experiment_html += '</div>';
    panel.el.find("div#experiment-type-content").append(experiment_html).append(content_html);
    
    //displaying the experiment types
    $.each(panel.json_data.evidence, function(key, ev){
      panel.displayTrack(ev.evidence_type, "div#"+key+"-content",ev.listType);
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
      if(selByClass) {
        container.find("div."+spanID).addClass("active");
      } else {      
        panel.el.find("#"+spanID).addClass("active");
      }
    } 
  },
  
  //function to display tracks (checkbox label), it can either be inside a letter ribbon or just list
  displayTrack: function(data, container, listType) {
    var panel       = this;
    var ribbonObj   = {};
    var countTrack  = 1;

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
        countTrack++;
      });
      html += '</ul>';
      html = '<div class="all-box list-all-box"><span class="fancy-checkbox"></span>Select all<text>('+countTrack+')</text></div>' + html; 
      panel.el.find(container).append(html);
      
      //clicking select all checkbox
      panel.clickCheckbox(this.el.find(container+" div.all-box"));
      
      //clicking checkbox
      panel.clickCheckbox(this.el.find(container+" ul.letter-content"), 0, 1);
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
    $.each([...Array(26).keys()], function(i) {
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
      
      html += '<div class="ribbon_'+letter+' alphabet-div '+active_class+'">'+letter.toUpperCase()+'<span class="content-id">'+letter+'_content</span></div>';
      content_html += '<div class="'+letter+'_content alphabet-content '+active_class+'">'+letterHTML+'</div>';
    });
    panel.el.find(container).append('<div class="cell-listing"><div class="larrow inactive">&#x25C0;</div><div class="letters-ribbon"></div><div class="rarrow">&#x25B6;</div><div class="ribbon-content"></div><div class="all-box"><span class="fancy-checkbox"></span>Select all<text>('+total_num+')</text></div></div>');    
    panel.el.find(container+' div.letters-ribbon').append(html);
    panel.el.find(container+' div.ribbon-content').append(content_html);

    //clicking checkbox
    panel.clickCheckbox(this.el.find(container+" ul.letter-content"), 0, 1);
    
    //clicking select all checkbox
    panel.clickCheckbox(this.el.find(container+" div.all-box"));
    
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
    
    panel.elLk.arrows.on("click", function(){
      if(!this.className.match(/inactive/gi)) {
        panel.elLk.activeAlphabet = panel.el.find(container+' div.alphabet-div.active');
        if(this.className.match(/larrow/gi)) {
          //get currently selected letter, convert it to utf-16 number add 1 to get next letter number and then convert it to char
          var prevLetter = String.fromCharCode(panel.elLk.activeAlphabet.html().charAt(0).toLowerCase().charCodeAt(0)-1);
          $.when(
            panel.toggleTab(container+" div.ribbon_"+prevLetter, panel.el.find(container), 1)
          ).then(
            selectArrow()
          );           
        } 
        if (this.className.match(/rarrow/gi)) {
          //get currently selected letter, convert it to utf-16 number add 1 to get next letter number and then convert it to char
          var nextLetter = String.fromCharCode(panel.elLk.activeAlphabet.html().charAt(0).toLowerCase().charCodeAt(0)+1);
          $.when(
            panel.toggleTab(container+" div.ribbon_"+nextLetter, panel.el.find(container), 1)
          ).then(
            selectArrow()
          );            
        }
      }
      
    });    
  }
});
