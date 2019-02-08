// https://stackoverflow.com/a/25359264
$.urlParam = function(name){
    var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
    if (results==null) {
        return null;
    }
    return decodeURI(results[1]) || 0;
}

function get_node_color_for_jira_status(jira_status) {
    switch (jira_status) {
        case null          : return "grey";
        case "In Progress" : return "yellow";
        case "Resolved"    : return "DeepSkyBlue";
        case "Closed"      : return "grey";
        default            : return "white";        // Reported, Reopened
    }
}

var digraph;

function process_tickets(json) {
    var n_tickets = json.issues.length;
    //console.log(n_tickets);
    if (n_tickets == 0) {
        $('#progress').text("No tickets found !");
    }
    for(var i =0; i<n_tickets; i++) {
        var ticket = json.issues[i];
        var labels = ticket.fields.labels.filter(function (el) {
            return el.startsWith("Graph:");
        });
        if (labels.length == 0) {
            continue;
        }
        // Assume there is just 1 Graph label
        var label = labels[0].replace("Graph:", "").replace(/_/g, " ");

        var index = label.indexOf(":");
        if (index == -1) {
            pipeline_name = label.trim();
            run_name = ticket.fields.customfield_11130.value;
        } else {
            pipeline_name = label.substr(0, index).trim();
            run_name = label.substr(index+1).trim();
        }
        var matches;
        if (matches = ticket.fields.summary.match(/ batch \d+/)) {
            run_name += matches[0];
        }
        if (!(pipeline_name in pipelines)) {
            alert("Cannot find " + pipeline_name + " in the graph");
            continue;
        }

        var status_name = ticket.fields.status.name;
        var colour = get_node_color_for_jira_status(status_name);
        //console.log(pipeline_name, run_name, status_name, colour);
        pipelines[pipeline_name].push( [run_name,colour] );
    }

    for(pipeline_name in pipelines) {
        var runs = pipelines[pipeline_name];
        //console.log(runs);
        if (runs.length == 0) {
            continue;
        }
        var table_desc = '<table border="0" cellborder="0" cellspacing="0" cellpadding="1">';
        table_desc += '<tr><td><u>' + pipeline_name + '</u></td></tr><tr><td></td></tr>';
        var seen_colours = {};
        for(var i=0; i<runs.length; i++) {
            table_desc += '<tr><td bgcolor="' + runs[i][1] + '" port="' + runs[i][0] + '">' + runs[i][0] + '</td></tr>';
            seen_colours[runs[i][1]] = 1;
        }
        table_desc += '</table>';
        var seen_colours_array = Object.keys(seen_colours);
        var background_colour = seen_colours_array.length == 1 ? seen_colours_array[0] : 'white';
        var node_desc = "\"" + pipeline_name + '" [fillcolor="' + background_colour + '", label=<' + table_desc + '>, shape="box", style="rounded,filled"];';
        //console.log(pipeline_name, node_desc);
        digraph += node_desc + "\n";
    }
    digraph += '}';
    //console.log("groups", pipelines);
    //console.log("digraph final");
    //console.log(digraph);
    d3.select("#graph").graphviz()
        .fade(false)
        .renderDot(digraph);
    if (n_tickets) {
        $('#progressbar').fadeOut("normal", function() {
            $(this).remove();
        });
    }
}


// fetch ticket status from REST API
var endpoint_ticket_list = 'https://www.ebi.ac.uk/panda/jira/rest/api/2/search/?jql=project=ENSCOMPARASW+AND+fixVersion="Release+__RELEASE__"+AND+component+IN+("Relco+tasks","Production+tasks")+AND+labels+IS+NOT+EMPTY+ORDER+BY+created+ASC,id+ASC';
var release = $.urlParam("release");
var pipelines = {};
$('#progress').text("Loading e" + release + " graph");
$.ajax({
    type: "GET",
    url: "compara_merged." + release + ".dot",
    dataType: "text",
    success: function(loaded_digraph) {
        //console.log("digraph:", loaded_digraph);
        digraph = loaded_digraph.replace(/\}\s?$/g, '');
        // All the strings are considered potential pipeline names
        var all_pipeline_names = digraph.match(/"[a-zA-Z][^"]*"/g);
        for(var j = 0; j < all_pipeline_names.length; j++){
            var this_name = all_pipeline_names[j].substr(1, all_pipeline_names[j].length-2)
            pipelines[this_name] = [];
        }
        //console.log(all_pipeline_names);
        $('#progress').text("Loading all e" + release + " tickets");
        $.ajax({
            type: "GET",
            url: endpoint_ticket_list.replace('__RELEASE__', release),
            success: process_tickets,
            error: function(jqXHR, status, error) {
                $('#progress').text("Error fetching the " + release + "tickets: " + error);
            },
        });
    },
    error: function(jqXHR, status, error) {
        $('#progress').text("Error fetching the " + release + ".dot file: " + error);
    }
});

