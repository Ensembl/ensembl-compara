// $Revision$

Ensembl.Panel.Masthead = Ensembl.Panel.extend({
  constructor: function (id) {
    var minWidth    = Ensembl.minWidthEl.width();
    var windowWidth = $(window).width();
    
    this.longTabs  = false;
    this.moreShown = false;
  
    this.base(id);
    
    Ensembl.EventManager.register('windowResize', this, this.resize);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    var tabs  = $('.tabs', this.el);
    var tools = $('.tools_holder', this.el);
    var logo  = $('.logo_holder', this.el);
    
    this.elLk.shortTabs  = $('li.short_tab', tabs);
    this.elLk.longTabs   = $('li.long_tab', tabs);
    this.elLk.toolsUl    = $('.tools', tools);
    this.elLk.tools      = $('li', this.elLk.toolsUl);
    this.elLk.toolMore   = $('.more', tools);
    this.elLk.toolMoreUl = $('<ul class="more_tools" />').appendTo(this.elLk.toolMore);
    
    this.elLk.toolMore.children('a').click(function () {
      panel.elLk.toolMoreUl.html(panel.elLk.toolsOverflow.clone()).toggle();
      panel.moreShown = true;
      return false;
    });
    
    this.toolsShown = this.elLk.tools.length;
    
    this.widths = {
      search: $('.search_holder', this.el).outerWidth(true),
      logo:   logo.outerWidth(true) + logo.offset().left,
      more:   this.elLk.toolMore.outerWidth(true)
    };
    
    this.setWidth('tools');
    
    this.elLk.longTabs.show();
    this.setWidth('longTabs');
    this.elLk.longTabs.hide();
    
    this.resize();
    
    tabs  = null;
    tools = null;
    logo  = null;
  },
  
  setWidth: function (type) {
    var panel = this;
    
    this.widths[type] = 0;
    this.widths[type + 'Array'] = [];
    
    this.elLk[type].each(function () {
      var w = $(this).outerWidth(true);
      panel.widths[type] += w;
      panel.widths[type + 'Array'].unshift(w);
    });
  },
  
  resize: function () {
    var panel = this;
    
    var minWidth    = Ensembl.minWidthEl.outerWidth();
    var windowWidth = $(window).width();
    var threshold   = windowWidth < minWidth ? minWidth : windowWidth;
    var longTabs    = this.widths.longTabs < threshold;
    var shortTools  = this.widths.tools > threshold - this.widths.search - this.widths.logo;
    var holderWidth, i, left;
    
    if (longTabs !== this.longTabs) {
      if (longTabs) {
        this.elLk.shortTabs.hide();
        this.elLk.longTabs.show();
      } else {
        this.elLk.shortTabs.show();
        this.elLk.longTabs.hide();
      }
      
      this.longTabs = longTabs;
    }
    
    if (shortTools) {
      holderWidth = threshold - this.widths.search - this.widths.logo - this.widths.more;
      i           = this.widths.toolsArray.length;
      left        = 0;
      
      while (i--) {
        if (left + this.widths.toolsArray[i] > holderWidth) {
          this.elLk.toolsOverflow = this.elLk.tools.filter(':gt(' + (this.widths.toolsArray.length - i - 2) + ')');
          break;
        }
        
        left += this.widths.toolsArray[i];
      }
      
      this.elLk.toolsUl.width(holderWidth);
      this.elLk.toolMore.css('left', left).show();
      
      if (this.moreShown) {
        this.elLk.toolMoreUl.html(this.elLk.toolsOverflow.clone());
      }
    } else {
      this.elLk.tools.show();
      this.elLk.toolMore.hide();
      this.elLk.toolsUl.width('auto');
    };
  }
});
