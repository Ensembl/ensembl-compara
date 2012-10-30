/*
 * JavaScript to dynamically change form action on the UserData upload page according to the option selected (or radio buttons checked)
 */

Ensembl.Panel.UserData = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    this.base();

    this.elLk.form          = this.el.find('form');
    this.elLk.actionInputs  = this.elLk.form.find(':input._action').each(function() {
      $(this).on('change', function() {

        var action;
        if (this.nodeName == 'SELECT') {
          var radio = panel.elLk.actionInputs.filter('input:visible:checked');
          if (radio.length) { // give priority to radio buttons if they are visible
            action = radio[0];
          } else {
            action = $(this).find('option:selected')[0];
          }
        } else if (this.checked) {
          action = this;
        }
        action = action ? (action.className.match(/(?:\s+|^)_action_([^\s]+)/) || []).pop() || '' : '';
        if (action) {
          panel.elLk.form.toggleClass('upload', action == 'upload').attr('action', panel.elLk.form.find('input[name=' + action + ']').val());
        }
      });
    });
  }
});