// $Revision$

Ensembl.Panel.ZMenu = Ensembl.Panel.extend({
  constructor: function (id, data) {
    this.base(id);
    
    var area = $(data.area.a);
    
    this.drag = area.hasClass('drag') ? 'drag' : area.hasClass('vdrag') ? 'vdrag' : false;
    this.das  = area.hasClass('das') && area.hasClass('group') ? 'group' : area.hasClass('das') ? 'feature' : false;
    this.href = area.attr('href');
    this.title = area.attr('title');
    
    if (this.das !== false) {
      this.logicName = area.attr('class').replace(/das/, '').replace(/group/, '').replace(/ /g, '');
    }
    
    area = null;
    
    this.position = data.position;
    this.coords = data.coords;
    this.areaCoords = $.extend({}, data.area);
    this.location = 0;
    
    delete this.areaCoords.a;
    
    Ensembl.EventManager.register('showExistingZMenu', this, this.showExisting);
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.elLk.caption = $('span.title', this.el);
    this.elLk.tbody = $('tbody', this.el);
    
    $(this.el).mousedown(function () {
      Ensembl.EventManager.trigger('panelToFront', myself.id);
    });
    
    $('.close', this.el).click(function () { 
      myself.hide();
    });
    
    this.baseURL = window.location.href.replace(/&/g, ';').replace(/#.*$/g, '').replace(/\?r=[^;]+;?/g, '?').replace(/;r=[^;]+;?/g, ';').replace(/[\?;]$/g, '');
    this.baseURL += this.baseURL.match(/\?/) ? ';' : '?';
    
    this.getContent();
  },
  
  getContent: function () {
    if (this.drag == 'drag') {
      this.populateRegion();
    } else if (this.drag == 'vdrag') {
      this.populateVRegion();
    } else if (this.das !== false && Ensembl.ajax == 'enabled') {
      this.populateDas();
    } else if (!this.href) {
      this.populate();
    } else if (this.href.match(/#/)) {
      this.populate(true);
    } else if (Ensembl.ajax == 'enabled') {
      this.populateAjax();
    } else {
      this.populateNoAjax();
    }
  },
  
  populate: function (link, extra) {
    var arr = this.title.split(';');
    var caption = arr.shift();
    
    this.buildMenu(arr, caption, link, extra);
  },
  
  populateDas: function () {
    var strandMap = { '+': 1, '-': -1 };
    
    var start  = this.title.match(/Start: (\d+)/)[1];
    var end    = this.title.match(/End: (\d+)/)[1];
    var strand = this.title.match(/Strand: ([-+])/)[1];
    
    var url = window.location.pathname.replace(/\/(\w+)\/\w+$/, '/Zmenu/$1/Das') +
      '?logic_name=' + this.logicName +
      ';' + this.das + '_id=' + this.title.split(';')[0] +
      ';start=' + start + 
      ';end=' + end + 
      ';strand=' + strandMap[strand] + 
      ';click_start=' + this.coords.clickStart + 
      ';click_end=' + this.coords.clickEnd;
      
    for (var p in Ensembl.coreParams) {
      if (Ensembl.coreParams[p]) {
        url += ';' + p + '=' + Ensembl.coreParams[p];
      }
    }
    
    this.populateAjax(url);
  },
  
  populateAjax: function (url) {
    var myself = this;
    
    url = url || this.href.replace(/\/(\w+\/\w+)\?/, '/Zmenu/$1?');
    
    if (url) {
      $.ajax({
        url: url,
        dataType: 'json',
        success: function (json) {
          if (json.entries.length) {
            var body = '';
            var row;
            
            for (var i in json.entries) {
              if (json.entries[i].type == 'subheader') {
                row = '<th class="subheader" colspan="2">' + json.entries[i].link + '</th>';
              } else if (json.entries[i].type) {
                row = '<th>' + json.entries[i].type + '</th><td>' + json.entries[i].link + '</td>';
              } else {
                row = '<td colspan="2">' + json.entries[i].link + '</td>';
              }
              
              body += '<tr>' + row + '</tr>';
            }
            
            myself.elLk.tbody.html(body);
            myself.elLk.caption.html(json.caption);
            
            myself.show();
          } else {
            myself.populateNoAjax();
          }
        },
        error: function () {
          myself.populateNoAjax();
        }
      });
    } else {
      this.populateNoAjax();
    }
  },
  
  populateNoAjax: function () {
    var extra = '';
    var loc = this.title.match(/Location: (\S+)/);
    
    if (loc) {          
      var r = loc[1].split(/\W/);
      this.location = parseInt(r[1]) + (r[2] - r[1]) / 2;
      
      extra += '<tr><th></th><td><a href="' + this.zoomURL(1) + '">Centre on feature</a></td></tr>';
      extra += '<tr><th></th><td><a href="' + this.baseURL + 'r=' + loc[1] + '">Zoom to feature</a></td></tr>';
    }
    
    this.populate(true, extra);
  },
  
  populateRegion: function () {
    var myself = this;
    
    var start, end, tmp, url, href;
    var arr, caption;
    
    var a = this.href.split('|');
    var min = parseInt(a[5]);
    var max = parseInt(a[6]);
    
    var scale = (max - min + 1) / (this.areaCoords.r - this.areaCoords.l);
    
    // Region select
    if (this.coords.r) {
      start = Math.floor(min + (this.coords.s - this.areaCoords.l) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.l) * scale);
      
      if (start > end) {
        tmp = start;
        start = end;
        end = tmp;
      }
      
      if (start < min) {
        start = min;
      }
      
      if (end > max) {
        end = max;
      }
      
      this.location = (start + end) / 2;
      
      url = this.baseURL + 'r=' + a[4] + ':' + start + '-' + end;
      
      arr = [
        '<a href="' + url + '">Jump to region (' + (end - start) + ' bp)</a>',
        '<a href="' + this.zoomURL(1) + '">Centre here</a>'
      ];
      
      caption = 'Region: ' + start + '-' + end;
    } else {
      this.location = Math.floor(min + (this.coords.x - this.areaCoords.l) * scale);
      
      arr = [
        '<a href="' + this.zoomURL(10)  + '">Zoom out x10</a>',
        '<a href="' + this.zoomURL(5)   + '">Zoom out x5</a>',
        '<a href="' + this.zoomURL(2)   + '">Zoom out x2</a>',
        '<a href="' + this.zoomURL(1)   + '">Centre here</a>'
      ];
      
      // Only add zoom in links if there is space to zoom in to.
      $.each([2, 5, 10], function () {
        href = myself.zoomURL(1 / this);
        
        if (href !== '') {
          arr.push('<a href="' + href + '">Zoom in x' + this + '</a>');
        }
      });
      
      caption = 'Location: ' + this.location;
    }
    
    this.buildMenu(arr, caption);
  },
  
  populateVRegion: function () {
    var start, end, view, arr, caption, tmp, url;
    
    var a = this.href.split('|');
    var min = parseInt(a[5]);
    var max = parseInt(a[6]);
    
    var scale = (max - min + 1) / (this.areaCoords.b - this.areaCoords.t);
    
    // Region select
    if (this.coords.r) {
      view = 'Overview';
      
      start = Math.floor(min + (this.coords.s - this.areaCoords.t) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.t) * scale);
      
      if (start > end) {
        tmp = start;
        start = end;
        end = tmp;
      }
      
      if (start < min) {
        start = min;
      }
      
      if (end > max) {
        end = max;
      }
      
      this.location = (start + end) / 2;
      
      caption = a[4] + ': ' + start + '-' + end;
    } else {
      view = 'View';
      
      this.location = Math.floor(min + (this.coords.y - this.areaCoords.t) * scale);
      
      start = this.location - (Ensembl.location.width / 2);
      end   = this.location + (Ensembl.location.width / 2);
      
      if (start < 1) {
        start = 1;
      }
      
      caption = a[4] + ': ' + this.location;
    }
    
    url = this.baseURL + 'r=' + a[4] + ':' + start + '-' + end;
    
    arr = [
      '<a href="/' + a[3] + '/Location/' + view + url + '">Jump to location ' + view + '</a>',
      '<a href="/' + a[3] + '/Location/Chromosome' + url + '">Chromosome summary</a>'
    ];
    
    this.buildMenu(arr, caption);
  },
  
  buildMenu: function (content, caption, link, extra) {
    var body = '';
    var arr, title;
    
    caption = caption || 'Menu';
    extra = extra || '';
    
    if (link === true && this.href) {
      title = this.title ? this.title.split(';')[0] : caption;
      extra = '<tr><th>Link</th><td><a href="' + this.href + '">' + title + '</a></td></tr>' + extra;
    }
    
    $.each(content, function () {
      arr = this.split(': ');
      body += '<tr>' + (arr.length == 2 ? '<th>' + arr[0] + '</th><td>' + arr[1] + '</td>' : '<td colspan="2">' + this + '</td>') + '</tr>';
    });
    
    this.elLk.tbody.html(body + extra);
    this.elLk.caption.html(caption);
    
    this.show();
  },
  
  zoomURL: function (scale) {    
    var w = Ensembl.location.width * scale;
    
    return w < 1 ? '' : this.baseURL + 'r=' + Ensembl.location.name + ':' + Math.round(this.location - (w - 1) / 2) + '-' + Math.round(this.location + (w - 1) / 2);
  },
  
  show: function () {
    var menuWidth = parseInt(this.width());
    var windowWidth = $(window).width() - 10;
    
    var css = {
      left: this.position.left, 
      top: this.position.top,
      position: 'absolute'
    };
    
    if (this.position.left + menuWidth > windowWidth) {
      css.left = windowWidth - menuWidth;
    }
    
    Ensembl.EventManager.trigger('panelToFront', this.id);
    
    $(this.el).css(css);
    
    this.base();
  },

  showExisting: function (data) {
    this.position = data.position;
    this.coords = data.coords;
    
    if (this.das == 'group' || this.drag) {
      this.elLk.tbody.empty();
      this.elLk.caption.empty();
      
      this.getContent();
    } else {
      this.show();
    };
  }
});
