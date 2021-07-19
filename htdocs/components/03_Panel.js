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

Ensembl.Panel = Base.extend({  
  constructor: function (id, params) {
    if (typeof id !== 'undefined') {
      this.id = id;
    }
    
    this.params = typeof params === 'undefined' ? {} : params;
    
    this.initialised = false;
  },
  
  destructor: function (action) {
    var el;
    
    if (action === 'empty') {
      this.el.empty().off();
    } else if (action !== 'cleanup') {
      this.el.remove();
    }
    
    for (el in this.elLk) {
      this.elLk[el] = null;
    }
    
    this.el = null;
  },
  
  init: function () {
    var panel = this;
    
    if (this.initialised) {
      return false;
    }
    
    this.el = $('#' + this.id);
    
    if (!this.el.length) {
      throw new Error('Could not find ' + this.id + ', perhaps DOM is not ready');
    }
    
    this.elLk = {};
    
    $('input.js_param', this.el).each(function () {
      if (!panel.params[this.name]) {
        panel.params[this.name] = $(this).hasClass('json') ? JSON.parse(this.value) : this.value;
      }
    });
    
    this.initialised = true;
  },
  
  hide: function () {    
    this.el.hide();
  },
  
  show: function () {
    this.el.show();
  },
  
  height: function (h) {
    return this.el.height(h);
  },
  
  width: function (w) {
    return this.el.width(w);
  }
});
