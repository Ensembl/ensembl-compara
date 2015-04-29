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

Ensembl.Panel.CloudMultiSelector = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id);
    this.urlParam = params.urlParam;
    this.params = params;

    this.selection = [];
    Ensembl.EventManager.register('updateConfiguration', this, this.updateSelection);
  },
 
  set_selection: function () {
    var panel = this;

    panel.selection = $.makeArray(
      $('.cloud_multi_selector_list li:not(.off)',panel.elLk.content).map(
        function(i,val) {
          return $(val).data('key');
        }
      )
    );

    if(panel.orig_selection) {
      panel.changed_on = [];
      panel.changed_off = [];
      var pend = {};
      $.each(panel.orig_selection,function(i,v) { pend[v] = 1; });
      $.each(panel.selection,function(i,v) {
        if(pend[v]) {
          delete pend[v];
        } else {
          panel.changed_on.push(v);
        }
      });
      $.each(pend,function(k,v) { panel.changed_off.push(k); });
      panel.changed = ( panel.changed_on.length||panel.changed_off.length );
    } else {
      panel.orig_selection = panel.selection;
      panel.changed = false;
    }
  },

  reset_selection: function () {
    delete this.orig_selection;
    this.set_selection();
  },
 
  init: function () {
    var panel = this;
    
    this.base();
    this.elLk.content = $('.modal_wrapper', this.el);
    this.elLk.list = $('.cloud_multi_selector_list li', this.elLk.content);
    this.elLk.filter = $('.cloud_filter input',this.el);
    this.elLk.clear = $('.cloud_filter_clear',this.el);
    this.elLk.all = $('.all',this.el);
    this.elLk.none = $('.none',this.el);

    panel.set_selection();
    $(panel.el).on('filter',function(e,val) {
      panel.elLk.list.each(function() {
        var $li = $(this);
        if($li.text().toLowerCase().indexOf(val.toLowerCase()) == 0) {
          $li.removeClass('hidden');
        } else {
          $li.addClass('hidden');
        }
      });
      if(val) { panel.elLk.clear.show(); } else { panel.elLk.clear.hide(); }
      panel.elLk.filter.focus();
    });
    this.elLk.list.click(function() {
      $(this).toggleClass('off');
      panel.set_selection();
      panel.elLk.filter.focus();
      return false;
    });
    this.elLk.all.click(function() {
      panel.elLk.list.removeClass('off');
      panel.set_selection();
      return false;
    });
    this.elLk.none.click(function() {
      panel.elLk.list.addClass('off');
      panel.set_selection();
      return false;
    });
    this.set_selection();
    this.val = '';
    panel.elLk.filter.val('');
    panel.elLk.clear.hide();
    this.elLk.filter.on({
      'keydown paste keyup mouseup blur': function(e) {
        var new_val = panel.elLk.filter.val();
        if(panel.val != new_val) {
          $(panel.el).trigger('filter',[new_val]);
          panel.val = new_val;
        }
      }
    }).focus();
    $(this.el).click(function() { panel.elLk.filter.focus(); });
    panel.elLk.clear.click(function() {
      panel.val = '';
      panel.elLk.filter.val('');
      $(panel.el).trigger('filter',['']);
    });
  }
});
