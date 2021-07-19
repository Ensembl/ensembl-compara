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

Ensembl.Panel.ZMenu = Ensembl.Panel.extend({
  constructor: function (id, data) {
    this.base(id);
    this.data = data;
    var area  = data.area.a;
    var params, n;

    if (data.area.link) {
      area = { klass:{}, attrs: { href: data.area.link.attr('href'), title: data.area.link.attr('title') } };
    }
    
    this.drag       = area.klass.drag ? 'drag' : area.klass.vdrag ? 'vdrag' : false;
    this.align      = area.klass.align; // TODO: implement alignslice menus
    this.group      = area.klass.group || area.klass.pseudogroup;
    this.coloured   = area.klass.coloured;
    this.href       = area.attrs.href;
    this.title      = area.attrs.title || '';
    this.das        = false;
    this.event      = data.event;
    this.coords     = data.coords || {};
    this.imageId    = data.imageId;
    this.onclose    = data.onclose; // to be triggered when the zmenu is closed
    this.context    = data.context; // context to call the 'onclose' on (defaults to the zmenu panel itself)
    this.relatedEl  = data.relatedEl;
    this.areaCoords = $.extend({}, data.area);
    this.location   = 0;
    
    if (area.klass.das) {
      this.das       = area.klass.group ? 'group' : area.klass.pseudogroup ? 'pseudogroup' : 'feature';
      this.logicName = '';
      $.each(area.attrs,function(k,v) {
        if(k != 'das' && k != 'pseudogroup' && k != 'group') {
          this.logicName += k;
        }
      });
    }
    
    if (this.drag) {
      params = this.href.split('|');
      n                = parseInt(params[1], 10) - 1;
      this.speciesPath = params[3].replace(/-/, '/');
      this.species     = this.speciesPath.split('/').pop();
      this.chr         = params[4];
      this.start       = parseInt(params[5], 10);
      this.end         = parseInt(params[6], 10);
      this.strand      = parseInt(params[7], 10);
      this.multi       = area.klass.multi ? n : false;
      if (!this.speciesPath.match(/^\//)) {
        this.speciesPath = '/' + this.speciesPath;
      }
    }

    area = null;
    
    delete this.areaCoords.a;
    
    Ensembl.EventManager.register('showExistingZMenu', this, this.showExisting);
  },
  
  init: function () {
    var panel = this;
    var r     = new RegExp('([\\?;]r' + (this.multi || '') + '=)[^;]+;?', 'g'); // The r parameter to remove from the current URL for this.baseURL
    
    this.base();
    
    this.elLk.container = $('.container', this.el);
    this.elLk.loading   = $('.loading',   this.el);

    // To open motif feature widget on regulation track
    this.el.on("click", 'a._motif', function(e) {
      e.preventDefault();
      Ensembl.openMotifWidget($(this).html());
    });
    
    this.el.on('mousedown', function () {
      Ensembl.EventManager.trigger('panelToFront', panel.id);
    }).on('click', 'a._location_change', function (e) {

      if (!window.location.pathname.match(/\/Location\/View(\/|$)/)) {
        return true;
      }

      var locationMatch = this.href.match(Ensembl.locationMatch);
      
      if (locationMatch) {
        e.preventDefault()

        if (locationMatch[1] !== Ensembl.coreParams.r) {
          Ensembl.updateLocation(locationMatch[1]);
        }
        
        panel.hide();
      }
    }).on('click', 'a._location_mark', function (e) {

      e.preventDefault();

      Ensembl.markLocation(this.href);

      panel.hide();
    });
    
    $('.close', this.el).on('click', function () { 
      panel.hide();
      if (panel.onclose) {
        panel.onclose.call(panel.context || panel);
      }
    });
    
    // The location parameter that is due to be changed has its value replaced with %s
    this.baseURL = window.location.href.replace(/&/g, ';').replace(/#.*$/g, '').replace(r, '$1%s;').replace(/[\?;]$/g, '');

    // Add r parameter if it doesn't exist already
    if (!this.baseURL.match(/%s/)) {
      this.baseURL += (this.baseURL.match(/\?/) ? ';' : '?') + 'r=%s';
    }
    
    if (this.multi) {
      // Remove align parameter when changing species
      this.baseURL = this.baseURL.replace(/align=\d+;?/, '').replace(/;$/, '') + ';action=primary;id=' + this.multi;
    }
    
    // Clear secondary regions so all species will be realigned - any change in primary species location should result in a new alignment
    if (this.multi === false) {
      this.baseURL = this.baseURL.replace(/r\d+=[^;]+;?/g, '');
    }
    
    if (this.coloured) {
      this.el.addClass('coloured');
    }
    
    this.el.on('click', 'a.expand', function () {
      panel.populateAjax(this.href, $(this).parents('tr'));
      return false;
    });
    
    this.getContent();

    // Refresh zmenu on click for timeouts
    $('.refresh-zmenu', this.el).on('click', function() {
      $(this).closest('tbody').hide();
      panel.elLk.loading.show();
      panel.populateAjax(panel.href, $(this).parents('tbody'), 1);
      return false;
    })
  },
  
  getContent: function () {
    var panel = this;
    
    this.populated = false;
    
    clearTimeout(this.timeout);
    
    this.timeout = setTimeout(function () {
      if (panel.populated === false) {
        panel.elLk.container.hide();
        panel.elLk.loading.show();
        panel.show(panel.das);
      }
    }, 300);
  
    if (this.data.mr_menu) {
      this.showMarkRegionMenu();
    }else if (this.drag === 'drag') {
      this.populateRegion();
    } else if (this.drag === 'vdrag') {
      this.populateVRegion();
    } else if (this.das !== false) {
      this.populateDas();
    } else if (!this.href) {
      this.populate();
    } else if (this.href.match(/#/) && !this.href.match(/#:@:/)) {
      this.populate(true);
    } else {
      this.populateAjax();
    }
  },
  
  showMarkRegionMenu: function () {
    var panel = this;
    var menu = [];

    if (Ensembl.markedLocation) {
      var a = '<a class="loc-icon-a _mr_jump_location"> <span class="loc-icon loc-change"></span>Jump to marked location</a>';
      var b = '<a class="loc-icon-a _mr_remove" style="cursor:pointer;"> <span class="loc-icon remove"></span>Remove marking</a>';
      menu.push(a,b);
    }
    this.buildMenu(menu, 'Marked Region');
    this.elLk.container.find('._mr_jump_location').off().on('click', function(e) { Ensembl.updateLocation(Ensembl.markedLocation[0]); panel.hide(); }).css({'cursor':'pointer'});
    this.elLk.container.find('._mr_remove').off().on('click', function(e) { Ensembl.markLocation(false); panel.hide(); });
  },

  populate: function (link, extra, error) {
    var menu    = this.title.toString().split('; ');
    var caption = menu.shift();
    
    this.buildMenu(menu, caption, link, extra, true, error);
  },
  
  populateDas: function () {
    var strandMap = { '+': 1, '-': -1 };
    var start     = this.title.match(/Start: (\d+)/)[1];
    var end       = this.title.match(/End: (\d+)/)[1];
    var strand    = (this.title.match(/Strand: ([-+])/) || [])[1];
    var id        = this.title.match(/; Id: ([^;]+)$/)[1];
    var url       = [
      window.location.pathname.replace(/\/(\w+)\/\w+$/, '/ZMenu/$1/Das'),
      '?logic_name=', this.logicName,
      ';', this.das, '_id=', id,
      ';start=', start, 
      ';end=', end,
      ';strand=', strandMap[strand],
      ';label=', this.title.split('; ')[0]
    ].join('');
      
    for (var p in Ensembl.coreParams) {
      if (Ensembl.coreParams[p]) {
        url += ';' + p + '=' + Ensembl.coreParams[p];
      }
    }
    
    this.populateNoAjax(true); // Always parse the title tag
    this.populateAjax(url);
  },

  // the server spends way too long creating URLs which will never be
  // clicked on. Pass through as quickly as possible and leave to client
  // side to calculate it, if needed.
  convertQuickUrl: function(url) {
    if(!url.match(/^#:@:/)) { return url; }
    url = url.replace(/^#:@:/,'');
    var parts = [];
    while(true) {
      var m = /^(\d+)-/.exec(url);
      if(!m) { break; }
      var len = parseInt(m[1]);
      parts.push(url.substr(m[0].length,len));
      url = url.substr(m[0].length+len+1);
    }
    var kvp = [];
    var kvv = {};
    var type;
    while(parts.length>1) {
      var k = parts.shift();
      var v = parts.shift();
      kvp.push(k);
      kvv[k] = encodeURIComponent(k)+"="+encodeURIComponent(v);
      if(k=='type') { type = v; }
    }
    var path = window.location.pathname.split("/");
    path.splice(1,2,path[1],"ZMenu",kvp['type']||type);
    var params = window.location.search.replace(/^\?/,'').split(/&|;/);
    var nparams = [];
    for(var i=0;i<params.length;i++) {
      var split = params[i].split('=');
      if(kvv[decodeURIComponent(split[0])]===undefined) {
        nparams.push(params[i]);
      }
    }
    for(var i=0;i<kvp.length;i++) {
      nparams.push(kvv[kvp[i]]);
    }
    var uri = path.join("/")+"?"+nparams.join(";");
    return uri;
  },

  populateAjax: function (url, expand) {
    var timeout = this.timeout;
        url     = url || this.href;

    var force = false;
    var ajaxError = true;

    url = this.convertQuickUrl(url);
    if (url && url.match('/ZMenu/')) {
      $.extend($.ajax({
        url:      url,
        data:     this.coords.clickStart ? { click_chr: this.coords.clickChr || Ensembl.location.name, click_start: this.coords.clickStart, click_end: this.coords.clickEnd, click_y: this.coords.clickY } : {},
        dataType: this.crossOrigin ? 'jsonp' : 'json',
        context:  this,
        success:  $.proxy(this.buildMenuAjax,  this),
        error:    $.proxy(this.populateNoAjax, this, force, ajaxError)
      }), { timeout: timeout, expand: expand });
    } else {
      this.populateNoAjax();
    }
  },
  
  buildMenuAjax: function (json, status, jqXHR) {
    var features  = json.features;
    var length    = features.length;
    var cols      = Math.min(length, 5);
    var div, feature, i, j, body, subheader, row;

    if (jqXHR.timeout !== this.timeout) {
      return;
    } else if (length === 0) {
      return this.populateNoAjax();
    }
    
    this.populated = true;
    
    for (var i = 0; i < length; i++) {
      feature = features[i];
      
      if (i === 0 || div.children().length === cols) {
        div = $('<div></div>').appendTo(this.elLk.container);
      }
      
      if (feature.entries.length) {
        body = row = '';
        
        if (feature.caption) {
          body += this.header(feature.caption, length > 1);
        }
        
        for (var j = 0; j < feature.entries.length; j++) {
          if (feature.entries[j].key === 'subheader') {
            if (feature.entries[j].value !== feature.caption) {
              row = this.header(feature.entries[j].value, true);
            }
          } else {
            row = this.row(feature.entries[j].key, feature.entries[j].value, feature.entries[j]['class'], feature.entries[j].childOf);
          }
          
          body += row;
        }
        
        if (jqXHR.expand) {
          jqXHR.expand.replaceWith(body);
          jqXHR.expand = null;
        } else {
          this.makeTable(body).appendTo(div).find('a.update_panel').attr('rel', this.imageId);
        }
      }
    }
    
    if (length > 1) {
      this.elLk.header = $('<div class="header">' + (json.header ? json.header : length + ' features') + '</div>').insertBefore(this.elLk.container.addClass('row' + (length > cols ? ' grid' : '')));
    }

    this.addLocationIcons();

    this.show();
  },

  addLocationIcons: function () {
    var links = this.elLk.container.find('._location_mark').removeClass('_location_mark');
    if (links.length && this.imageId && !this.imageId.match('Multi')) {
      links.each(function () {
        var locationMatch = this.href.match(Ensembl.locationMatch);
        if (locationMatch) {
          $('<br />' +
            '<a class="loc-icon loc-mark _location_mark _ht" title="Mark feature on image" href="' + Ensembl.updateURL({mr: locationMatch[1]}, this.href) +'"></a>' +
            (this.className.match(/_location_change/) ? '<a class="loc-icon loc-zoom _location_change _ht" title="Zoom on feature" href="' + this.href +'"></a>' : '')
          ).insertAfter(this);
        }
        return true;
      });
    }
  },

  populateNoAjax: function (force, error) {
    if (this.das && force !== true) {
      this.populated = true;
      this.show();
      return;
    }
    
    var extra = '';
    var loc   = this.title.match(/Location: (\S+)/);
    var r;
    
    if (loc) {
      r = loc[1].split(/\W/);
      
      this.location = parseInt(r[1], 10) + (r[2] - r[1]) / 2;
      
      extra += this.row(' ', '<a class="loc-icon-a _location_change" href="' + this.zoomURL(1) + '"><span class="loc-icon loc-pin"></span>Centre on feature</a>');
      extra += this.row(' ', '<a class="loc-icon-a _location_change" href="' + this.baseURL.replace(/%s/, loc[1]) + '"><span class="loc-icon loc-zoom"></span>Zoom to feature</a>');
    }

    this.populate(true, extra, error);
  },
  
  populateRegion: function () {
    var panel        = this;
    var min          = this.start;
    var max          = this.end;
    var locationView = !!window.location.pathname.match('/Location/') && !window.location.pathname.match(/\/(Chromosome|Synteny)/);
    var scale        = (max - min + 1) / (this.areaCoords.r - this.areaCoords.l);
    var url          = this.baseURL;
    var menu, caption, start, end, tmp, cls;

    // Gene, transcript views
    function notLocation() {
      var view = end - start + 1 > Ensembl.maxRegionLength ? 'Overview' : 'View';
          url  = url.replace(/.+\?/, '?');
          menu = [ '<a class="loc-icon-a" href="' + panel.speciesPath + '/Location/' + view + url + '"><span class="loc-icon loc-change"></span>Jump to region ' + view.toLowerCase() + '</a>' ];
    }
    
    // Multi species view
    function multi() {
      var label = start ? 'region' : 'location';
          menu  = [ '<a href="' + url.replace(/;action=primary;id=\d+/, '') + '">Realign using this ' + label + '</a>' ];
        
      if (panel.multi) {
        menu.push('<a href="' + url + '">Use ' + label + ' as primary</a>');
      } else {
        menu.push('<a href="' + url.replace(/[rg]\d+=[^;]+;?/g, '') + '">Jump to ' + label + '</a>');
      }
    
      caption = panel.species.replace(/_/g, ' ') + ' ' + panel.chr + ':' + (start ? start + '-' + end : panel.location);
    }
    
    // AlignSlice view
    function align() {
      var label  = start ? 'region' : 'location';
          label += panel.species === Ensembl.species ? '' : ' on ' + Ensembl.species.replace(/_/g, ' ');
      
      menu    = [ '<a class="loc-icon-a" href="' + url.replace(/%s/, Ensembl.coreParams.r + ';align_start=' + start + ';align_end=' + end) + 
                  '"><span class="loc-icon loc-change"></span>Jump to best aligned ' + label + '</a>' ];
      caption = 'Alignment: ' + (start ? start + '-' + end : panel.location);
    }
    
    // Region select
    if (this.coords.r) {
      start = Math.floor(min + (this.coords.s - this.areaCoords.l) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.l) * scale);
      
      if (start > end) {
        tmp   = start;
        start = end;
        end   = tmp;
      }
      
      start = Math.max(start, min);
      end   = Math.min(end,   max);
      
      if (this.strand === 1) {
        this.location = (start + end) / 2;
      } else {
        this.location = (2 * this.start + 2 * this.end - start - end) / 2;
        
        tmp   = start;
        start = this.end + this.start - end;
        end   = this.end + this.start - tmp;
      }

      if (this.align) {
        align();
      } else {
        url     = url.replace(/%s/, this.chr + ':' + start + '-' + end);
        caption = 'Region: ' + this.chr + ':' + start + '-' + end;
        if (!locationView) {
          notLocation();
        } else if (this.multi !== false) {
          multi();
        } else {
          cls = '_location_change';
          
          if (end - start + 1 > Ensembl.maxRegionLength) {
            if (url.match('/View')) {
              url = url.replace('/View', '/Overview');
              cls = '';
            }
          }
          
          menu = [ '<a class="' + cls + ' loc-icon-a" href="' + url + '"><span class="loc-icon loc-change"></span>Jump to region (' + (end - start + 1) + ' bp)</a>' ];
        }
      }

      if (this.multi === false && !this.align) {
        menu.unshift('<a class="_location_mark loc-icon-a" href="' + Ensembl.updateURL({mr: this.chr + ':' + start + '-' + end}, window.location.href) + '"><span class="loc-icon loc-mark"></span>Mark region (' + (end - start + 1) + ' bp)</a>');
      }

    } else { // Point select
      this.location = Math.floor(min + (this.coords.x - this.areaCoords.l) * scale);
      
      if (this.align) {
        url = this.zoomURL(1/10);
        align();
      } else {
        url     = this.zoomURL(1);
        caption = 'Location: ' + this.chr + ':' + this.location;
        
        if (!locationView) {
          notLocation();
        } else if (this.multi !== false) {
          multi();
        } else {
          menu = [
            '<a class="_location_change" href="' + this.zoomURL(10) + '">Zoom out x10</a>',
            '<a class="_location_change" href="' + this.zoomURL(5)  + '">Zoom out x5</a>',
            '<a class="_location_change" href="' + this.zoomURL(2)  + '">Zoom out x2</a>',
            '<a class="_location_change" href="' + url + '">Centre here</a>'
          ];
          
          // Only add zoom in links if there is space to zoom in to.
          $.each([2, 5, 10], function () {
            var href = panel.zoomURL(1 / this);
            
            if (href !== '') {
              menu.push('<a class="_location_change" href="' + href + '">Zoom in x' + this + '</a>');
            }
          });
        }
      }
    }
    
    this.buildMenu(menu, caption);
  },
  
  populateVRegion: function () {
    var min    = this.start;
    var max    = this.end;
    var scale  = (max - min + 1) / (this.areaCoords.b - this.areaCoords.t);
    var length = Math.min(Ensembl.location.length, Ensembl.maxRegionLength) / 2;
    var start, end, view, menu, caption, tmp, url;
    
    if (scale === max) {
      scale /= 2; // For very small images, halve the scale. This will stop start > end problems
    }
    
    // Region select
    if (this.coords.r) {
      start = Math.floor(min + (this.coords.s - this.areaCoords.t) * scale);
      end   = Math.floor(min + (this.coords.s + this.coords.r - this.areaCoords.t) * scale);
      view  = end - start + 1 > Ensembl.maxRegionLength ? 'Overview' : 'View';
      
      if (start > end) {
        tmp   = start;
        start = end;
        end   = tmp;
      }
      
      start   = Math.max(start, min);
      end     = Math.min(end,   max);
      caption = this.chr + ': ' + start + '-' + end;
      
      this.location = (start + end) / 2;
    } else {
      this.location = Math.floor(min + (this.coords.y - this.areaCoords.t) * scale);
      
      view    = 'View';
      start   = Math.max(Math.floor(this.location - length), 1);
      end     =          Math.floor(this.location + length);
      caption = this.chr + ': ' + this.location;
    }
    
    url  = this.baseURL.replace(/.+\?/, '?').replace(/%s/, this.chr + ':' + start + '-' + end);
    menu = [ '<a href="' + this.speciesPath + '/Location/' + view + url + '">Jump to region ' + view.toLowerCase() + '</a>' ];
    
    if (!window.location.pathname.match('/Chromosome')) {
      menu.push('<a href="' + this.speciesPath + '/Location/Chromosome' + url + '">Chromosome summary</a>');
    }
    
    this.buildMenu(menu, caption);
  },

  buildMenu: function (content, caption, link, extra, decodeHTML, error) {
    var body = [];
    var i    = content.length;
    var menu, title, parse, j, row;
    
    caption = caption || (error ? 'Message' : 'Menu');
    extra   = extra   || '';

    if (error === true) {
      extra = this.row('<p>Still loading data... <a class="refresh-zmenu"> Please click here to refresh </a> this menu. </p> <p>If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="popup">contact our HelpDesk team</a>.</p>') + extra;
    }
    else if (link === true && this.href) {
      title = this.title ? this.title.split('; ')[0] : caption;
      extra = this.row('Link', '<a href="' + this.href + '">' + title + '</a>') + extra;
    }


    while (i--) {
      parse = this.coloured ? content[i].match(/\[(.+)\]/) : null;
      
      if (parse) {
        parse = parse[1].split(',');
        
        for (j = 0; j < parse.length; j += 2) {
          parse[j] = parse[j].split(':');
          row      = '<td style="color:#' + parse[j][1] + '">' + parse[j][0] + '</td>';
          
          if (parse[j+1]) {
            parse[j+1] = parse[j+1].split(':');
            row       += '<td style="color:#' + parse[j+1][1] + '">' + parse[j+1][0] + '</td>';
          } else {
            row += '<td></td>';
          }
          
          body.push('<tr>' + row + '</tr>');
        }
      } else {
        var kv = decodeHTML ? $('<span/>').html(content[i]).text() : content[i]; // Unescape HTML if needed
        menu = kv.split(': ');
        body.unshift(this.row.apply(this, menu.length > 1 ? [ menu.shift(), menu.join(': ') ] : [ kv ]));
      }
    }
    
    this.makeTable(this.header(caption) + body.join('') + extra).appendTo(this.elLk.container);
    
    if (this.das) {
      this.elLk.container.hide();
    } else {
      this.populated = true;
      this.show();
    }
  },
  
  zoomURL: function (scale) {
    var w = Math.min(Ensembl.location.length, Ensembl.maxRegionLength) * scale;
    
    if (w < 1) {
      return '';
    }
    
    var start = Math.round(this.location - (w - 1) / 2);
    var end   = Math.round(this.location + (w - 1) / 2); // No constraints on end - can't know how long the chromosome is, and perl will deal with overflow
    
    if (start < 1) {
      start = this.start;
    }
    
    if (this.align) {
      return this.baseURL.replace(/%s/, Ensembl.coreParams.r + ';align_start=' + start + ';align_end=' + end);
    } else {
      return this.baseURL.replace(/%s/, (this.chr || Ensembl.location.name) + ':' + start + '-' + end);
    }
  },
  
  show: function (loading) {
    if (!loading && this.elLk.container.html()) {
      this.elLk.loading.hide();
      this.elLk.container.show();
    }
    
    Ensembl.EventManager.trigger('panelToFront', this.id);
    
    if (!this.el.css({ top: 0, left: 0, display: 'block' }).position({ of: this.event, my: 'left top', collision: 'fit' }).hasClass('ui-draggable')) {
      this.el.scrollTop(0).draggable({
        handle:       '.header:not(.subheader)',
        start:        function() { $(this).css({'margin-top': -1 * $(window).scrollTop() }); },
        stop:         function() { $(this).css({'top': parseInt($(this).css('top')) + parseInt($(this).css('margin-top')), 'margin-top': 0 }); }
      });
    }
    
    if (this.relatedEl) {      
      this.relatedEl.addClass('highlight');
    }

    // enable helptips
    this.elLk.container.find('._ht').helptip();

    // any zmenus inside zmenus
    this.elLk.container.find('._zmenu').zMenuLink();

    // Hover ZMenus can be closed before they load!
    if(this.el.hasClass('closed')) {
      this.hide();
    }
  },
  
  showExisting: function (data) {
    this.event  = data.event;
    this.coords = data.coords;
    if (this.group || this.drag || this.event.shiftKey) {
      if (this.elLk.header) {
        this.elLk.header.remove();
        delete this.elLk.header;
      }
      this.elLk.container.empty();
      this.hide();
      this.getContent();
    } else {
      this.show();
    }
  },
  
  hide: function () {
    if (this.el) {
      this.base();
      
      if (this.relatedEl) {
        this.relatedEl.removeClass('highlight');
      }
    }
  },
  
  makeTable: function (content) {
    var classes  = {};
    var table    = $('<table class="zmenu" cellspacing="0"></table>').html(content);
    var children = table.find('tr.child');
    var rows     = table.find('tr[class]:not(.child)').each(function () {
      if (children.filter('.' + this.className).length) {
        classes[this.className] = 1;
      }
    });
    
    function toggle(e) {
      if (e.target.nodeName !== 'A') {
        var tr = $(this).parent();
        
        tr.siblings('.' + tr[0].className).toggle();
        $(this).toggleClass('closed opened');
        
        tr = null;
      }
    }
    
    for (var c in classes) {
      rows.filter('.' + c).children(':first').addClass('closed').on('click', toggle);
      children.filter('.' + c).hide();
    }
    
    rows = children = null;
    
    return table;
  },
  
  header: function (caption, subheader) {
    return '<tr class="header' + (subheader ? ' subheader' : '') + '"><th colspan="2">' + caption + '</th></tr>';
  },
  
  row: function (cell1, cell2, cls, childOf) {
    return (
      '<tr' + (cls || childOf ? ' class="' + (cls || childOf).replace(/\W/g, '_') + (childOf ? ' child' : '') + '"' : '') + '>' + 
        (cell1 && cell2 ? '<th>' + cell1 + '</th><td>' + cell2 + '</td>' : '<td colspan="2">' + (cell1 || cell2) + '</td>') +
      '</tr>'
    );
  }
}, {
  template: $([
    '<div class="zmenu_holder">',
    '  <span class="close"></span>',
    '  <div class="info_popup floating_popup">',
    '    <div class="loading"><div>Loading component</div><p class="spinner"></p></div>',
    '    <div class="container"></div>',
    '  </div>',
    '</div>'
  ].join(''))
});
