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

/*
 * EventLoop provides a way to do a non-blocking processing or DOM manipulation.
 * Example usage:
 *
 *  var obj = {
 *
 *    _run: function (arg1, arg2) { // private method
 *      // do something that blocks JS processing 
 *    },
 *
 *    run: function (arg1, arg2) {
 *
 *      // Example 1
 *      Ensembl.EventLoop.push({
 *        callback: this._run,
 *        arguments: [arg1, arg2],
 *        context: this
 *      }).execute();
 *
 *      // Example 2
 *      Ensembl.EventLoop.push({
 *        callback: function (arg1, arg2) {
 *          // do something that blocks JS processing
 *        },
 *        arguments: [arg1, arg2],
 *        context: this
 *      }).execute();
 *    }
 *  };
 */

Ensembl.EventLoop = {

  _queue: [],

  push: function (event) {
  /*
   * Pushes an event to the list of events to be executed after the current event loop
   * event - object with following properties:
   *   callback  - function to be called
   *   arguments - Array of arguments to be provided to the callback
   *   context   - Context to call the callback on
   */
    this._queue.push(event);
    return this;
  },

  execute: function (event) {
  /*
   * Executes all events present in the queue
   * event - same as accepted by EventLoop.push (optional - if provided, will push this event to the queue before executing all of them)
   */
    if (event) {
      this.push(event);
    }
    this._timeout = window.setTimeout(function () {
      var event = Ensembl.EventLoop._queue.shift();
      if (event) {
        event.method.apply(event.context, event.arguments);
        if (Ensembl.EventLoop._queue.length) {
          Ensembl.EventLoop.execute();
        }
      }
    }, 0);
    return this;
  },

  pause: function () {
  /*
   * Clears the current timeout to pause the execution
   */
    if (this._timeout) {
      window.clearTimeout(this._timeout);
    }
  },

  clear: function () {
  /*
   * Clears the current timeout and the remaining events from the queue
   */
    this.pause();
    this._queue = [];
  }
};
