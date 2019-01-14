// https://stackoverflow.com/a/25359264
$.urlParam = function(name){
    var results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href);
    if (results==null) {
        return null;
    }
    return decodeURI(results[1]) || 0;
}

var digraph;
var n_tasks_done = 0;
var n_tasks_total = 0;
function set_node_color_by_status(node_name, ticket_status) {
    var colour;
    if (ticket_status == null) {
        colour = "grey";
    } else if (ticket_status == "In Progress") {
        colour = "yellow";
    } else if (ticket_status == "Resolved") {
        colour = "DeepSkyBlue";
    } else if (ticket_status == "Closed") {
        colour = "grey";
    }
    if (colour != null) {
        digraph = digraph + '"' + node_name + '" [style="filled",fillcolor="' + colour + '"];\n';
    }
    n_tasks_done ++;
    update_progress_bar();
    if (n_tasks_done == n_tasks_total) {
        digraph += '}';
        //console.log("digraph final");
        //console.log(digraph);
        d3.select("#graph").graphviz()
            .fade(false)
            .renderDot(digraph);
        $('#progressbar').fadeOut("normal", function() {
            $(this).remove();
        });
    }
}

function update_progress_bar() {
    console.log(n_tasks_done);
    $('#progress').width(100*n_tasks_done/n_tasks_total + '%');
    if (n_tasks_done) {
        $('#progress').text(n_tasks_done + " / " + n_tasks_total + " tickets loaded");
    } else {
        $('#progress').text("");
    }
}

// fetch ticket status from REST API
var endpoint = 'https://www.ebi.ac.uk/panda/jira/rest/api/latest/issue';
var release = $.urlParam("release");
var division = $.urlParam("division");
$('#progress').text("Loading " + division + " e" + release + " graph");
$.ajax({
    type: "GET",
    url: "compara_" + division + "." + release + ".dot",
    dataType: "text",
    success: function(loaded_digraph) {
        console.log("digraph:", loaded_digraph);
        digraph = loaded_digraph.replace(/\}\s?$/g, '');
        $('#progress').text("Loading " + division + " e" + release + " ticket list");
        $.ajax({
            type: "GET",
            url: division + "_jira_tickets." + release + ".tsv",
            dataType: "text",
            success: function(tickets_txt) {
                var lines = tickets_txt.split('\n').filter(function (el) {
                    return el != "";
                });
                n_tasks_total = lines.length;
                update_progress_bar();
                for(var i = 0; i < lines.length; i++){
                    console.log("*" + lines[i] + "*");
                    var tab = lines[i].split('\t');
                    node_name = tab[0];
                    jira_id = tab[1];
                    console.log('ticket : ' + node_name + ", " + jira_id);

                    if ( jira_id == 'NOT_RUN' ) {
                        set_node_color_by_status(node_name, null);
                    } else {
                        $.ajax(endpoint + "/" + jira_id, {
                            success: function(node_name) { return function(json) {
                                console.log('json: ', json);
                                status_name = json.fields.status.name
                                console.log('this_status: ', status_name);
                                set_node_color_by_status(node_name, status_name);
                            }}(node_name),
                            error: function(jqXHR, status, error) {
                                console.log('Error: ' + (error || jqXHR.crossDomain && 'Cross-Origin Request Blocked' || 'Network issues'));
                                window.alert('Having trouble contacting Jira - please check that you are logged in');
                            },
                            crossDomain: true,
                        })
                    }
                }
            }
        });
    }
});
