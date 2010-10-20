// $Revision$

Ensembl.Panel.AutoComplete = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.cache      = {};
    this.query      = false;
    this.reposition = false;
    this.focused    = false;
    
    Ensembl.EventManager.register('windowResize', this, this.resize);
    Ensembl.EventManager.register('mouseUp',      this, this.mouseUp);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.form  = $('form.autocomplete',  this.el);
    this.elLk.input = $('input.autocomplete', this.elLk.form).attr('autocomplete', 'off');
    this.elLk.g     = $('input[name=g]',      this.elLk.form);
    this.elLk.db    = $('input[name=db]',     this.elLk.form);
    this.elLk.list  = $('<ul>', { className: 'autocomplete', css: this.position() }).insertAfter(this.elLk.input);    
    
    // On gene form submit, stop the request going to psychic search if the user has selected a gene from the dropdown,
    // or has typed in something which matches (case insensitive) a name from the dropdown.
    this.elLk.form.bind('submit', function () {
      var form  = this;
      var g     = panel.elLk.g.val();
      var query = panel.elLk.input.val().toUpperCase();
      
      if (g) {
        this.action = window.location.pathname;
      } else {
        panel.elLk.list.find('span.name').each(function () {
          if ($(this).text().toUpperCase() == query) {
            form.action = window.location.pathname;
            panel.elLk.g.val($(this).siblings('.stable_id').text());
            return true;
          }
        });
      }
    });
    
    this.elLk.input.bind('keyup', function (e) {
      var value = this.value;
            
      // e.keyCode = 38: escape
      if (e.keyCode == 27) {
        panel.elLk.list.hide();
        return;
      }
      
      // e.keyCode = 38: up
      // e.keyCode = 40: down
      if (panel.elLk.list && (e.keyCode == 38 || e.keyCode == 40)) {
        panel.elLk.list.children().removeClass('focused');
        
        if (panel.focused) {
          if (!panel.focused[e.keyCode == 38 ? 'prev' : 'next']().trigger('mouseover', true).length) {
            panel.elLk.input.val(value);
          }
        } else {
          panel.elLk.list.children(e.keyCode == 38 ? ':last' : ':first').trigger('mouseover', true);
        }
        
        return;
      }
      
      // e.keyCode = 8:       backspace
      // e.keyCode = 32:      space
      // e.keyCode = 46:      delete
      // e.keyCode > 47:      alphanumeric/symbols
      // e.keyCode = 111-123: F keys
      if (
        value.length < 3 || 
        e.ctrlKey || e.altKey || 
        (e.keyCode < 46 && e.keyCode != 8 && e.keyCode != 32) || 
        (e.keyCode > 111 && e.keyCode < 124) || 
        value.match(/^\w+:\d+/)
      ) {
        return;
      }
      
      if (panel.reposition === true) {
        panel.elLk.list.css(panel.position());
      }
      
      // Clear timeout and abort xhr to stop ongoing requests and avoid conflicts
      if (panel.timer) {
        clearTimeout(panel.timer);
      }
      
      if (panel.xhr) {
        panel.xhr.abort();
        panel.xhr = false;
      }
      
      if (!panel.filter(value)) {
        panel.timer = setTimeout(function () {
          panel.xhr = $.ajax({
            url: Ensembl.speciesPath + '/autocomplete',
            data: { q: value },
            dataType: 'json',
            success: function (json) {
              panel.query = value;
              panel.cache[value] = json;
              
              panel.buildList(json);
              panel.filter(value); // Call filter again in case the user has typed more since the ajax request was made
            }
          });
        }, 100);
      }
    });
    
  },
  
  // Filter down existing results as the user types more
  // Returns false if a new search term has been entered (the user deleted back past the limit of the current query, and nothing in the cache matches the new query)
  filter: function (query) {
    var results = [];
    var cache   = (this.query && query.match('^' + this.query) ? this.cache[this.query] : this.cache[query]) || [];
    
    if (cache.length) {
      for (var i = 0; i < cache.length; i++) {
        if (cache[i][0].match('^' + query, 'i')) {
          results.push(cache[i]);
          
          if (results.length == 10) {
            break;
          }
        }
      }
      
      if (this.cache[query]) {
        this.query = query;
      }
      
      this.buildList(results);
      
      return true;
    } else {
      return false;
    }
  },
  
  buildList: function (results) {
    var panel = this;
    var lis   = [];
    var limit = results.length < 10 ? results.length : 10
    
    for (var i = 0; i < limit; i++) {
      lis.push('<li><span class="name">', results[i][0], '</span><span class="stable_id">', results[i][1], '</span><input type="hidden" class="db" value="', results[i][2], '" /></li>');
    }
    
    this.elLk.list.html(lis.join('')).find('li').bind({
      click: function () {
        panel.elLk.input.val($('.name', this).text());
        panel.elLk.g.val($('.stable_id', this).text());
        panel.elLk.db.val($('.db', this).val());
        panel.elLk.form.trigger('submit');
      },
      mouseover: function (e, keyPress) {
        $(this).siblings().removeClass('focused');
        
        panel.focused = $(this).addClass('focused');
        
        if (keyPress === true) {
          panel.elLk.input.val($('.name', this).text());
        }
      },
      mouseout: function () {
        $(this).removeClass('focused');
      }
    });
    
    this.elLk.list[results.length ? 'show' : 'hide']();
  },
  
  position: function () {
    var pos = this.elLk.input.position();
    
    return {
      top:   pos.top + this.elLk.input.innerHeight(),
      left:  pos.left,
      width: this.elLk.input.innerWidth()
    };
  },
  
  resize: function () {
    this.reposition = true;
    this.elLk.list.hide();
  },
  
  mouseUp: function () {
    this.elLk.list.hide();
  }
});
