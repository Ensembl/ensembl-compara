var id_to_update;
var status_id;

function start_periodic_updates(delay, update, ticket, status) {
  id_to_update = update;
  status_id = status;
  setInterval(update_queue_display, delay, ticket);
  update_queue_display(ticket);
}

function update_queue_display(ticket) {
  var url = "/Homo_sapiens/blast_update";

  var data;
  data = "ticket=" + ticket;

  var panelContent = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: response_received,
                           onLoading: loading
                         });
}

function response_received(response) {
  $(id_to_update).innerHTML = response.responseText; 
}

function loading(response) {
  $(status_id).innerHTML = "Checking Blast search queue...";
}
