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
    var form      = options.form;
    var iFrame    = null;
    var cloneForm = null;
    var name      = 'iframe' + $.now();
    
    // Function to revert all changes made to the page
    function cleanUp() {
      cloneForm.remove();
      iFrame.off('load').attr('src', 'javascript:false;').remove();
      cloneForm = iFrame = null;
    }
    
    // Remove 'iframe' from the datatypes list added by ajaxPrefilter so that further processing is based upon the dataType specified in options
    options.dataTypes.shift();
    
    // Use the iframe transport iff there are files that need to be uploaded
    if (form.find('input:file:enabled:not([value=""])').length) {
    
      // Clone the actual form (that will be submitted through iFrame), add required attributes to it, and add a hidden input for the server side to know about the request type
      cloneForm = form.clone().hide()
        .attr({action: options.url || form.attr('href'), target: name, enctype: 'multipart/form-data', method: 'POST'})
        .append($('<input>', {type: 'hidden', name: 'X-Requested-With', value: 'iframe'}));

      // In case there's an input in the form with name 'submit', it won't let the form to be submited via JS
      if (typeof cloneForm[0].submit !== 'function') {
        throw "Default submit() method seems to be missing for the form being submitted. Please make sure there's no field with name 'submit' in the form.";
      }
      
      // return the 'send' and 'abort' functions for this transport
      return {
      
        send: function(headers, completeCallback) {
          iFrame = $('<iframe>', {src :'javascript:false;', name: name, id: name, style: 'display:none'});
          
          // The first load event gets fired after the iframe has been injected into the DOM, and is used to prepare the actual submission.
          iFrame.on('load', function() {
          
            // The second load event gets fired when the response to the form submission is received.
            iFrame.off('load').on('load', function() {
              var doc   = this.contentWindow ? this.contentWindow.document : (this.contentDocument ? this.contentDocument : this.document);
              var root  = doc.documentElement || doc.body;
              cleanUp();
              completeCallback(200, 'OK', { html: root.innerHTML, text: root.textContent || root.innerText }, null);
            });
            
            // Now that the load handler has been set up, submit the form.
            cloneForm[0].submit();
          });
          
          // After everything has been set up correctly, the form and iframe get injected into the DOM so that the submission can be initiated.
          $('body').append(cloneForm, iFrame);
        },
        
        abort: function() {
          if (iFrame !== null) {
            cleanUp();
          }
        }
      };
    }
  });
})(jQuery);
