// https://stackoverflow.com/a/25359264
$.urlParam = function(name){
    var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
    if (results==null) {
        return null;
    }
    return decodeURI(results[1]) || 0;
}

// https://stackoverflow.com/a/3291856
String.prototype.capitalize = function() {
    return this.charAt(0).toUpperCase() + this.slice(1);
}

// fetch ticket status from REST API
var endpoint_ticket_list = 'https://www.ebi.ac.uk/panda/jira/rest/api/2/search/?jql=project=ENSCOMPARASW+AND+issuetype=Task+AND+fixVersion="Release+__RELEASE__"+AND+component="Relco+tasks"+AND+cf[11130]=__DIVISION__+ORDER+BY+created+ASC,id+ASC&maxResults=500';
var endpoint_ticket_subtasks = 'https://www.ebi.ac.uk/panda/jira/rest/api/2/search/?jql=project=ENSCOMPARASW+AND+parent="__PARENT__"+ORDER+BY+created+ASC,id+ASC&maxResults=500';

var endpoint_ticket_query = 'https://www.ebi.ac.uk/panda/jira/rest/api/2/issue';
var url_jira_issue = 'https://www.ebi.ac.uk/panda/jira/browse/';
var release = $.urlParam("release");
var all_divisions = [ 'empty', 'Vertebrates', 'GRCh37', 'Metazoa', 'Plants', 'Protists', 'Fungi', 'Pan', 'Bacteria' ];

$('body').append('<h1>Release ' + release + ' dashboard</h1>');

function process_division(division) { return function(json) {
    //console.log('json: ', json);
    var n_tickets = json.issues.length;
    console.log(n_tickets);
    if (n_tickets == 0) {
        $('#' + division).prev('h2').remove();
        return;
    }
    var table = $('<table class="division_dashboard"></table>').appendTo('#' + division);
    for(var i =0; i<n_tickets; i++) {
        var ticket = json.issues[i];
        var summary = ticket.fields.summary;
        summary = summary.replace('Release ' + release, '');
        summary = summary.replace(division, '');
        table.append( '<tr id="' + ticket.key + '"><td>' + summary.trim().capitalize() + '</td><td><a href="' + url_jira_issue + ticket.key + '">' + ticket.key + '</a></td><td></td></tr>' );
        var endpoint = endpoint_ticket_subtasks.replace('__PARENT__', ticket.key);
        console.log(endpoint);
        $.ajax(endpoint, {
            success: process_task(ticket.key),
            error: function(jqXHR, status, error) {
                console.log('Error: ' + (error || jqXHR.crossDomain && 'Cross-Origin Request Blocked' || 'Network issues'));
                window.alert('Having trouble contacting Jira - please check that you are logged in');
            },
            crossDomain: true,
        })
    }

} }

function process_task(task) { return function(json) {
    console.log('json: ', json);
    var n_tickets = json.issues.length;
    //$('#' + task).append('<td>' + json.issues.length + '</td>');
    var n_done = 0;
    var n_in_progress = 0;
    var n_to_do = 0;
    for(var i =0; i<n_tickets; i++) {
        var ticket = json.issues[i];
        switch (ticket.fields.status.name) {
            case 'Resolved':    n_done ++; break;
            case 'Closed':      n_done ++; break;
            case 'In Progress': n_in_progress ++; break;
            default:            n_to_do ++; break;
        }
    }
    var prog = '';
    if (n_done) {
        prog += '<div class="back_jira_green" style="width:' + (100. * n_done / n_tickets) + '%"></div>';
    }
    if (n_in_progress) {
        prog += '<div class="back_jira_yellow" style="width:' + (100. * n_in_progress / n_tickets) + '%"></div>';
    }
    if (n_to_do) {
        prog += '<div class="back_jira_blue" style="width:' + (100. * n_to_do / n_tickets) + '%"></div>';
    }
    $('#' + task).append('<td><div class="task_progress_bar">' + prog + '</div></td>');
    $('#' + task).append('<td class="issue_count"><span class="jira_green">' + n_done + '</span> done,</td>');
    $('#' + task).append('<td class="issue_count"><span class="jira_yellow">' + n_in_progress + '</span> in progress,</td>');
    $('#' + task).append('<td class="issue_count"><span class="jira_blue">' + n_to_do + '</span> to do</td>');
} }

for(var j = 0; j < all_divisions.length; j++){
    var division = all_divisions[j];
    var endpoint = endpoint_ticket_list.replace('__RELEASE__', release).replace('__DIVISION__', division);
    console.log(endpoint);
    if (division.toLowerCase() != "empty") {
        $('body').append('<h2>' + division + '</h2>');
    }
    $('body').append('<div id="' + division + '"></div>');
    $.ajax(endpoint, {
        success: process_division(division),
        error: function(jqXHR, status, error) {
            console.log('Error: ' + (error || jqXHR.crossDomain && 'Cross-Origin Request Blocked' || 'Network issues'));
            window.alert('Having trouble contacting Jira - please check that you are logged in');
        },
        crossDomain: true,
    })
}

