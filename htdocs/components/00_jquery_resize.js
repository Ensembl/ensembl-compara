/* https://github.com/rbtbar/jquery-elementresize */
/* some fixes embedded by EnsEMBL team */
/*
The MIT License (MIT)

Copyright (c) 2014 Robert Bar

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/

(function (factory) {
    'use strict';
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof exports === 'object') {
        // Node/CommonJS style for Browserify/Webpack
        module.exports = factory(require('jquery'));
    } else {
        // Browser globals
        factory(jQuery);
    }
}(function ($) {    
    'use strict';
    var specialEventName = 'elementResize';
    
    function addDetector(elem) {
        if (!$.data(elem, specialEventName)) {
            $.data(elem, specialEventName, new ElementResizeDetector(elem));
        }        
    }
    
    function removeDetector(elem) {
        var detector = $.data(elem, specialEventName);
        
        if (detector) {
            detector.destroy();
            $.removeData(elem, specialEventName);
        }            
    }    

    function ElementResizeDetector(elem) {
        this.elem = elem;
        this.$elem = $(elem);
        this.activate();
    }

    $.extend(ElementResizeDetector.prototype, {
        activate: function () {
            var frameContent = '<!DOCTYPE html><html><head><title>jquery.elementResize</title></head><body><script>window.onresize = resize;function resize() { var detector = parent.$(this.frameElement).data("elementResize"); detector.trigger(); }</script></body></html>',
                iframes = [
                    $('<iframe src="about:blank" style="position:absolute; top:-50000px; left:0px; width:100%;"></iframe>'), 
                    $('<iframe src="about:blank" style="position:absolute; top:0; left:-50000px; height:100%;"></iframe>') 
                ];

            for (var index = 0; index < iframes.length; index++) {
                var $iframe = iframes[index];            
                this.$elem.append($iframe);
                $iframe.data(specialEventName, this);
                var id;
                id = setInterval(function() {
                  if($iframe[0].contentWindow) {
                    $iframe[0].contentWindow.emitcontent = frameContent;
                    clearInterval(id);
                  }
                },100);
                /* jshint -W107 */
                $iframe[0].src = 'javascript:window.emitcontent';
                /* jshint +W107 */
            }

            this.iFrameArray = iframes;
        },        

        destroy: function() {  
            for (var index = 0; index < this.iFrameArray.length; index++) {
                var $iframe = this.iFrameArray[index];
                $iframe.removeData(specialEventName);
                $iframe.remove();
            }
            this.iFrameArray = null;
            this.$elem = null;
            this.elem = null;
        },

        trigger: function() {
            this.$elem.elementResize();
        }
    });
    
    $.event.special[specialEventName] = {              
        version: '0.2.0',
        
        setup: function() {
            if (this.nodeType === 1) {
                addDetector(this);
            } else {
                throw new Error('Unsupported node type: ' + this.nodeType);
            }
        },
        
        teardown: function() {
             removeDetector(this);
        }
    }; 
    
    $.fn.extend({
        elementResize: function(fn) {
            return fn ? this.bind(specialEventName, fn) : this.trigger(specialEventName);
        },
        
        unelementResize: function(fn) {
            return this.unbind(specialEventName, fn);
        }
    });

}));
