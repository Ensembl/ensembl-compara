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

Ensembl.Panel.TextSequence = Ensembl.Panel.Content.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('dataTableRedraw', this, this.initPopups);
  },
  
  init: function () {
    var panel = this;
    
    this.popups = {};
    Ensembl.Panel.TextSequence.zmenuId = 1;
    
    this.base();
    
    if (!Ensembl.browser.ie) {
      $('pre > [title]', this.el).helptip({ track: true });
    }
   
    $('.adornment',this.el).each(function() {
      var $this = $(this);
      $this.adorn(function(outer) {
        var $outer = $(outer);
        panel.initPopups($outer);
        panel.updateKey($outer);
        panel.fixKey($outer);
        if(!$('.ajax_pending',this.el).length &&
            !$('.ajax_load',this.el).length &&
            !$('.sequence_key img',this.el).length) {
//            panel.requestKey($this);
        }
      });
    });

    this.el.on('mousedown', '.info_popup', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
    }).on('click', '.info_popup .close', function () {
      $(this).parent().hide();
    }).on('click', 'pre a.sequence_info', function (e) {
        panel.makeZMenu(e, $(this));
        return false;
    });
  },
  
  updateKey: function(el) {
    var $mydata = $('.sequence_key_json',el);
    var mydata = JSON.parse($mydata.html()||false);
    if(!mydata) { return; }
    var $key = el.parents('.js_panel').find('.sequence_key');
    if(!$key.length) { return; }
    var alldata = $key.data('key') || {};
    $.extend(true,alldata,mydata);
    $key.data('key',alldata);
    var params = [];
    $.each(alldata,function(k,w) {
      if(k == 'variations' || k == 'exons') {
        $.each(w,function(v,i) { params.push(k+"="+v); });
      } else {
        params.push(k+'='+w);
      }
    });
    params.sort();
    var url = this.params.updateURL.replace(/sub_slice\?/,'key?'+';');
    url += params.join(';');
    $key.data('url',url);
  },

  fixKey: function(el) {
    el.parents('.js_panel').find('._adornment_key').first().keepOnPage({marginTop: 10, spaced: true}).keepOnPage('trigger');
  },

  requestKey: function(el) {
    var $key = el.parents('.js_panel').find('.sequence_key');
    if(!$key.length) { return; }
    this.getContent($key.data('url'),$key);
  },

  initPopups: function (el) {
    var keys = [];
    $('.info_popup',el).hide();
   
    $('pre a.sequence_info',el).each(function() {
      if (!keys[this.href]) {
        var zid = Ensembl.Panel.TextSequence.zmenuId++;
        keys[this.href] = 'zmenu_' + zid;
      }
      $(this).data('menuId', keys[this.href]); // Store a single reference <a> for all identical hrefs - don't duplicate the popups
    });
  },
  
  makeZMenu: function (e, el) {
    Ensembl.EventManager.trigger('makeZMenu', el.data('menuId'), { event: e, area: { link: el } });
  }
});
