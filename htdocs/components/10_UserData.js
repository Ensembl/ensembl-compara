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

// JavaScript to dynamically change form action on the UserData upload page according to the option selected (or radio buttons checked) and do validation on the form

Ensembl.Panel.UserData = Ensembl.Panel.extend({
  formats: {
    'bam'  : 'BAM',
    'bb'   : 'BIGBED',
    'bcf'  : 'BCF',
    'bed'  : 'BED',
    'bgr'  : 'BEDGRAPH',
    'bw'   : 'BIGWIG',
    'cram' : 'CRAM',
    'gff'  : 'GTF',
    'gff3' : 'GFF3',
    'gtf'  : 'GTF',
    'psl'  : 'PSL',
    'vcf'  : 'VCF',
    'vep'  : 'VEP',
    'wig'  : 'WIG'
  },

  init: function () {
    var panel = this;

    this.base.apply(this, arguments);

    this.elLk.activeLink    = this.el.parents('.modal_wrapper').siblings('.modal_nav').find('ul.local_context li.active');
    this.elLk.form          = this.el.find('form').off('.UserData').on('submit.UserData', function (e) { e.preventDefault(); panel.formSubmit(); });

    this.elLk.formatDropdown = this.elLk.form.find('select[name=format]').on('change', function () {
      panel.showError();
    });

    var dataInputEvent = function(e) { // add some delay to make sure the blur event actually gets fired after making sure some other event hasn't removed the input string
      panel.showError();
      var element = $(this).off('blur change paste'); // prevent all events to fire at once
      setTimeout(function() {
        element.trigger('finish').trigger('blur').on('blur change paste', dataInputEvent);
        element = null;
      }, 100);
    };

    this.elLk.dataFieldText = this.elLk.form.find('._userdata_add textarea').on({
      'focus': function(e) {
        if (!this.value || this.value === this.defaultValue) {
          $(this).val('').removeClass('inactive');
        }
      },
      'finish': function() {
        this.value = this.value.trim();
        if (this.value && this.value !== this.defaultValue) {
          panel.updateFormatDropdown(this.value, false);
        } else {
          $(this).val(this.defaultValue).addClass('inactive');
          panel.resetFormatDropdown();
        }
      },
      'blur change paste': dataInputEvent
    });

    this.elLk.dataFieldFile = this.elLk.form.find('._userdata_add input[type=file]').on('change', function () {
      panel.updateFormatDropdown(this.value, true);
    });
  },

  updateFormatDropdown: function (data, isUpload) {

    var format;

    this.elLk[isUpload ? 'dataFieldText' : 'dataFieldFile'].val('').trigger('finish');

    if (!isUpload) {
      if (data.match(/^(ht|f)tp(s?)\:\/\//)) {
        if (data.match(/\/hub\.txt$/)) { // this is most likely a track hub (although there are more cases when it could be a trackhub)
          format = 'TRACKHUB'
        }
      } else {
        isUpload  = true;      // data being uploaded from the text area
        format    = 'unknown'; // could be anything, unless we have some code that guess the format
      }
    }

    if (!format) {
      format = this.formats[data.replace(/\.gz$/, '').split('.').pop().toLowerCase()];
    }

    this.elLk.formatDropdown.find('option').prop('disabled', function () {
      return !(isUpload ? !this.className.match('_format_remote') : !this.className.match('_format_upload'));
    }).filter(':first, [value=' + format + ']:enabled').last().prop('selected', true);
    // Finally, reveal the dropdown
    this.elLk.formatDropdown.removeClass('hide');
  },

  resetFormatDropdown: function () {
    if (!this.elLk.dataFieldFile.val() && (!this.elLk.dataFieldText.val() || this.elLk.dataFieldText.val() === this.elLk.dataFieldText.prop('defaultValue'))) {
      this.elLk.formatDropdown.find('option').prop('disabled', false).first().prop('selected', true);
    }
  },

  showError: function (message, el) {
    if (message) {
      if (!this.elLk.errorMessage) {
        this.elLk.errorMessage  = $('<label>').addClass('invalid');
      }
      this.elLk.errorMessage.html('&nbsp;' + message).insertAfter(el);
    } else {
      $(this.elLk.errorMessage).empty().remove();
    }
  },

  formSubmit: function () {
    if (!this.elLk.dataFieldFile.val() && (!this.elLk.dataFieldText.val() || this.elLk.dataFieldText.val() === this.elLk.dataFieldText.prop('defaultValue'))) {
      this.showError('Please provide some data', this.elLk.dataFieldText);
      return false;
    }

    if (!this.elLk.formatDropdown.val()) {
      this.showError('Please select a format', this.elLk.formatDropdown);
      return false;
    }

    this.showError();
    this.elLk.activeLink.removeClass('active');

    return Ensembl.EventManager.trigger('modalFormSubmit', this.elLk.form);
  }
});
