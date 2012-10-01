(function($) {
  var obj = {
    update: function (els) {
      $('.heightWrap', els).each(function () {
        var el    = $(this);
        var open  = el.hasClass('open');
        var val   = el.children();
        var empty = val.text() === '';
        
        if (open) {
          el.removeClass('open');
        }
        
        val[empty ? 'addClass' : 'removeClass']('empty');
        
        // check if content is hidden by overflow: hidden
        el.children('span.toggle_img')[el.height() < val.height() ? 'show' : 'hide']();
        
        if (open) {
          el.addClass('open');
          
          if (empty) {
            el.children('span.toggle_img').trigger('click');
          }
        }
        
        el = null;
      });
      
      els = null;
    },
    
    toggleblock: function($what) {
      return $what.parents().filter(function() {
          return $(this).css('display') != 'inline';
      }).first();

    },
    
    remember_size: function($what) {
      if(!$what.hasClass('toggle_img')) {
        $what = $('.toggle_img',$what);
      }
      var $fix = $what.parents('.toggleblock');
      if(!$fix.length) {
        $fix = obj.toggleblock($what.parents('.toggle_div'));
      }
      $fix.data('fix-width',$fix.width());
    },
    
    toggle: function($what) {
      obj.remember_size($what);       
      $what.toggleClass('open').parents().first().toggleClass('open');
    },
    
    // duty_cycle: do as many as possible at same time but don't cause delays
    duty_cycle_step: function(num,action,done,more) {
      var timeout = 1;
      if(more) {
        var start = new Date().getTime();
        var ret = action(num);
        var end = new Date().getTime();
        if(!ret) {
          if(done)
            done();
          return;
        }
        var actual = end-start;
        if(actual > 100) { num /= 2; }
        if(actual < 25)  { num *= 2; }
        timeout = Math.min(actual * 10,2000);
      }
      setTimeout(function() { obj.duty_cycle_step(num,action,done,1); },timeout);
    },

    duty_cycle: function(jq,action,done) {
      var start = 0;
      obj.duty_cycle_step(1,function(times) {
        jq.slice(start,start+times).each(action);
        start += times;
        return start < jq.length && jq.length;
      },done);
    },

    remember_sizes: function(table,done) {
      obj.duty_cycle($('.toggle_div',table),function($slice) {
        obj.remember_size($(this));
      },done);
    },

    are_summaries_superfluous: function(table,done) {
      obj.duty_cycle($('.toggle_div',table),function($slice) {
        $(this).data('inner-width',$('.cell_detail',this).width());
        $(this).data('summary-width',$('.toggle_summary',this).width());
      },done);
    },

    remove_superfluous_summaries: function(table) {
      obj.duty_cycle($('.toggle_div',table),function($slice) {
        var $cell = $(this);
        var width = obj.toggleblock($cell).data('fix-width')-16;
        if($cell.data('inner-width') < width) {
          $cell.replaceWith($('.cell_detail',$cell).removeClass('cell_detail'));
        } else if(width > $cell.data('summary-width')+100) {
          $('span.toggle-img',$cell).addClass('limpet');
        }        
      });
    },

    init: function(what,options) {
      var settings = { // no settings for now
      };
      $.extend(settings,options);
            
      return what.andSelf().find('.heightwrap_inside,.cellwrap_inside').each(function() {
        var table = $(this);

        if(table.css('table-layout') !== 'fixed') {
          $('th,td',table).each(function() {
            $(this).width($(this).width());
          });
          table.css('table-layout','fixed');
        }
        
        $('<span class="toggle_img"/>').appendTo($('.heightWrap',table));
        $(window).resize(function() { obj.update(table); });
        obj.update(table);
        table.off('click','span.toggle_img');
        table.on('click','span.toggle_img', function() {
          obj.toggle($(this));
          return false;
        });
        obj.remember_sizes(table,function() {
          obj.are_summaries_superfluous(table,function() {
            obj.remove_superfluous_summaries(table);
          });
        });
      });
    }
  };

  $.fn.togglewrap = function(arg) {
    if(arg === 'update') {
      // update
      obj.update(this);
    } else {
      // initialise
      obj.init(this,arg);
    }
  };
})(jQuery);
