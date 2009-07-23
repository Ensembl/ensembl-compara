// $Revision$

Ensembl.EventManager = {
  // The repository for all event data
  registry: {},
  
  /**
   * Registers a particular object as having an interest in a certain action
   */
  register: function (eventName, callObj, callFunc) {
    var callId = callObj.id;
    
    // if this is the first time an action is registered create space for it
    if (!this.registry[eventName]) {
      this.registry[eventName] = {};
      this.registry[eventName].ref = {};
      this.registry[eventName].count = 0;
    }

    // currently an object can't register with the same action more than once.    
    if (this.registry[eventName].callId) { return false; }
    
    // register the object and function references
    this.registry[eventName].count++;
    this.registry[eventName].ref[callId] = {};  
    this.registry[eventName].ref[callId].func = callFunc;
    this.registry[eventName].ref[callId].obj = callObj;
  },
   
  /**
   * Removes the interest of an object from a specific action
   */ 
  unregister: function (eventName, callObj) {
    var callId = callObj.id;
    
    // Remove this items interest from this action
    if (this.registry[eventName] && this.registry[eventName].ref[callId]) {
      delete this.registry[eventName].ref[callId];
      this.registry[eventName].count--;
      this.deleteTest(eventName);
    }
  },
  
   /**
   * Finds all instances of an object and removes all references
   * Useful if an item is removed from the DOM and no longer has interest
   */ 
  remove: function (callObj) {
    var callId = callObj.id;
    var eventName;
    
    for (eventName in this.registry) {
      if (this.registry[eventName].ref[callId]) {
        delete this.registry[eventName].ref[callId];
        this.registry[eventName].count--;
      }
      
      this.deleteTest(eventName);
    }    
  },
  
  /**
   * Clears the specified action from the register, removes all interest
   */ 
  clear: function (eventName) {
    // Remove all interest of this action
    if (this.registry[eventName]) {
      delete this.registry[eventName];
    }
  },
  
  /**
   * Tests whether an event has any objects assigned to it, if it doesn't the Event is removed
   */ 
  deleteTest: function (eventName) {
    if (this.registry[eventName].count === 0) {
      delete this.registry[eventName];
    }
  },
    
  /**
   * Triggers the event specified and calls all relevant functions
   */     
  trigger: function (eventName) {
    var args = [];
    var i = arguments.length;
    var callId;
    var rtn = [];
    var r;
    
    if (this.registry[eventName]) {
      while (i--) {
        args[i] = arguments[i]; // Make a copy of arguments
      }
      
      for (callId in this.registry[eventName].ref) {
        r = this.registry[eventName].ref[callId].func.apply(
          this.registry[eventName].ref[callId].obj, args.slice(1, args.length) // remove eventName
        );
        
        if (typeof r != 'undefined') {
          rtn.push(r);
        }
      }
    }
    
    if (rtn.length == 1) {
      rtn = rtn[0];
    } else if (rtn.length === 0) {
      rtn = undefined;
    }
    
    return rtn;
  },
  
  /**
   * Triggers the event on the specified id and calls all relevant functions
   */     
  triggerSpecific: function (eventName, id) {
    var args = [];
    var i = arguments.length;
    
    if (this.registry[eventName] && this.registry[eventName].ref[id]) {
      while (i--) {
        args[i] = arguments[i]; // Make a copy of arguments
      }
      
      return this.registry[eventName].ref[id].func.apply(
        this.registry[eventName].ref[id].obj, args.slice(2, args.length)
      );
    }
  }
};
