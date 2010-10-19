// $Revision$

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.matchRegex   = new RegExp(/[\?;&]r=([^;&]+)/);
    this.replaceRegex = new RegExp(/([\?;&]r=)[^;&]+(;&?)*/);
    this.autoComplete = { query: false, all: 0 };
    
    Ensembl.EventManager.register('hashChange',   this, this.getContent);
    Ensembl.EventManager.register('windowResize', this, this.resize);
    
    if (!window.location.pathname.match(/\/Multi/)) {
      Ensembl.EventManager.register('ajaxComplete', this, function () { this.enabled = true; });
    }
  },
  
  init: function () {
    var panel = this;
    var hash, boundaries, r, l, i;
    
    this.base();
    
    if (Ensembl.ajax == 'disabled') {
      return; // If the user has ajax disabled, don't create the slider. The navigation will then be based on the ramp links.
    }
    
    this.enabled = this.params.enabled || false;
    this.reload  = false;
    
    this.elLk.sliderConfig  = $('span.ramp',          this.el).hide().children();
    this.elLk.sliderLabel   = $('.slider_label',      this.el);
    this.elLk.updateURL     = $('.update_url',        this.el);
    this.elLk.slider        = $('.slider',            this.el);
    this.elLk.locationInput = $('.location_selector', this.el);
    this.elLk.geneLocForm   = $('.gene_location',     this.el);
    this.elLk.geneInput     = $('.gene_selector',     this.elLk.geneLocForm).attr('autocomplete', 'off');
    this.elLk.g             = $('input[name=g]',      this.elLk.geneLocForm);
    this.elLk.db            = $('input[name=db]',     this.elLk.geneLocForm);
    this.elLk.autoComplete  = $('<ul>', { className: 'auto_complete', css: this.autoCompletePosition() }).insertAfter(this.elLk.geneInput);
    this.elLk.navLinks      = $('a',                  this.el).addClass('constant').bind('click', function (e) {
      var newR;
      
      if (panel.enabled === true) {
        if ($(this).hasClass('move')) {
          panel.reload = true;
        }
        
        newR = this.href.match(panel.matchRegex)[1];
        
        if (newR != Ensembl.coreParams.r) {
          window.location.hash = 'r=' + newR; 
        }
        
        return false;
      }
    });
    
    if (window.location.hash) {
      hash = window.location.hash.replace(/^#/, '?') + ';';
      r    = hash.match(this.matchRegex)[1].split(/\W/);
      l    = r[2] - r[1] + 1;
      
      this.elLk.sliderLabel.html(l);
      this.elLk.sliderConfig.removeClass('selected');
      
      i = this.elLk.sliderConfig.length;
      
      if (l >= parseInt(this.elLk.sliderConfig[i-1].name, 10)) {
        this.elLk.sliderConfig.last().addClass('selected');
      } else {
        boundaries = $.map(this.elLk.sliderConfig, function (el, i) {
          return Math.sqrt((i ? parseInt(panel.elLk.sliderConfig[i-1].name, 10) : 0) * parseInt(el.name, 10));
        });
        
        boundaries.push(1e30);
        
        while (i--) {
          if (l > boundaries[i] && l <= boundaries[i+1]) {
            this.elLk.sliderConfig.eq(i).addClass('selected');
            break;
          }
        }
      }
    }
    
    this.sliderInit();
    this.autoCompleteInit();
    
    Ensembl.EventManager.register('mouseUp', this, function () { panel.elLk.autoComplete.hide(); });
  },
    
  sliderInit: function () {
    var panel = this;
    
    $('.slider_wrapper', this.el).children().css('display', 'inline-block');
    
    this.elLk.slider.slider({
      value: panel.elLk.sliderConfig.filter('.selected').index(),
      step:  1,
      min:   0,
      max:   panel.elLk.sliderConfig.length - 1,
      force: false,
      slide: function (e, ui) {
        panel.elLk.sliderLabel.html(panel.elLk.sliderConfig[ui.value].name + ' bp').show();
      },
      change: function (e, ui) {      
        var input = panel.elLk.sliderConfig[ui.value];
        var url   = input.href;
        var r     = url.match(panel.matchRegex)[1];
        
        panel.elLk.sliderLabel.html(input.name + ' bp');
        
        input = null;
        
        if (panel.elLk.slider.slider('option', 'force') === true) {
          return false;
        } else if (panel.enabled === false) {
          Ensembl.redirect(url);
          return false;
        } else if ((!window.location.hash || window.location.hash == '#') && url == window.location.href) {
          return false;
        } else if (window.location.hash.match('r=' + r)) {
          return false;
        }
        
        window.location.hash = 'r=' + r;
      },
      stop: function () {
        panel.elLk.sliderLabel.hide();
        $('.ui-slider-handle', panel.elLk.slider).trigger('blur'); // Force the blur event to remove the highlighting for the handle
      }
    });
  },
   
  getContent: function () {
    var panel = this;
    
    if (this.reload === true) {
      $.ajax({
        url: Ensembl.urlFromHash(panel.elLk.updateURL.val()),
        dataType: 'html',
        success: function (html) {
          Ensembl.EventManager.trigger('addPanel', panel.id, 'LocationNav', html, $(panel.el), { enabled: panel.enabled });
        }
      });
    } else {
      $.ajax({
        url: Ensembl.urlFromHash(this.elLk.updateURL.val() + ';update_panel=1'),
        dataType: 'json',
        success: function (json) {
          var sliderValue = json.shift();
          
          if (panel.elLk.slider.slider('value') != sliderValue) {
            panel.elLk.slider.slider('option', 'force', true);
            panel.elLk.slider.slider('value', sliderValue);
            panel.elLk.slider.slider('option', 'force', false);
          }
        
          panel.elLk.updateURL.val(json.shift());
          panel.elLk.locationInput.val(json.shift());
          
          panel.elLk.navLinks.not('.ramp').attr('href', function () {
            return this.href.replace(panel.replaceRegex, '$1' + json.shift() + '$2');
          });
        }
      });
    }
  },
  
  autoCompleteInit: function () {
    var panel = this;
    
    // On gene form submit, stop the request going to psychic search if the user has selected a gene from the dropdown,
    // or has typed in something which matches (case insensitive) a name from the dropdown.
    this.elLk.geneLocForm.bind('submit', function () {
      var form  = this;
      var g     = panel.elLk.g.val();
      var query = panel.elLk.geneInput.val().toUpperCase();
      
      if (g) {
        this.action = window.location.pathname;
      } else {
        panel.elLk.autoComplete.find('span.name').each(function () {
          if ($(this).text().toUpperCase() == query) {
            form.action = window.location.pathname;
            panel.elLk.g.val($(this).siblings('.stable_id').text());
            return true;
          }
        });
      }
    });
    
    this.elLk.geneInput.bind('keyup', function (e) {
      var value = this.value;
      
      // Filter down existing results as the user types more
      // Returns false if a new search term has been entered (the user deleted back past the limit of the current query)
      // or if the current results do not contain the complete set for that query (panel.autoComplete.all == 0)
      function filter() {
        var show = false;
        
        if (panel.autoComplete.all && panel.autoComplete.query && value.match('^' + panel.autoComplete.query)) {
          panel.elLk.autoComplete.children().each(function () {
            if ($(this).text().match('^' + value, 'i')) {
              $(this).show();
              show = true;
            } else {
              $(this).hide();
            }
          }).end()[show ? 'show' : 'hide']();
          
          return true;
        } else {
          return false;
        }
      }
      
      // e.keyCode = 38: escape
      if (e.keyCode == 27) {
        panel.elLk.autoComplete.hide();
        return;
      }
      
      // e.keyCode = 38: up
      // e.keyCode = 40: down
      if (panel.elLk.autoComplete && (e.keyCode == 38 || e.keyCode == 40)) {
        panel.elLk.autoComplete.children().removeClass('focused');
        
        if (panel.autoComplete.focused) {
          if (!panel.autoComplete.focused[e.keyCode == 38 ? 'prev' : 'next']().trigger('mouseover', true).length) {
            panel.elLk.geneInput.val(value);
          }
        } else {
          panel.elLk.autoComplete.children(e.keyCode == 38 ? ':last' : ':first').trigger('mouseover', true);
        }
        
        return;
      }
      
      // e.keyCode = 8:       backspace
      // e.keyCode = 32:      space
      // e.keyCode = 46:      delete
      // e.keyCode > 47:      alphanumeric/symbols
      // e.keyCode = 111-123: F keys
      if (
        value.length < 3 || 
        e.ctrlKey || e.altKey || 
        (e.keyCode < 46 && e.keyCode != 8 && e.keyCode != 32) || 
        (e.keyCode > 111 && e.keyCode < 124) || 
        value.match(/^\w+:\d+/)
      ) {
        return;
      }
      
      if (panel.autoComplete.reposition === true) {
        panel.elLk.autoComplete.css(panel.autoCompletePosition());
      }
      
      if (panel.timer) {
        clearTimeout(panel.timer);
      }
      
      if (panel.xhr) {
        panel.xhr.abort();
        panel.xhr = false;
      }
      
      if (!filter()) {
        panel.timer = setTimeout(function () {
          panel.xhr = $.ajax({
            url: Ensembl.speciesPath + '/autocomplete',
            data: { q: value },
            dataType: 'json',
            success: function (json) {
              panel.elLk.autoComplete.empty();
              panel.autoComplete = { query: value, all: json.all };
              
              for (var i in json.results) {
                $('<li>', {
                  html: [ '<span class="name">', json.results[i][0], '</span><span class="stable_id">', json.results[i][1], '</span><input type="hidden" class="db" value="', json.results[i][2], '" />' ].join(''),
                  click: function () {
                    panel.elLk.geneInput.val($('.name', this).text());
                    panel.elLk.g.val($('.stable_id', this).text());
                    panel.elLk.db.val($('.db', this).val());
                    panel.elLk.geneLocForm.trigger('submit');
                  },
                  mouseover: function (e, keyPress) {
                    $(this).siblings().removeClass('focused');
                    
                    panel.autoComplete.focused = $(this).addClass('focused');
                    
                    if (keyPress === true) {
                      panel.elLk.geneInput.val($('.name', this).text());
                    }
                  },
                  mouseout: function () {
                    $(this).removeClass('focused');
                  }
                }).appendTo(panel.elLk.autoComplete);
              }
              
              if (!json.results.length) {
                panel.elLk.autoComplete.hide();
              } else {
                panel.elLk.autoComplete.show();
              }
              
              filter();
            }
          });
        }, 100);
      }
    });
  },
  
  autoCompletePosition: function () {
    var pos = this.elLk.geneInput.position();
    
    return {
      top:   pos.top + this.elLk.geneInput.innerHeight(),
      left:  pos.left,
      width: this.elLk.geneInput.innerWidth()
    };
  },
  
  resize: function () {
    this.autoComplete.reposition = true;
    this.elLk.autoComplete.hide();
  }
});
