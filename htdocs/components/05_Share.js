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

Ensembl.Share = {
  shareInit: function (options) {
    var panel = this;
    
    this.shareOptions = $.extend({
      species: {},
      type: 'page',
      positionPopup: function (popup, link) {
        return popup.css({ top: $(link).offset().top + 1, left: this.el.outerWidth(true) });
      }
    }, options);
    
    this.elLk.shareLink = $('a.share', this.el).on('click', function () {
      if (!panel.elLk.share) {
        panel.elLk.share        = $('<div class="share_page info_popup"><span class="close"></span></div>').appendTo('body').css('left', panel.el.offset().left).data('loading', true);
        panel.elLk.shareSpinner = $('<div class="spinner"></div>').appendTo(panel.elLk.share);
        
        panel.share(this.href, this);
        
        panel.elLk.share.on('click', '.close, .cancel', function () {
          panel.elLk.share.hide();
        }).on('click', '.url', function () {
          $(this).select();
        });
        
        panel.elLk.shareLink.data('popup', panel.elLk.share);
      } else if (!panel.elLk.share.data('loading')) {
        panel.shareOptions.positionPopup.call(panel, panel.elLk.share, this).toggle();
      }
      
      return false;
    });
  },
  
  share: function (url, link) {
    var panel = this;
    
    if (!this.elLk.share) {
      return;
    }
    this.shareOptions.positionPopup.call(this, this.elLk.share, link);
    
    this.shareTimeout = setTimeout(function () {
      panel.elLk.share.add(panel.elLk.shareSpinner).show();
    }, 200);
    
    if (this.shareEnabled === false) {
      this.shareWaiting = true;
      return;
    }
    
    $.ajax({
      url: url,
      dataType: 'json',
      data: { species: JSON.stringify(this.shareOptions.species), hash: window.location.hash.replace('#', '') },
      success: function (json) {
        clearTimeout(panel.shareTimeout);
        
        panel.elLk.shareSpinner.hide();
        
        if (json.url) {
          json.url = $('<a>').attr('href', json.url).prop('href'); // in case protocol or domain is missing

          if (!$('.url', panel.elLk.share).val(json.url).add('.copy', panel.elLk.share).show().length) {
            panel.elLk.share.find('.fbutton').addClass('bottom-margin');
            panel.elLk.shareSpinner.before('<p class="copy">Copy this link:</p><input class="url" type="text" value="' + json.url + '" />');
          }
        } else if (json.confirmShare) {
          panel.elLk.shareSpinner.before(
            '<p>This ' + panel.shareOptions.type + ' is displaying some custom tracks.<br />Select which of these you\'d like to share:</p><ul>' +
            $.map(json.confirmShare, function (f) { return '<li><label>' + f[0] + '</label><input class="file" type="checkbox" value="' + f[1] + '" /></li>'; }).join('') +
            '</ul><input type="button" class="go fbutton" value="Accept" /><input type="button" class="cancel fbutton" value="Cancel" />'
          );
          
          $('.go', panel.elLk.share).on('click', function () {
            $('.url', panel.elLk.share).add('.copy', panel.elLk.share).hide();
            panel.elLk.shareSpinner.show();
            panel.share(url + ';custom_data=' + ($('.file', panel.elLk.share).map(function () { return this.checked ? this.value : undefined; }).toArray().join(',') || 'none'), link);
          });
        }
        
        panel.elLk.share.show().removeData('loading');
      },
      error: function () {
        panel.elLk.share.remove();
        delete panel.elLk.share;
      }
    });
  },
  
  removeShare: function () {
    if (this.elLk.share) {
      this.elLk.share.remove();
      delete this.elLk.share;
    }
  }
};
