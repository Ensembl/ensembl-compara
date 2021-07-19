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

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);

    this.geneCache      = {};
    this.geneIDCache    = {};
    this.sliderConfig   = false;
    this.extraParams    = {};
    this.refreshOnly    = true;
    this.alignmentPage  = false;

    Ensembl.EventManager.register('hashChange',  this, this.getContent);
    Ensembl.EventManager.register('changeWidth', this, this.resize);
    Ensembl.EventManager.register('imageResize', this, this.resize);
    
    if (window.location.pathname.match(/\/Multi/)) {
      this.extraParams  = {realign: 1};
      this.refreshOnly  = false;
    }
  },

  currentLocations: function () {
  /*
   * Extracts r params into easy to use format
   */
    var out     = {};
    var rRegexp = new RegExp(/^([^:]*):([^-]*)-([^:]*)(:.*)?/);

    $.each(window.location.search.replace(/^\?/, '').split(/[;&]/), function (i, part) {
      var kv = part.split('=');
      if (!kv[0].match(/^r[0-9]*$/)) {
        return;
      }
      var rParts = decodeURIComponent(kv[1]).match(rRegexp);
      out[kv[0]] = [rParts[1], parseInt(rParts[2]), parseInt(rParts[3]), rParts[4] || ''];
    });

    return out;
  },

  newHref: function (rs, others) {
  /*
   * Creates a new URL from the given r and other params
   */
    var url       = window.location.href.split("?");
    var newParams = [];
    others        = others || {};

    $.each(url[1].split(/[;&]/), function (i, part) {
      var kv = part.split('=');

      if (kv[0].match(/^r[0-9]*$/) && rs[kv[0]]) {
        newParams.push(kv[0] + '=' + rs[kv[0]][0] + ':' + rs[kv[0]][1] + '-' + rs[kv[0]][2] + (rs[kv[0]][3] || ''));
      } else if (kv[0] in others) {
        newParams.push(kv[0] + '=' + others[kv[0]]);
        delete others[kv[0]];
      } else {
        newParams.push(kv[0] + '=' + decodeURIComponent(kv[1]));
      }
    });

    for (var k in others) {
      newParams.push(k + '=' + others[k]);
    }

    for (var k in this.extraParams) {
      newParams.push(k + '=' + this.extraParams[k]);
    }

    return url[0] + '?' + newParams.sort(function(a, b) {
      return a.split('=')[0] > b.split('=')[0];
    }).join(';');
  },

  arrowHref: function (step) {
  /*
   * Returns href for the arrow buttons at cur pos. as string
   */
    var panel = this;
    var rs    = this.currentLocations();

    $.each(rs, function (k, v) {
      v[1] += step;
      v[2] += step;
      if (k == 'r') {
        if (v[1] > panel.sliderConfig.length) { v[1] = panel.sliderConfig.length - panel.sliderConfig.min; }
        if (v[2] > panel.sliderConfig.length) { v[2] = panel.sliderConfig.length; }
        if (v[1] < 1) { v[1] = 1; }
        if (v[2] < 1) { v[2] = panel.sliderConfig.min; }
      }
    });

    return this.newHref(rs);
  },

  zoomHref: function (factor) {
  /*
   * Returns href for +/- buttons at cur pos. as string
   */
    var rs    = this.currentLocations();
    var width = rs['r'][2] - rs['r'][1];
    rs        = this.rescale(rs, width * factor);

    if (factor > 1) {
      $.each(rs, function (k, v) {
        if (v[1] == v[2]) { v[2]++; }
      });
    }

    return this.newHref(rs);
  },

  rescale: function(rs, newWidth) {
  /*
   * Resets the r params according to the new width provided
   */
    var panel = this;
    newWidth  = Math.round(newWidth);
    var out   = {};

    $.each(rs, function (k, v) {
      var rStart  = Math.max(Math.round((Math.round(v[1] + v[2]) - newWidth) / 2), 1);
      var rEnd    = rStart + newWidth + 1;

      if (k == 'r') {
        rStart  = Math.max(Math.min(rStart, panel.sliderConfig.length - panel.sliderConfig.min), 1);
        rEnd    = Math.min(rEnd, panel.sliderConfig.length);
      }

      out[k] = [v[0], rStart, rEnd, v[3]];
    });

    return out;
  },

  updateButtons: function(sliderVal) {
    /*
     * Update button hrefs (and location input) at cur. pos
     */
    sliderVal = Math.round(typeof sliderVal === 'undefined' ? this._val2pos() : sliderVal);
    var rs    = this.currentLocations();
    var width = rs['r'][2]-rs['r'][1]+1;

    this.elLk.left1.attr('href', this.arrowHref(-width));
    this.elLk.left2.attr('href', this.arrowHref(-1e6));
    this.elLk.right1.attr('href', this.arrowHref(width));
    this.elLk.right2.attr('href', this.arrowHref(1e6));

    this.elLk.zoomIn.attr('href', this.zoomHref(0.5)).toggleClass('disabled', sliderVal === 0).helptip(sliderVal === 0 ? 'disable' : 'enable');
    this.elLk.zoomOut.attr('href', this.zoomHref(2)).toggleClass('disabled', sliderVal === 100).helptip(sliderVal === 100 ? 'disable' : 'enable');

    this.elLk.regionInput.val(rs['r'][0] + ':' + rs['r'][1] + '-'+rs['r'][2]);
  },
 
  init: function () {
    var panel = this;
    
    this.base();

    this.elLk.navbar    = this.el.find('.navbar');
    this.elLk.imageNav  = this.elLk.navbar.find('.image_nav');
    this.elLk.forms     = this.elLk.navbar.find('form');
    this.elLk.navLinks  = this.elLk.imageNav.find('a');

    this.alignmentPage  = !!this.elLk.forms.first().closest('.alignment_select').length;

    this.initNavForms();
    this.initNavLinks();
    this.initSlider();
    this.resize();
  },

  initNavForms: function() {
  /*
   * Initialises the gene and location navigation form
   */
    var panel = this;

    this.elLk.regionInput = this.elLk.forms.find('input[name=r]');
    this.elLk.geneInput   = this.elLk.forms.find('input[name=q]');

    // attach form submit event
    this.elLk.forms.on('submit', function (e) {
      e.preventDefault();

      var gene = {};
      var term, goToGene;

      if (panel.alignmentPage) {

        return Ensembl.redirect(panel.newHref([], (function(form) {
          var p = {};
          $.each(form.serializeArray(), function (v, k) {
            p[k.name] = k.value;
          });
          return p;
        })($(this))));
      }

      // g and db params needed for gene navigation
      if (this.className.match(/_nav_gene/)) {

        goToGene = function (panel, gene, term) {

          if (gene) {
            panel.elLk.geneInput.autocomplete('close').val(gene.label || gene.g);
            panel.updateURL({ g: gene.g, db: gene.db, r: gene.r });
          } else {
            alert("No gene found for '" + term + "'");
            return;
          }
        };

        term = this.q.value.trim().toUpperCase();

        if (term.length < 3) {
          alert('Please type in at least 3 characters to get a list of matching genes');
          return;
        }

        if (gene = (panel.geneCache[term.substr(0, 3)] || {})[term] || panel.geneIDCache[term]) {

          goToGene(panel, gene, term);

        } else {

          // gene not cached already, try looking for the stable id
          $.ajax({
            url: Ensembl.speciesPath + '/Ajax/autocomplete_geneid',
            cache: true,
            data: { q: term },
            dataType: 'json',
            context: { panel: panel, stableID: term, goToGene: goToGene },
            success: function(json) {
              if (this.stableID in json) {
                this.panel.geneIDCache[this.stableID] = json[this.stableID];
              }
              this.goToGene(this.panel, this.panel.geneIDCache[this.stableID], this.stableID);
            }
          });
          return;
        }
      } else {

        panel.updateURL({ r: this.r.value.trim() });
      }

    }).find('a').on('click', function (e) {
      e.preventDefault();
      $(this).closest('form').trigger('submit');
    });

    // autocomplete on the gene input field
    this.elLk.geneInput.autocomplete({
      minLength: 3,
      source: function(request, responseCallback) {

        var context = { // context to be passed to ajax callbacks
          panel     : panel,
          term      : request.term,
          key       : request.term.substr(0, 3).toUpperCase(),
          callback  : function(str, group) {
            var regexp = new RegExp('^' + $.ui.autocomplete.escapeRegex(str), 'i');
            return responseCallback($.map(group, function(val, geneLabel) {
              return regexp.test(geneLabel) ? val.label : null;
            }));
          }
        }

        if (context.key in panel.geneCache) {
          return context.callback(request.term, panel.geneCache[context.key]);
        }

        $.ajax({
          url: Ensembl.speciesPath + '/Ajax/autocomplete',
          cache: true,
          data: {
            q: context.key
          },
          dataType: 'json',
          context: context,
          success: function (json) {
            this.panel.geneCache[this.key] = json;
          },
          complete: function () {
            return this.callback(this.term, this.panel.geneCache[this.key]);
          }
        });
      },
      select: function(e, ui) {
        $(this).closest('form').find('input[name=q]').val(ui.item.value).end().trigger('submit');
      }
    });
  },

  updateURL: function(params) {
  /*
   * Updates the url and does a page refresh (possible via ajax)
   */
    var r = params.r.match(/^([^:]+):\s?([0-9\,]+)(-|_|\.\.)([0-9\,]+)$/);

    if (!r || r.length !== 5 || r[4] - r[2] < 0) {
      alert('Invalid location: ' + params.r);
      return;
    }

    if (this.refreshOnly) {
      Ensembl.updateURL($.extend({}, this.extraParams, {
        g: params.g,
        db: params.db
      }));

      /* replacing chr, _ and .. in location search */
      var new_r = (r[1].replace(/^(chr)/,''))+":"+r[2].replace(/\,/g,'')+(r[3].replace(/(_|\.\.)/, '-'))+r[4].replace(/\,/g,'');
      new_r     = new_r.replace(/\s/g,''); //replacing any blank space
      Ensembl.updateLocation(new_r);
    } else {
      Ensembl.redirect(this.newHref([], params));
    }
  },

  initNavLinks: function () {
  /*
   * Initialises the image navigation like
   */
    var panel = this;

    this.elLk.navLinks.helptip().addClass('constant').on('click', function (e) {

      if (this.className.match(/disabled/)) {
        return false;
      }

      var newR;

      if (panel.refreshOnly) {
        e.preventDefault();
        newR = this.href.match(Ensembl.locationMatch)[1];

        if (newR !== Ensembl.coreParams.r) {
          Ensembl.updateLocation(newR);
        }
      }
    });
  },

  initSlider: function () {
  /*
   * Initialises the slider
   */
    var panel = this;

    try {
      this.sliderConfig = $.parseJSON(this.elLk.imageNav.find('span.ramp').remove().text());
    } catch (ex) {
      return;
    }

    if (!this.sliderConfig) {
      return;
    }

    this.elLk.slider      = this.elLk.imageNav.find('.slider_wrapper').show().find('.slider');
    this.elLk.sliderLabel = this.elLk.imageNav.find('.slider_label').hide();
    this.elLk.zoomIn      = this.elLk.navLinks.filter('.zoom_in');
    this.elLk.zoomOut     = this.elLk.navLinks.filter('.zoom_out');
    this.elLk.left1       = this.elLk.navLinks.filter('.left_1');
    this.elLk.left2       = this.elLk.navLinks.filter('.left_2');
    this.elLk.right1      = this.elLk.navLinks.filter('.right_1');
    this.elLk.right2      = this.elLk.navLinks.filter('.right_2');

    this.elLk.slider.slider({
      value: this._val2pos(),
      step:  1,
      min:   0,
      max:   100,
      force: false,
      slide: function (e, ui) {
        panel.elLk.sliderLabel.html(panel._pos2val(ui.value) + ' bp').show();
      },
      change: function (e, ui) {

        if (panel.elLk.slider.slider('option','fake')) {
          return;
        }

        var rs = panel.rescale(panel.currentLocations(), panel._pos2val(ui.value));
        // Max window size is 1MB
        if (rs['r'][2] - rs['r'][1] > 1000000) {
          rs['r'][2] = rs['r'][1] + 1000000; 
        }

        if (panel.refreshOnly) {
          Ensembl.updateLocation(rs['r'][0] + ':' + rs['r'][1] + '-' + rs['r'][2]);
        } else {
          Ensembl.redirect(panel.newHref(rs));
        }
      },
      stop: function (e, ui) {
        panel.elLk.sliderLabel.hide();
        $(ui.handle).trigger('blur');
      }
    });

    this.updateButtons();
  },

  getContent: function () {
  /*
   * Overrides the default getContent method to update the slider to the new location instead of refreshing the whole panel via ajax
   */
    if (this.elLk.slider) {
      var sliderVal = this._val2pos();
      this.elLk.slider.slider('option','fake',true);
      this.elLk.slider.slider('value', sliderVal);
      this.elLk.slider.slider('option','fake',false);
      this.updateButtons(sliderVal);
    }
  },

  resize: function () {
  /*
   * Rearranges the navbar accoding to the new browser window size
   */
    var widths = {
      navbar: this.elLk.navbar.width(),
      slider: this.elLk.imageNav.width(),
      forms:  this.elLk.forms.width()
    };
    
    if (widths.navbar < widths.forms + widths.slider) {
      this.elLk.navbar.removeClass('narrow1').addClass('narrow2');
    } else if (widths.navbar < (widths.forms * this.elLk.forms.length) + widths.slider) {
      this.elLk.navbar.removeClass('narrow2').addClass('narrow1');
    } else {
      this.elLk.navbar.removeClass('narrow1 narrow2');
    }

    if (this.elLk.slider) {
      this.updateButtons();
    }
  },

  _val2pos: function () { // from 0-100 on UI slider to bp
    var rs        = this.currentLocations();
    var width     = rs['r'][2] - rs['r'][1] + 1;
    var slideMul  = ( Math.log(this.sliderConfig.max) - Math.log(this.sliderConfig.min) ) / 100;
    var slideOff  = Math.log(this.sliderConfig.min);

    return Math.min(Math.max((Math.log(width) - slideOff) / slideMul, 0), 100);
  },

  _pos2val: function(pos) { // from bp to 0-100 on UI slider
    var slideMul = ( Math.log(this.sliderConfig.max) - Math.log(this.sliderConfig.min) ) / 100;
    var slideOff = Math.log(this.sliderConfig.min);
    var rawValue = Math.exp(pos * slideMul + slideOff);

    // To 2sf
    var mag   = Math.pow(10, 2 - Math.ceil(Math.log(rawValue) / Math.LN10));

    return Math.round(Math.round(rawValue*mag) / mag);
  }
});
