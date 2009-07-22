// $Revision$

Ensembl.PanelManager = new Base();

Ensembl.PanelManager.extend({
  constructor: null,
  
  /**
   * Inspects the HTML to find and create panels
   */
  initialize: function () {
    this.id = 'PanelManager';
    this.panels = {};
    this.nextId = 1;
    this.zIndex = 101;
    
    var myself = this;
    var panels = $('.js_panel');
    
    Ensembl.EventManager.register('createPanel', this, this.createPanel);
    Ensembl.EventManager.register('destroyPanel', this, this.destroyPanel);
    Ensembl.EventManager.register('addPanel', this, this.addPanel);
    Ensembl.EventManager.register('panelToFront', this, this.panelToFront);
    Ensembl.EventManager.register('resetZIndex', this, this.resetZIndex);
    Ensembl.EventManager.register('highlightImageMaps', this, this.highlightImageMaps);
    
    panels.each(function () {      
      myself.generateId(this);
      myself.createPanel(this.id, $('input.panel_type', this).val());
    });
    
    panels = null;
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
   * Returns all panels of the given type, in the order their divs appear on the page
   */
  getPanels: function (type) {
    var myself = this;
    var ids = [];
    var panels = [];
    
    for (var p in this.panels) {
      if (this.panels[p] instanceof Ensembl.Panel[type]) {
        ids.push('#' + this.panels[p].id);
      }
    }
    
    // This ensures we get the panel divs back in the order they appear on the page.
    $.each($(ids.join(',')), function () {
      panels.push(myself.panels[this.id]);
    });
    
    return panels;
  },
  
  /**
   * Adds a panel's html to the page, or triggers an event and brings the panel to the front if it already exists
   */
  addPanel: function (id, type, html, container, params, event) {
    if (this.panels[id]) {
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
      }
    }
  },
  
  /**
   * Creates the panels in the Ensembl object, adds to the panels registry and initializes it
   */
  createPanel: function (id, type, params) {    
    if (type) {
      this.panels[id] = new Ensembl.Panel[type](id, params);
    } else {
      this.panels[id] = new Ensembl.Panel(id, params);
    }
    
    this.panels[id].init();
  },
  
  /**
   * Cleans up and removes a panel from the registry
   */
  destroyPanel: function (id) {
    if (this.panels[id] !== undefined) {
      this.panels[id].destructor();
      delete this.panels[id];
      Ensembl.EventManager.remove(id);
    }
  },
  
  /**
   * Increases a panel's z-index so that it will be the top panel
   */
  panelToFront: function (id) {
    if (this.panels[id] !== undefined) {
      this.panels[id].el.style.zIndex = ++this.zIndex;
      
      if (this.zIndex > 1000000) {
        this.resetZIndex();
      }
    }
  },
  
  /**
   * Reset the zIndex variable, keeping the panel display the same
   */
  resetZIndex: function () {
    var p;
    var zInd = [];
    
    function sort(a, b) {
      return a.index - b.index;
    }
    
    this.zIndex = 101;
    
    for (p in this.panels) {
      zInd.push({ id: p, index: this.panels[p].el.style.zIndex });
    }
    
    for (p in zInd.sort(sort)) {
      this.panels[zInd[p].id].el.style.zIndex = ++this.zIndex;
    }
  },
  
  /**
   * Organise the drawing of the red boxs on location images
   */
  highlightImageMaps: function () {
    var panels = this.getPanels('ImageMap');
    var i = panels.length;
    var link = true;
    var panel, linkedPanel, region, start, end;
    
    while (i--) {
      linkedPanel = panels[i+1];
      
      if (linkedPanel && linkedPanel.region) {
        region = linkedPanel.region.a.href.split('|');
        start = parseInt(region[5]);
        end = parseInt(region[6]);
      } else {
        // Highlight from the page's region parameter
        start = Ensembl.location.start;
        end = Ensembl.location.end;
        link = false;
      }
      
      Ensembl.EventManager.triggerSpecific('highlightImage', panels[i].id, start, end, link);
    }
  }
});
