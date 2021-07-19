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

Ensembl.Panel.TextSequence = Ensembl.Panel.Content.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('dataTableRedraw', this, this.initPopups);
  },
  
  init: function () {
    var panel = this;
    this.base();
    
    if (!Ensembl.browser.ie) {
      $('pre > [title]', this.el).helptip({ track: true });
    }

    this.el.find('.adornment').each(function() {
      var $this = $(this);
      $this.adorn(function(outer) {
        var $outer = $(outer);
        panel.initPopups($outer);
        panel.updateKey($outer);
        panel.fixKey();
      });
    });

    // to make sure among multiple zmenu popup menus, the one that gets clicked comes on the top
    this.el.on('mousedown', '.info_popup', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
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

  fixKey: function() {
    if (!this.elLk.keyBox) {
      this.elLk.keyBox = this.el.parents('.js_panel').find('._adornment_key').first();
    }
    if (!this.elLk.keyBoxToggler) {
      this.elLk.keyBoxToggler = $('<div class="toggler"><span class="open">&#9660;</span><span>&#9650;</span></div>');
    }
    if (!this.elLk.keyBoxToggler.parent().length) {
      this.elLk.keyBoxToggler.appendTo(this.elLk.keyBox).off('.textsequence').on('click.textsequence', function() {
        $(this).parent().removeClass('was_collapsed').toggleClass('collapsed', 100);
      });
    }
    this.elLk.keyBox.keepOnPage({
      marginTop: 10,
      onreset: function() {
        $(this).removeClass('fixed').filter('.collapsed').removeClass('collapsed').addClass('was_collapsed');
      },
      onfix: function() {
        $(this).addClass('fixed').filter('.was_collapsed').removeClass('was_collapsed').addClass('collapsed');
      }
    }).keepOnPage('trigger');
  },

  initPopups: function (el) {
    el.find('.info_popup').hide();
    el.find('pre a.sequence_info:not(._zmenu_initalised)').zMenuLink().addClass('_zmenu_initalised');
  },

  getContent: function (url, el, params, newContent, attrs) {
    attrs = attrs || {};
    attrs.paced = true;

    if (this.elLk.keyBox) {
      this.elLk.keyBox.keepOnPage('destroy');
    }

    this.base(url, el, params, newContent, attrs);
  },

  // This is the client side replica of EnsEMBL::Web::Component::TextSequence::chunked_content()
  showFullTextSequence: function() {
    var panel = this;
    var i   = 1;
    var j   = panel.params.chunkLength;
    var end = (parseInt (panel.params.totalLength / j)) * j; // Find the final position covered by regular chunking - we will add the remainer once we get past this point.
    var url = '';
    var html = '';
      // The display is split into a managable number of sub slices, which will be processed in parallel by requests
      while (j <= panel.params.totalLength) {
        // Replace slice start and end w.r.t different chunks 
        url = panel.params.updateURL;
        url = url.replace(/subslice_start=(\d+);/, 'subslice_start=' + i + ';');
        url = url.replace(/subslice_end=(\d+);/, 'subslice_end=' + j + ';');
        url = url.replace(/follow=0/,'');
        url += ";follow=1";
        html += '<div class="ajax"><input type="hidden" class="ajax_load" value="'+ url +'" /></div>';

        if (j == panel.params.totalLength) break;
        i  = j + 1;
        j += panel.params.chunkLength;
        if (j > end) j  = panel.params.totalLength;
      }
    return html;
  }
});
