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

/* The plugin adds the ability to the jQuery.ajax method to submit a form via iFrame in case there's any file input in the form
 * To make it work, add two extra keys to the argument provided to the ajax method: { iframe: true, form: $(form) }
 * Adapted from http://cmlenz.github.com/jquery-iframe-transport/
 */

(function($, undefined) {

  // Register a prefilter that checks whether the 'iframe' option is set, and switch to the 'iframe' datatype if it is 'true'.
  $.ajaxPrefilter(function(options, origOptions, jqXHR) {
    if (options.iframe) {
      return 'iframe';
    }
  });
  
  // Register a transport for the 'iframe' data type.
  $.ajaxTransport('iframe', function(options, origOptions, jqXHR) {
    var iFrame    = null;
    var form      = null;
    var files     = { originals: options.form.find('input:file:enabled:not([value=""])') };
    var name      = 'iframe' + $.now();
    
    // Function to revert all changes made to the page
    function cleanUp() {
      if (iFrame) {
        files.clones.replaceWith(function(i) { return files.originals[i]; });
        form.remove();
        iFrame.off('load').attr('src', 'javascript:false;').remove();
        form = iFrame = null;
      }
    }
    
    // Remove 'iframe' from the datatypes list added by ajaxPrefilter so that further processing is based upon the dataType specified in options
    options.dataTypes.shift();
    
    // Use the iframe transport iff there are files that need to be uploaded
    if (files.originals.length) {
    
      // Create a new form (that will be submitted through iFrame) and add required attributes to it
      form = $('<form>', {action: options.url || options.form.attr('href'), name: name, target: name, enctype: 'multipart/form-data', method: 'POST'});
      
      // Add hidden inputs corresponding to each input in original form and an extra one for the server side to know about the request type
      $.each($.merge([{name: 'X-Requested-With', value: 'iframe'}], options.form.serializeArray()), function(i, field) {
        $('<input type="hidden" />').attr(field).appendTo(form);
      });
      
      // Copy the actual file inputs to the new form, and leave the cloned file inputs in the actual form
      files.clones = files.originals.after(function() { return this.cloneNode(true); }).next();
      files.originals.appendTo(form);
      
      // return the 'send' and 'abort' functions for this transport
      return {
      
        send: function(headers, completeCallback) {
        
          // The first load event gets fired after the iframe has been injected into the DOM, and is used to prepare the actual submission.
          iFrame = $('<iframe name="' + name + '" id="' + name + '" src="javascript:false;" style="display:none">').on('load.initial', function() {
          
            // The second load event gets fired when the response to the form submission is received.
            iFrame.off('load').on('load', function() {
            
              var doc   = this.contentWindow ? this.contentWindow.document : (this.contentDocument ? this.contentDocument : this.document);
              var root  = doc.documentElement || doc.body;
              cleanUp();
              completeCallback(200, 'OK', { html: root.innerHTML, text: root.textContent || root.innerText }, null);
            });
            
            // Now that the load handler has been set up, submit the form.
            form[0].submit();
          });
          
          // After everything has been set up correctly, the form and the iframe get injected into the DOM so that the submission can be initiated.
          $('body').append(form, iFrame);

          // In case it doesn't trigger automatically (Firefox 49 bug)
          iFrame.triggerHandler('load.initial');
        },
        
        abort: function() {
          cleanUp();
        }
      };
    }
  });
})(jQuery);
