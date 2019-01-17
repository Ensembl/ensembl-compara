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

function get_node_color_for_jira_status(jira_status) {
    switch (jira_status) {
        case null          : return "grey";
        case "In Progress" : return "yellow";
        case "Resolved"    : return "DeepSkyBlue";
        case "Closed"      : return "grey";
        default            : return "white";        // Reported, Reopened
    }
}

function set_pipeline_run_color_by_status(pipeline_name, run_name, jira_status) {
    var colour = get_node_color_for_jira_status(jira_status);
    pipelines[pipeline_name].push( [run_name,colour] );
    n_tasks_done ++;
    update_progress_bar();
}

var digraph;
var n_tasks_done = 0;
var n_tasks_total = 0;
function update_progress_bar() {
    //console.log(n_tasks_done, " / ", n_tasks_total);
    $('#progress').width(100*n_tasks_done/n_tasks_total + '%');
    if (n_tasks_done) {
        $('#progress').text(n_tasks_done + " / " + n_tasks_total + " tickets loaded");
    } else {
        $('#progress').text("");
    }
    if (n_tasks_done == n_tasks_total) {
        for(pipeline_name in pipelines) {
            var runs = pipelines[pipeline_name];
            //console.log(runs);
            if (runs.length > 0) {
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
        }
        digraph += '}';
        //console.log("groups", pipelines);
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

function process_file(division) {
    return function(tickets_txt) {
        var lines = tickets_txt.split('\n').filter(function (el) {
            return el != "";
        });
        //console.log(lines.length, " tickets in ", division);
        n_tasks_total += lines.length;
        update_progress_bar();

        for(var i = 0; i < lines.length; i++){
            //console.log("*" + lines[i] + "*");
            var tab = lines[i].split('\t');
            var node_name = tab[0];
            var jira_id = tab[1];
            //console.log('ticket : ' + node_name + ", " + jira_id);

            var pipeline_name;
            var run_name;

            var index = node_name.indexOf(": ");
            if (index == -1) {
                pipeline_name = node_name;
                run_name = division.capitalize();
            } else {
                pipeline_name = node_name.substr(0, index);
                run_name = node_name.substr(index+2).capitalize();
            }
            if (!(pipeline_name in pipelines)) {
                alert("Cannot find " + pipeline_name + " in the graph");
                n_tasks_done++;
                update_progress_bar();
                continue;
            }

            var colour;
            if ( jira_id == 'NOT_RUN' ) {
                set_pipeline_run_color_by_status(pipeline_name, run_name, null);
            } else {
                colour = get_node_color_for_jira_status(run_name !== "Plants" ? "Resolved" : "In Progress");
                $.ajax(endpoint + "/" + jira_id, {
                    success: function(pipeline_name, run_name) { return function(json) {
                        //console.log('json: ', json);
                        var status_name = json.fields.status.name;
                        //console.log('this_status: ', status_name);
                        set_pipeline_run_color_by_status(pipeline_name, run_name, status_name);
                    }}(pipeline_name, run_name),
                    error: function(jqXHR, status, error) {
                        console.log('Error: ' + (error || jqXHR.crossDomain && 'Cross-Origin Request Blocked' || 'Network issues'));
                        window.alert('Having trouble contacting Jira - please check that you are logged in');
                    },
                    crossDomain: true,
                })
            }
            //console.log("groups", pipelines);
        }
        n_tasks_done++;
        update_progress_bar();
    }
}


// fetch ticket status from REST API
var endpoint = 'https://www.ebi.ac.uk/panda/jira/rest/api/latest/issue';
var release = $.urlParam("release");
var all_divisions = $.urlParam("divisions").split(",");
var pipelines = {};
n_tasks_total = all_divisions.length;
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
        for(var j = 0; j < all_divisions.length; j++){
            var division = all_divisions[j];
            $('#progress').text("Loading " + division + " e" + release + " ticket list");
            $.ajax({
                type: "GET",
                url: division + "_jira_tickets." + release + ".tsv",
                dataType: "text",
                success: process_file(division),
                error: function(jqXHR, status, error) {
                    // Presumably the file of this division is not available
                    update_progress_bar();
                },
            });
        }
    }
});
