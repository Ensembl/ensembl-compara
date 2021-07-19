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

/*
 * This plugin adds the ability to jQuery.ajax to receive large responses in small chunks
 * and process them as soon as they are returned, instead of waiting for the whole response
 *
 * How to use?
 * -----------
 * Add these extra keys to the options provided to the ajax method
 *  comet: true // explicit flag to enable this
 *  update: function() {} // method that will be called everytime an update is recieved
 * (update is called to the context provided in context option, or window if missing context)
 *
 * How does it work?
 * -----------------
 * It uses iframe for the actual data transfer. The data is added as hidden fields to a hidden
 * form, and submitted with target set as an iframe. The update method provided by the user
 * is temporarily saved in window object to make it accessible from within the iframe. The
 * iframe response contains <script> tags with a call to that update method with required
 * resopnse as arguments, which causes the browser to call the update method without having
 * to wait for the whole response. Once the whole response is recieved, the success method
 * is called considering the contents of body tag as final response.
 * The backend needs to be compatible with this to send individual script tags as chunks.
 *
 * It is useful when the response is large, or the backend is doing lots of processing before
 * returning data chunks.
 *
 * TODOs
 * -----
 * Combine it with iframetransport to handle user form submissions with file field in them
 * Error handling
 */

(function($, undefined) {

  // Redirect the request to 'comet' dataType if comet key is set true
  $.ajaxPrefilter(function(options, origOptions, jqXHR) {
    if (options.comet) {
      return 'comet';
    }
  });

  // Add a transport for 'comet' dataType, to be used in case dataType is comet (as set by ajaxPrefilter)
  $.ajaxTransport('comet', function(options, origOptions, jqXHR) {
    var iFrame    = null;
    var forms     = null;
    var name      = 'cIframe_' + $.now();
    var methodKey = 'cUpdate';

    // Function to revert all changes made to the page
    function cleanUp() {
      $(form).remove();
      $(iFrame).off('load').attr('src', 'javascript:false;').remove();
      iFrame = form = null;
      delete window[methodKey][name];
    }

    // Remove 'comet' from the dataTypes list and let jquery parse the response based upon the originally provided dataType
    options.dataTypes.shift();

    // Add a temporary update method to the window to enable the iframe response to call that method from within it's <script> tags using parent syntax
    if (!window[methodKey]) {
      window[methodKey] = {};
    }
    window[methodKey][name] = function() {
      (options.update || $.noop).apply(options.context || window, arguments);
    }

    // Create a new form (that will be submitted via iFrame) and add required attributes to it
    form = $('<form>', (function(attrs) {
      if (attrs.method.match(/post/i)) {
        attrs.enctype = 'multipart/form-data';
      }
      return attrs;
    })({action: options.url, name: name, target: name, method: options.type || 'POST'}));

    // Convert data to a format as returned by serializeArray method
    var data = origOptions.data || [];
    if (!$.isArray(data)) {
      var dataArray = []
      if (!$.isPlainObject(data)) { // data is a string
        var dataObject = {};
        $.each(data.split('&|;'), function(i, val) {
          val = val.split('=');
          dataObject[val[0]] = decodeURIComponent(val[1].replace(/\+/g, '%20'));
        });
        data = dataObject;
        dataObject = null;
      }

      $.each(data, function(name, value) {
        dataArray.push({ name: name, value: value });
      });
      data = dataArray;
      dataArray = null;
    }

    // Add hidden inputs for all data params
    $.each($.merge([
      {name: 'X-Requested-With',  value: 'iframe'},
      {name: 'X-Comet-Request',   value: 'true'},
      {name: '_cupdate',          value: 'parent.' + methodKey + '.' + name}
    ], data), function(i, field) {
      $('<input type="hidden" />').attr(field).appendTo(form);
    });

    // Return the 'send' and 'abort' functions
    return {

      send: function(headers, completeCallback) {

        // The first load event gets fired after the iframe has been injected into the DOM, and is used to prepare the actual form submission.
        iFrame = $('<iframe name="' + name + '" id="' + name + '" src="javascript:false;" style="display:none">').on('load.initial', function() {

          // The second load event gets fired when the response to the form submission is received.
          // While the actual update is done via script tags in the iframe response, final 'success' method is called once complete response is recieved
          iFrame.off('load').on('load', function() {
            var body = $(this.contentWindow ? this.contentWindow.document : (this.contentDocument ? this.contentDocument : this.document)).find('body');
            cleanUp();
            completeCallback(200, 'OK', { html: body.html(), text: body.text() }, null);
          });

          // Now that the load handler has been set up, submit the form.
          form[0].submit();
        });

        // After everything has been set up correctly, inject the form and the iframe into the DOM so that the submission can be initiated.
        $('body').append(form, iFrame);

        // In case it doesn't trigger automatically (Firefox 49 bug)
        iFrame.triggerHandler('load.initial');
      },

      abort: cleanUp
    };
  });
})(jQuery);
