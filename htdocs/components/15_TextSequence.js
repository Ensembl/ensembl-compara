/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.Panel.TextSequence = Ensembl.Panel.Content.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('dataTableRedraw', this, this.initPopups);
    Ensembl.EventManager.register('ajaxComplete',    this, this.sequenceKey);
    Ensembl.EventManager.register('getSequenceKey',  this, this.getSequenceKey);
  },
  
  init: function () {
    var panel = this;
    
    this.popups = {};
    this.zmenuId = 1;
    
    this.base();
    this.initPopups();
    
    if (!Ensembl.browser.ie) {
      $('pre > [title]', this.el).helptip({ track: true });
    }
    
    this.el.on('mousedown', '.info_popup', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
    }).on('click', '.info_popup .close', function () {
      $(this).parent().hide();
    }).on('click', 'pre a.sequence_info', function (e) {
        panel.makeZMenu(e, $(this));
        return false;
    });
  },
  
  initPopups: function () {
    var panel = this;
    
    $('.info_popup', this.el).hide();
    
    $('pre a.sequence_info', this.el).each(function () {
      if (!panel.popups[this.href]) {
        panel.popups[this.href] = 'zmenu_' + panel.id + '_' + (panel.zmenuId++);
      }
      
      $(this).data('menuId', panel.popups[this.href]); // Store a single reference <a> for all identical hrefs - don't duplicate the popups
    });
  },
  
  makeZMenu: function (e, el) {
    Ensembl.EventManager.trigger('makeZMenu', el.data('menuId'), { event: e, area: { a: el } });
  },
  
  sequenceKey: function () {
    $('.adornment',this.el).adorn();
    if (!$('.sequence_key', this.el).length) {
      var key = Ensembl.EventManager.trigger('getSequenceKey');
      
      if (!key) { 
        return;
      }
      
      var params = {};
      
      $.each(key, function (id, k) {
        $.extend(true, params, k);
      });
      
      var urlParams = $.extend({}, params, { variations: [], exons: [] });
      
      $.each([ 'variations', 'exons' ], function () {
        for (var p in params[this]) {
          urlParams[this].push(p);
        }
      });
      
      this.getContent(this.params.updateURL.replace(/sub_slice\?/, 'key?') + ';' + $.param(urlParams, true), this.el.parent().siblings('.sequence_key'));
    }
  },
  
  getSequenceKey: function () {
    Ensembl.EventManager.unregister('ajaxComplete', this);
    return JSON.parse($('.sequence_key_json', this.el).html() || false);
  }
});
