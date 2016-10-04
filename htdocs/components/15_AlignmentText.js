/*
 * Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.Panel.AlignmentText = Ensembl.Panel.Content.extend({
  constructor: function () {
    this.base.apply(this, arguments);
  },
  
  init: function () {
    var panel = this;
    this.base();

    var partial_alignment_panel;
    var full_alignment_panel;
    var message_text_partial = '';
    var message_text_full = '';

    /* On full display button click, create another TextSequence panel, 
       add ajax_load hidden htmls and then initiate to load content
    */
    $('div.display_full_message_div a', panel.el).on('click', function(e) {
      e.preventDefault();
      
      if (!message_text_partial) {
        message_text_partial = $(this).parent('.display_full_message_div').siblings('p').html();
      }
      if (!message_text_full) {
        message_text_full = 'Currently showing full alignment. Please click the button below to show the alignment for first ' + $(this).data('displayWidth') + ' columns.';
      }

      // Get TextSequence Panel
      if (!partial_alignment_panel) {
        var panels_arr = Ensembl.PanelManager.getPanels('TextSequence');
        partial_alignment_panel = panels_arr[0];
      }

      if ($(this).html() === 'Display full alignment') {
        $(this).html('Hide full alignment');
        $(this).closest('.message-pad').find('p:first-child').hide().html(message_text_full).fadeIn('slow');
        partial_alignment_panel && partial_alignment_panel.el.hide();
        full_alignment_panel && full_alignment_panel.el.fadeIn();
      }
      else {
        $(this).html('Display full alignment')
        $(this).closest('.message-pad').find('p:first-child').hide().html(message_text_partial).fadeIn('slow');
        full_alignment_panel && full_alignment_panel.el.hide();
        partial_alignment_panel && partial_alignment_panel.el.fadeIn();
      }

      if (!full_alignment_panel) {
        var params = new Object();
        Object.assign(params, $(this).data(), partial_alignment_panel.params);

        // Create a new TextSequence panel and generate ajax urls to get chunked content
        full_alignment_panel = Ensembl.EventManager.trigger('createPanel', 'full_alignment', 'TextSequence', params);

        var ajax_html = full_alignment_panel.showFullTextSequence($(this).data('totalLength'), $(this).data('chunkLength'), $(this).data('displayWidth'));
        full_alignment_panel.el.html(ajax_html);
        full_alignment_panel.init();
      }
    })
  }
});
