/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {
    this.base();
    
    this.xhr = false;
    
    var fnEls = {
      ajaxLoad:         $('.ajax', this.el),
      hideHints:        $('.hint', this.el),
      helpTips:         $('._ht', this.el),
      zMenuLink:        $('._zmenu', this.el),
      wrapping:         $('table.cellwrap_inside, table.heightwrap_inside', this.el),
      selectToToggle:   $('._stt', this.el),
      selectAll:        $('input._selectall', this.el),
      filterable:       $('._fd', this.el),
      speciesDropdown:  $('._sdd', this.el),
      toggleButtons:    $('.tool_buttons a.togglebutton', this.el),
      dataTable:        $('table.data_table', this.el),
      redirectForm:     $('form._redirect', this.el),
      newTable:         $('.new_table', this.el)
    };
    
    if (this.el.hasClass('ajax')) {
      $.extend(fnEls.ajaxLoad, this.el);
    }
    
    $.extend(this.elLk, fnEls);

    this.toggleable();  
    $(this).afterimage();

    // To open motif feature widget on regulation views
    this.el.on("click", 'a._motif', function(e) {
      e.preventDefault();
      Ensembl.openMotifWidget($(this).html());
    });

    for (var fn in fnEls) {
      if (fnEls[fn].length) {
        this[fn]();
      }
    }
    
    Ensembl.EventManager.register('updatePanel', this, this.getContent);
    
    if (this.el.parent('.initial_panel')[0] === Ensembl.initialPanels.get(-1)) {
      Ensembl.EventManager.register('hashChange', this, this.hashChange);
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    Ensembl.EventManager.deferTrigger('relocateTools', this.el.find('.other_tool'));
    
    // Links in a popup (help) window should make a new window in the main browser
    if (window.name.match(/^popup_/)) {
      $('a:not(.cp-internal, .popup)', this.el).on('click', function () {
        window.open(this.href, window.name.replace(/^popup_/, '') + '_1');
        return false;
      });
    }

    this.el.externalLinks();
  },
  
  ajaxLoad: function () {
    var panel = this;
    
    $('.navbar', this.el).width(Ensembl.width);

    if ($.find('.js_panel .error.fatal').length) {
      // Return false if there are any fatal errors displayed
      return false;
    }

    this.elLk.ajaxLoad.each(function () {
      var el    = $(this);
      var url   = el.find('input.ajax_load').val();
      var data  = {};
      
      if (!url) {
        return;
      }
      
      if (url.match(/\?/)) {
        url = Ensembl.replaceTimestamp(url);
      } else {
        url += '?';
      }
      
      el.find('input.ajax_post').each(function(i, inp) {
        data[inp.name] = inp.value;
      });
      
      panel.getContent(url, $(this), { updateURL: url + ';update_panel=1', updateType: $.isEmptyObject(data) ? 'get' : 'post', updateData: data });
    });
  },

  getContent: function (url, el, params, newContent, attrs) {
    var node, data, background;
   
    attrs = attrs || {};
    background = attrs.background || 0;
    if (typeof el === 'string') {
      el = $(el, this.el);
      if(!background) { el.empty(); }
    } else {
      $('.js_panel', el || this.el).each(function () {
        Ensembl.EventManager.trigger('destroyPanel', this.id); // destroy all sub panels
      });
    }
    
    params = params || this.params;
    url    = url    || Ensembl.replaceTimestamp(params.updateURL);
    el     = el     || this.el;
    if(!background) { el.empty(); }
    
    switch (el[0].nodeName) {
      case 'DL': node = 'dt'; break;
      case 'UL': 
      case 'OL': node = 'li'; break;
      default  : node = 'p';  break;
    }
    
    if(!background) {
      el.append('<' + node + ' class="spinner ajax_pending">Loading component</' + node + '>');
    }
    
    if (newContent === true) {
      window.location.hash = el[0].id; // Jump to the newly added div
    } else if (newContent) {
      Ensembl.updateURL(newContent); // A link was clicked that needs to add parameters to the url
    }
    
    data = params.updateData || (typeof newContent === 'object' ? newContent : {}) || {};
    
    // Add the URL params as POST params in case of POST request
    if (params.updateType === 'post') {
      $.each((url.split(/\?/)[1] || '').split(/&|;/), function(i, param) {
        param = param.split('=');
        if (typeof param[0] !== 'undefined' && !(param[0] in data)) {
          data[param[0]] = param[1];
        }
      });
    }
    
    this.xhr = $[attrs.paced ? 'paced_ajax' : 'ajax']({
      url: url,
      data: data,
      dataType: 'html',
      context: this,
      type: params.updateType,
      success: function (html) {
        if(background) {
          el.empty();
        }
        if (html) {
          Ensembl.EventManager.trigger('addPanel', undefined, $((html.match(/<input[^<]*class="[^<]*panel_type[^<]*"[^<]*>/) || [])[0]).val() || 'Content', html, el, params);
          
          if (newContent === true) {
            // Jump to the newly added content. Set the hash to a dummy value first so the browser is forced to jump again
            window.location.hash = '_';
            window.location.hash = el[0].id;
          }
        } else {
          el.html('');
        }
        
        Ensembl.EventManager.trigger('ajaxLoaded');
      },
      error: function (e) {
        if (e.status !== 0) { // e.status === 0 when navigating to a new page while request is still loading
          el.html('<div class="error ajax_error"><h3>Ajax error</h3><div class="error-pad"><p>Sorry, the page request "' + url + '" failed to load.</p></div></div>');
        }
      },
      complete: function () {
        el = null;
        this.xhr = false;
      }
    });
  },
  
  addContent: function (url, rel) {
    var newContent = $('<div class="js_panel">').appendTo(this.el);
    var i          = 1;
    
    if (rel) {
      newContent.addClass(rel);
    } else {
      rel = 'anchor';
    }
    
    // Ensure unique id
    while (document.getElementById(rel)) {
      rel += i++;
    }
    
    newContent.attr('id', rel + 'Panel');
    
    this.getContent(url, newContent, this.params, true);
    
    return newContent;
  },
  
  toggleable: function () {
    var panel     = this;
    var toTrigger = {};
    
    $('a.toggle, .ajax_add', this.el).on('click', function (e) {
      
      e.preventDefault();
      
      var duration = !!e.which && $(this).hasClass('_slide_toggle') ? parseInt((this.className.match(/_slide_toggle_(\d+)/) || [300]).pop()) : undefined;
      
      if ($(this).hasClass('ajax_add')) {
        var url = $('input.url', this).val();
        
        if (url) {
          if (panel.elLk[this.rel]) {
            panel.toggleContent($(this), duration);
            window.location.hash = panel.elLk[this.rel][0].id;
          } else {
            panel.elLk[this.rel] = panel.addContent(url, this.rel);
          }
        }
      } else {
        panel.toggleContent($(this), duration);
        if (panel.elLk[this.rel] && $(this).hasClass('closed')) {
          if (panel.elLk[this.rel][0].id) {
            window.location.hash = panel.elLk[this.rel][0].id;
          }
        } else {
          // remove the hash from the url
          history.replaceState("", document.title, window.location.pathname + window.location.search);
        }
      }
      
      Ensembl.EventManager.trigger('toggleContent', this.rel, duration); // this toggles any other toggle switches used to toggle the same html block
      
      return false;
    }).filter('[rel]').each(function () {
      var cookie = Ensembl.cookie.get('toggle_' + this.rel);
      
      if ($(this).hasClass('closed')) {
        var regex = '[#?;&]' + this.rel + '(Panel)?[&;]*';
        
        if (cookie === 'open' || Ensembl.hash.match(new RegExp(regex))) {
          toTrigger[this.rel] = this; 
        }
      } else if ($(this).hasClass('open') && cookie === 'closed') {
        toTrigger[this.rel] = this;
      }
    });
    
    // Ensures that only one matching link with same rel is triggered (two triggers would revert to closed state)
    $.each(toTrigger, function () { $(this).trigger('click'); });
  },
  
  toggleContent: function (el, duration) {
    var rel       = el.attr('rel');
    var toggle    = duration ? 'slideToggle' : 'toggle';
    var link_html = el.html();
 
    if (!rel) {
      el.toggleClass('open closed').siblings('.toggleable')[toggle](duration);
    } else {
      if (this.id === rel + 'Panel') {
        this.el.find('.toggleable')[toggle](duration);
      } else {
        if (!this.elLk[rel]) {
          this.elLk[rel] = $('.' + rel, this.el);
        }
        
        if (!this.elLk[rel].find('.toggleable:first').addBack('.toggleable')[toggle](duration).length) {
          el.siblings('.toggleable')[toggle](duration);
        }
      }

      if (link_html.match(/Show/) && el.hasClass("toggle_link")) {
        el.html("Hide");
      } else if (link_html.match(/Hide/) && el.hasClass("toggle_link")) {
        el.html("Show");
      }
            
      if (el.hasClass('set_cookie')) {
        Ensembl.cookie.set('toggle_' + rel, el.hasClass('open') ? 'closed' : 'open');
      }
    }
    
    el = null;
  },
  
  hashChange: function () {
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (this.xhr) {
      this.xhr.abort();
      this.xhr = false;
    }
    
    this.getContent(Ensembl.replaceTimestamp(this.params.updateURL + ';hash_change=' + Ensembl.lastR));
  },
  
  hideHints: function () {
    this.elLk.hideHints.each(function () {
      var div = $(this);
      
      $('<img src="/i/close.png" alt="Hide" title="" />').on('click', function () {
        var tmp = [];
        
        div.hide();
        
        Ensembl.hideHints[div[0].id] = 1;
        
        for (var i in Ensembl.hideHints) {
          tmp.push(i);
        }
        
        Ensembl.cookie.set('ENSEMBL_HINTS', tmp.join(':'));
      }).prependTo(this.firstChild).helptip({ content: 'Hide this panel' });
    });
  },

  dataTable: function () {
    $.extend(this, Ensembl.DataTable);
    this.dataTableInit();
  },

  helpTips: function () {
    this.elLk.helpTips.helptip();
  },

  zMenuLink: function () {
    this.elLk.zMenuLink.zMenuLink();
  },

  wrapping: function () {
    this.elLk.wrapping.togglewrap();
  },
  
  selectToToggle: function() {
    this.elLk.selectToToggle.selectToToggle({}, this.el);
  },

  selectAll: function() {
    this.elLk.selectAll.on('change', function() {
      $(this).parents('div._selectall').find('input[type=checkbox]').prop('checked', this.checked);
    });
  },

  filterable: function() {
    this.elLk.filterable.filterableDropdown();
  },

  speciesDropdown: function() {
    this.elLk.speciesDropdown.speciesDropdown();
  },

  toggleButtons: function() {
    this.elLk.toggleButtons.toggleButtons();
  },

  redirectForm: function() {
    this.elLk.redirectForm.on('submit', function() {
      this.action = $(this).find('select[name=url]').val();
    });
  },

  newTable: function() {
    this.elLk.newTable.newTable();
  }
});
