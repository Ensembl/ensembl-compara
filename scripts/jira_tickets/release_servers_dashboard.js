
// fetch ticket status from REST API
var endpoint_ticket_list = 'https://www.ebi.ac.uk/panda/jira/rest/api/2/search/?jql=project=ENSCOMPARASW+AND+(description~"cp__SERVER__"+OR+description~"cp__SERVER__-w"+OR+description~"prod-__SERVER__"+OR+description~"prod-__SERVER__-ensadmin")+AND+status="In+progress"+ORDER+BY+created+ASC,id+ASC&maxResults=500';
var endpoint_ticket_query = 'https://www.ebi.ac.uk/panda/jira/rest/api/2/issue';
var url_jira_issue = 'https://www.ebi.ac.uk/panda/jira/browse/';

$('body').append('<h1>Server usage dashboard</h1>');

function process_ticket(ticket) {
    // The ticket information is as follows:
    //     summary [for division] (assignee)
    // NOTE: the part between brackets will be ommited if the field is null
    var ticket_info = ticket.fields.summary;
    if (ticket.fields.customfield_11130) {
        ticket_info += ' for ' + ticket.fields.customfield_11130.value;
    }
    ticket_info += ' (<i>' + ticket.fields.assignee.name + '</i>)';
    ticket_url = '<a href="https://www.ebi.ac.uk/panda/jira/browse/' + ticket.key + '">' + ticket_info + '</a>';
    return ticket_url;
}

function process_server(server) { return function(json) {
    var n_tickets = json.issues.length;
    var table = $('<table class="server_dashboard"></table>').appendTo('#cp' + server);
    table.append('<tbody><tr id="usage_cp' + server + '"><th>mysql-ens-compara-prod-' + server + '</th></tr>');
    if (n_tickets) {
        $('#usage_cp' + server).append('<td><div class="status_bar"><div class="yellow_light" style="width:100%"><i>busy</i></div></div></td>');
        var ticket_info = process_ticket(json.issues[0]);
        $('#usage_cp' + server).append('<td class="ticket_summary">' + ticket_info + '</td>');
        for (var i = 1; i < n_tickets; i++) {
            var ticket_info = process_ticket(json.issues[i]);
            table.append('<tr><th></th><td></td><td class="ticket_summary">' + ticket_info + '</td></tr>');
        }
    } else {
        $('#usage_cp' + server).append('<td><div class="status_bar"><div class="green_light" style="width:100%"><i>free</i></div></div></td><td class="ticket_summary"></td>');
    }
    table.append('</tbody>');
} }

for(var j = 1; j < 11; j++){
    var endpoint = endpoint_ticket_list.replace(/__SERVER__/g, j);
    console.log(endpoint);
    $('body').append('<div id="cp' + j + '"></div>');
    $.ajax(endpoint, {
        success: process_server(j),
        error: function(jqXHR, status, error) {
            console.log('Error: ' + (error || jqXHR.crossDomain && 'Cross-Origin Request Blocked' || 'Network issues'));
            window.alert('Having trouble contacting Jira - please check that you are logged in');
        },
        crossDomain: true,
    })
}
