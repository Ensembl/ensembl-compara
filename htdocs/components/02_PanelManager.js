/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.PanelManager = new Base();

Ensembl.PanelManager.extend({
  constructor: null,
  
  /**
   * Inspects the HTML to find and create panels
   */
  initialize: function () {
    this.id          = 'PanelManager';
    this.panels      = {};
    this.nextId      = 1;
    this.panelNumber = 0;
    this.zIndex      = 101;
    
    function ajaxLoaded() {
      if (!$('.ajax_load').length) {
        Ensembl.EventManager.trigger('ajaxComplete');
      }
    }

    Ensembl.EventManager.register('createPanel',  this, this.createPanel);
    Ensembl.EventManager.register('destroyPanel', this, this.destroyPanel);
    Ensembl.EventManager.register('addPanel',     this, this.addPanel);
    Ensembl.EventManager.register('panelToFront', this, this.panelToFront);
    Ensembl.EventManager.register('ajaxLoaded',   this, ajaxLoaded); 
    
    this.init($('.js_panel'));
    
    ajaxLoaded();
  },
  
  init: function (panels) {
    panels.each(function () {
      var panelType   = $('input.panel_type', this).val();
      var parentPanel = {};
      
      Ensembl.PanelManager.generateId(this);
      
      $(this).parents('.js_panel').each(function () {
        parentPanel[Ensembl.PanelManager.panels[this.id].panelType] = 1;
      });
      
      if (!parentPanel[panelType]) {
        Ensembl.PanelManager.createPanel(this.id, panelType);
      }
    });
  },
  
  /**
   * Set an id on panels which don't have them
   */
  generateId: function (panel) {
    if (!panel.className.match(/js_panel/)) {
      panel = $('.js_panel', panel)[0];
    }
    
    if (!panel) {
      return;
    }
    
    if (!panel.id) {
      panel.id = 'ensembl_panel_' + this.nextId++;
    }
    
    return panel.id;
  },
  
  /**
   * Returns all panels of the given type (or all panels if no type is specified), in the order their divs appear on the page
   */
  getPanels: function (type) {
    var ids    = [];
    var panels = [];
    
    for (var p in this.panels) {
      if (!type || this.panels[p] instanceof Ensembl.Panel[type]) {
        ids.push('#' + this.panels[p].id);
      }
    }
    
    // This ensures we get the panel divs back in the order they appear on the page.
    $.each($(ids.join(',')), function () {
      panels.push(Ensembl.PanelManager.panels[this.id]);
    });
    
    return panels;
  },
  
  /**
   * Adds a panel's html to the page, or triggers an event and brings the panel to the front if it already exists
   */
  addPanel: function (id, type, html, container, params, event) {
    if (this.panels[id] && event) {
      Ensembl.EventManager.triggerSpecific(event, id, params);
      this.panelToFront(id);
    } else {
      params = params || {};
      
      if (container && html) {
        container.html(html);
        
        id = id || this.generateId(container[0]);
      }
      
      if (id) {
        this.createPanel(id, type, params);
        this.init($('.js_panel', this.panels[id].el));
      }
    }
  },
  
  /**
   * Creates the panels in the Ensembl object, adds to the panels registry and initializes it
   */
  createPanel: function (id, type, params) {
    if (this.panels[id]) {
      this.destroyPanel(id, 'cleanup');
    }
    
    if (type) {
      this.panels[id] = new Ensembl.Panel[type](id, params);
    } else {
      this.panels[id] = new Ensembl.Panel(id, params);
    }
    
    this.panels[id].panelNumber = this.panelNumber++;
    this.panels[id].panelType   = type;
    this.panels[id].init();
  },
  
  /**
   * Cleans up and removes a panel from the registry
   */
  destroyPanel: function (id, action) {
    if (this.panels[id] !== undefined) {
      this.panels[id].destructor(action);
      delete this.panels[id];
      Ensembl.EventManager.remove(id);
    }
  },
  
  /**
   * Increases a panel's z-index so that it will be the top panel
   */
  panelToFront: function (id) {
    if (this.panels[id] !== undefined) {
      this.panels[id].el.css('zIndex', ++this.zIndex);
      
      if (this.zIndex > 1000000) {
        this.resetZIndex();
      }
    }
  },
  
  /**
   * Reset the zIndex variable, keeping the panel display the same
   */
  resetZIndex: function () {
    var zInd = [];
    var p;
    
    function sort(a, b) {
      return a.index - b.index;
    }
    
    this.zIndex = 101;
    
    for (p in this.panels) {
      zInd.push({ id: p, index: this.panels[p].el.css('zIndex') });
    }
    
    for (p in zInd.sort(sort)) {
      this.panels[zInd[p].id].el.css('zIndex', ++this.zIndex);
    }
  }
});
