/**
 * helptip - Displays a helptip on hovering an element
 * Usage:
 * el.helptip('show this on hover', { 'static': true }); // create a helptip (or modifies an existing one)
 * el.helptip('');                                       // hides a helptip
 * el.helptip(false);                                    // completely removes any existing helptip from the element
 **/
(function ($) {
  $.helptip = function (tip, options) {
    var el  = $(this);
    options = $.extend({
      container:       'body',
      scrollContainer: $(window),
      eventIn:         'mouseenter',
      eventOut:        'mouseleave',
      delay:           100,
      callbacks:       {}
    }, options);
    
    var data = { coords: false };
    
    if (typeof tip === 'undefined' || tip === '') {
      tip = this.title;
    }
    
    var methods = {
      init: function () {
        var elData = el.data('helptip');
        
        if (elData) {
          data = $.extend(elData, data);
        }
        
        el.data('helptip', data);
        
        if (data.popup) {
          data.disabled = false; // if helptip already created
        } else {
          data.popup = $('<div class="helptip"><div class="helptip-inner"></div></div>').appendTo(options.container);
        }
        
        methods.setOption(); // set options
        
        tip = tip.replace(/\n/g, '<br />');
        
        if (el[0].title) {
          el[0].title = '';
        }
        
        if (tip) {
          methods.setTip(tip); // set tip
          
          if (options.show) {
            data.popup.show();
          }
        } else {
          methods.disable(el);
        }
        
        if (!data.initiated) {
          methods.setEventHandlers(); // set event handlers
        }
        
        if (typeof options.callbacks.init === 'function') {
          options.callbacks.init.call(this, el, data, options);
        }
      },
      
      setOption: function () {
        data.options = options;
        
        if (data['class']) { // previously added class
          data.popup.removeClass(data['class']);
        }
        
        if (options['class']) {
          data.popup.addClass(options['class']);
          data['class'] = options['class'];
        }
        
        data.popup.toggleClass('helptip-static', options['static']);
      },
      
      setTip: function (html) {
        data.popup.children().html(html).end().width(function (i, w) { return w; });
      },
      
      setEventHandlers: function (args) {
        args = $.extend({
          namespace: 'helptip',
          mouseIn:   methods.mouseIn,
          mouseOut:  methods.mouseOut
        }, args);
        
        var handlers = {};
        var func;
        
        if (options.delay) {
          handlers = { over: args.mouseIn, out: args.mouseOut, interval: options.delay, namespace: args.namespace };
          func     = 'hoverIntent';
          
          el.on('mousemove.helptip-track', args.mouseMove || function (e) {
            if (!data.mousemove) {
              data.coords = { x: e.pageX, y: e.pageY };
            }
          });
        } else {
          handlers[options.eventIn  + '.' + args.namespace] = args.mouseIn;
          handlers[options.eventOut + '.' + args.namespace] = args.mouseOut;
          
          func = 'on';
        }
        
        el[func](handlers);
        
        if (data.popup) {
          data.popup.on(options.eventOut + '.' + args.namespace, args.mouseOut);
        }
        
        if (args.namespace === 'helptip') {
          data.initiated = true;
        }
      },
      
      mouseIn: function (e) {
        var pos;
        
        if (options['static']) {
          var offset = options.container === 'body' ? el.offset() : el.position();
          pos = { x: offset.left + el.outerWidth() / 2, y: offset.top + el.outerHeight() / 2 };
        } else {
          pos = data.coords || { x: e.pageX, y: e.pageY };
          data.coords = false;
          
          if (!data.mousemove) {
            el.on('mousemove.helptip', methods.mouseMove);
            data.mousemove = true;
          }
        }
        
        var originalPos = $.extend(true, pos);
        
        if (options.fixed) {
          pos.x += options.scrollContainer.scrollLeft();
        } else {
          data.popup.removeClass('helptip-left helptip-top');
          
          if (options.scrollContainer.height() < ((pos.y - options.scrollContainer.scrollTop()) * 2)) {
            data.popup.addClass('helptip-top');
            pos.y -= data.popup.height();
          }
          
          if (options.scrollContainer.width() < ((pos.x - options.scrollContainer.scrollLeft()) * 2)) {
            data.popup.addClass('helptip-left');
            pos.x -= (data.offset || {}).width || data.popup.width();
          }
        }
        
        if (!data.disabled) {
          data.popup.css({ left: pos.x, top: pos.y }).show();
        }
        
        data.offset = { x: pos.x - originalPos.x, y: pos.y - originalPos.y, width: data.popup.width() };
      },
      
      mouseOut: function (e) {
        if (!(e.currentTarget === el[0] ? data.popup : el).find('*').andSelf().is(e.relatedTarget)) {
          data.popup.hide();
          el.off('mousemove.helptip');
          data.mousemove = false;
        }
      },
      
      mouseMove: function (e) {
        if (!data.disabled) {
          var offset = data.offset;
          data.popup.css({ left: offset.x + e.pageX, top: offset.y + e.pageY });
        }
      },
      
      disable: function () {
        data.disabled = true;
        data.popup.hide();
      },
      
      destroy: function () {
        el.off('.helptip .helptip-track');
        
        if (data.popup) {
          data.popup.remove();
          data.popup = null;
        }
        
        el.removeData('helptip');
        el = null;
      }
    };
    
    if (options.deferred) {
      if (options.delay) {
        el.on('mouseover.helptip-clearTitle', function () { $(this).off('mouseover.helptip-clearTitle')[0].title = ''; });
      }
      
      return methods.setEventHandlers({
        namespace: 'helptip-deferred',
        mouseMove: options['static'] ? $.noop : function (e) { data.coords = { x: e.pageX, y: e.pageY }; },
        mouseOut:  function ()  { el.off('.helptip-deferred'); },
        mouseIn:   function (e) {
          if (!data.coords) {
            data.coords = { x: e.pageX, y: e.pageY };
          }
          
          methods.init();
          methods.mouseIn();
        }
      });
    }
    
    // destroy any existing helptip instance if first argument is set false, else initialise
    methods[tip === false ? 'destroy' : 'init']();
  };

  $.fn.helptip = function (
    tip,    // text to be displayed on hover
    options // options - static, width (TODO)
  ) {
    if (typeof tip === 'object') {
      options = tip;
      tip     = '';
    }
    
    options = $.extend({ 'static': $('body').hasClass('ie6') }, options || {});
    return this.each(function () { $.helptip.call(this, tip, options); });
  };
})(jQuery);