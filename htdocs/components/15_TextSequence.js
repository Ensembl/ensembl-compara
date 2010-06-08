// $Revision$

Ensembl.Panel.TextSequence = Ensembl.Panel.Content.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('dataTableRedraw', this, this.initPopups);
  },
  
  init: function () {
    var panel = this;
    
    this.popups = {};
    
    this.base();
    this.initPopups();
    
    this.elLk.popup = $([
      '<div class="info_popup floating_popup">',
      ' <img class="close" src="/i/close.png" />',
      ' <table cellspacing="0"></table>',
      '</div>'
    ].join(''));
    
    $('.info_popup', this.el).live('mousedown', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
    });
    
    $('.info_popup .close', this.el).live('click', function () {
      $(this).parent().hide();
    });
    
    $('pre a.sequence_info', this.el).live('click', function (e) {
        var el    = $(this);
        var data  = el.data();
        var popup = data.link.data('popup');
        var position, maxLeft, scrollLeft;
        
        if (!data.position) {
          data.position  = el.position();
          data.position.top  += 0.75 * el.height();
          data.position.left += 0.25 * el.width();
          
          el.data('position', data.position);
        }
        
        if (popup) {
          position   = $.extend({}, data.position); // modifying data.position changes the stored value too, so make a fresh copy
          maxLeft    = $(window).width() - popup.width() - 20;
          scrollLeft = $(window).scrollLeft();
          
          if (position.left > maxLeft + scrollLeft) {
            position.left = maxLeft + scrollLeft;
          }
        
          popup.show().css(position);
        } else if (!data.processing) {
          el.data('processing', true);
          panel.getPopup(el);
        }
        
        el    = null;
        popup = null;
        
        return false;
    });
  },
  
  initPopups: function () {
    var panel = this;
    
    $('.info_popup', this.el).hide();
    
    $('pre a.sequence_info', this.el).each(function () {
      if (!panel.popups[this.href]) {
        panel.popups[this.href] = $(this);
      }
      
      $(this).data('link', panel.popups[this.href]); // Store a single reference <a> for all identical hrefs - don't duplicate the popups
      $(this).data('position', null);                // Clear the position data
    }).css('cursor', 'pointer');
  },
  
  getPopup: function (el) {
    var data = el.data();
    var popup = this.elLk.popup.clone().appendTo(this.el).draggable({ handle: 'tr:first' }).css(data.position);
    
    function toggle(e) {
      if (e.target.nodeName != 'A') {
        var tr = $(this).parent();
        
        tr.siblings('.' + tr.attr('className')).toggle();
        $(this).toggleClass('closed opened');
        
        tr = null;
      }
    }
    
    $.ajax({
      url: el.attr('href'),
      dataType: 'json',
      context: this,
      success: function (json) {
        if (json.length) {
          var classes = {};
          var i, j, tbody, feature, caption, entry, childOf, cls, css, tag, row, maxLeft, scrollLeft;
          
          for (i = 0; i < json.length; i++) {
            tbody = $('<tbody>').appendTo(popup.children('table'));
            feature = json[i];
             
            for (j = 0; j < feature.length; j++) {
              caption = feature[j].caption || null;
              entry   = feature[j].entry   || [];
              childOf = feature[j].childOf || '';
              cls     = (feature[j].cls    || childOf).replace(/\W/g, '_');
              css     = childOf ? { paddingLeft: '12px' } : {};
              tag     = 'td';
              
              if (typeof entry == 'string') {
                entry = [ entry ];
              }
              
              caption = caption || entry.shift();
              
              if (cls) {
                classes[cls] = 1;
              }
              
              if (caption && entry.length) {
                caption += ':';
              }
              
              if (j === 0) {
                tag = 'th';
                cls = 'header';
              }
              
              row = $('<tr>', { 'class': cls }).appendTo(tbody);
             
              if (caption !== null && entry.length) {
                row.append($('<' + tag + '>', { html: caption, css: css })).append($('<' + tag + '>', { html: entry.join(' ') }));
              } else {
                row.append($('<' + tag + '>', { html: (caption || entry.join(' ')), colspan: 2 }));
              }
            }
            
            tbody.append('<tr style="display:block;padding-bottom:3px;">'); // Add padding to the bottom of the tbody
          }
          
          $('tbody', popup).each(function () {
            var rows = $('tr', this);
            var trs;
            
            for (var c in classes) {
              trs = rows.filter('.' + c);
              
              if (trs.length > 2) {
                $(':first', trs[0]).addClass('closed').click(toggle);
                trs.not(':first').hide();
              }
            }
            
            trs  = null;
            rows = null;
          });
          
          popup.css('zIndex', ++Ensembl.PanelManager.zIndex).show();
          
          maxLeft    = $(window).width() - popup.width() - 20;
          scrollLeft = $(window).scrollLeft();
          
          if (data.position.left > maxLeft + scrollLeft) {
            popup.css('left', maxLeft + scrollLeft);
          }
          
          data.link.data('popup', popup); // Store the popup on the reference <a>
        }
      },
      complete: function () {
        el.data('processing', false);
        popup = null;
      }
    });
  }
});
