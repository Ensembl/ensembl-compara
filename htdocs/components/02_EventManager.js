/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

Ensembl.EventManager = {
  // The repository for all event data
  registry: {},

  // List of defered events that are waiting for an event to get registered before they get triggered
  deferred: {},
  
  /**
   * Registers a particular object as having an interest in a certain action
   */
  register: function (eventName, callObj, callFunc) {
    var callId = callObj.id;
    
    // if this is the first time an action is registered create space for it
    if (!this.registry[eventName]) {
      this.registry[eventName]       = {};
      this.registry[eventName].ref   = {};
      this.registry[eventName].count = 0;
    }
    
    // register the object and function references
    for (var id in this.getCallIds(callId)) {
      if (!this.registry[eventName].ref[id]) {
        this.registry[eventName].count++;
      }
      
      this.registry[eventName].ref[id]      = {};  
      this.registry[eventName].ref[id].func = callFunc;
      this.registry[eventName].ref[id].obj  = callObj;

      // if anything was defer-triggered, trigger it now for the new function
      if (this.deferred[eventName]) {
        for (var i = 0; i < this.deferred[eventName].length; i++) {
          this.triggerSpecific.apply(this, [eventName, id].concat(this.deferred[eventName][i]));
        }
      }
    }
  },
   
  /**
   * Removes the interest of an object from a specific action
   */ 
  unregister: function (eventName, callObj) {
    var callId = callObj.id;
    
    // Remove this items interest from this action
    if (this.registry[eventName] && this.registry[eventName].ref[callId]) {
      for (var id in this.getCallIds(callId)) {
        delete this.registry[eventName].ref[id];
        this.registry[eventName].count--;
      }
      
      this.deleteTest(eventName);
    }
  },
  
  /**
   * Finds all instances of an object and removes all references
   * Useful if an item is removed from the DOM and no longer has interest
   */ 
  remove: function (callId) {
    var eventName;
    
    for (eventName in this.registry) {
      if (this.registry[eventName].ref[callId]) {
        for (var id in this.getCallIds(callId)) {
          delete this.registry[eventName].ref[id];
          this.registry[eventName].count--;
        }
      }
      
      this.deleteTest(eventName);
    }    
  },
  
  /**
   * Returns an associative array whose keys are the ids required
   * Used to register/unregister correctly when the callId is in the form id1--id2
   */
  getCallIds: function (callId) {
    var ids = callId.split(/--/);
    var rtn = {};
    
    if (ids.length > 1) { ids.push(callId); }
    $.each(ids, function () { rtn[this] = 1; });
    
    return rtn;
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
    var args = [].slice.call(arguments, 1); // Make a copy of arguments, removing eventName
    var rtn  = {};
    var ids  = [];
    var id, r;
    
    if (this.registry[eventName]) {
      for (id in this.registry[eventName].ref) {
        r = this.registry[eventName].ref[id].func.apply(this.registry[eventName].ref[id].obj, args);
        
        if (typeof r !== 'undefined') {
          rtn[id] = r;
          ids.push(id);
        }
      }
    }
    
    if (ids.length === 1) {
      rtn = rtn[ids[0]];
    } else if (ids.length === 0) {
      rtn = undefined;
    }
    
    return rtn;
  },

  /**
   * Triggers the specified event if it's already registered, otherwise triggers it as soon as it gets registered
   */
  deferTrigger: function (eventName) {
    var args = [].slice.call(arguments, 1); // Make a copy of arguments, removing eventName

    if (!this.deferred[eventName]) {
      this.deferred[eventName] = [];
    }

    // save it in the deferred list for future event registrations
    this.deferred[eventName].push(args);

    if (this.registry[eventName]) {
      return this.trigger.apply(this, arguments);
    }
  },

  /**
   * Triggers the event on the specified id and calls all relevant functions
   */     
  triggerSpecific: function (eventName, id) {
    var args = [].slice.call(arguments, 2); // Make a copy of arguments, removing eventName and id
    
    if (this.registry[eventName] && this.registry[eventName].ref[id]) {
      return this.registry[eventName].ref[id].func.apply(this.registry[eventName].ref[id].obj, args);
    }
  }
};
