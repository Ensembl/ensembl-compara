<!DOCTYPE html>
<meta charset="utf-8">
<head>
<?php
	# read basic diagraph from file
	$eg_dot_file = 'compara_plants.dot';
	$myfile = fopen($eg_dot_file, "r") or die("Unable to open $eg_dot_file");
	$eg_digraph = fread($myfile,filesize($eg_dot_file));
	fclose($myfile);
	$eg_digraph = preg_replace('/\s+/', ' ', $eg_digraph);
	$eg_digraph = preg_replace('/\}\s?$/', '', $eg_digraph);

	# load ticket mapping
	$eg_tickets = 'eg_jira_tickets.tsv';
	$ticketfh   = fopen($eg_tickets, "r") or die("Unable to open $eg_tickets");
	// $ticket_str = fread($ticketfh, filesize($eg_tickets));
	$ticket_map = array();
	$ticket_json = '{';
	while(!feof($ticketfh)) {
		$line = fgets($ticketfh);
		$line = preg_replace('/\s+$/', '', $line);
	  $parts = preg_split('/\t+/', $line);
	  // echo fgets($ticketfh) . "<br>";
	  // $ticket_map[$parts[0]] = $parts[1];
	  $node_name = $parts[0];
	  $jira_id   = $parts[1];

	  if ( $node_name == '' ) {
	  	continue;
	  }

	  $ticket_map[$node_name] = $jira_id;
	  $ticket_json = $ticket_json . '"' . $node_name . '":"' . $jira_id . '",';
	}
	$ticket_json = preg_replace('/\,+$/', '}', $ticket_json);
	// echo $ticket_json;
	// var_dump($ticket_map);
	// $encoded_ticket_map = json_encode($ticket_map);
	// echo $encoded_ticket_map;

?>
</head>
<body>
<script src="//d3js.org/d3.v4.min.js"></script>
<script src="https://unpkg.com/viz.js@1.8.0/viz.js" type="javascript/worker"></script>
<script src="https://unpkg.com/d3-graphviz@1.4.0/build/d3-graphviz.min.js"></script>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
<!-- <script
  src="https://code.jquery.com/jquery-2.2.4.min.js"
  integrity="sha256-BbhdlvQf/xTY9gja0Dq3HiwQF8LaCRTXxZKRutelT44="
  crossorigin="anonymous">
</script> -->
<div id="graph" style="text-align: center;"></div>
<p id="output"></p>
<script>
	// grab diagraph string from PHP and render with javascript
	var eg_digraph = '<?php echo $eg_digraph ?>';
	console.log(`eg_digraph: ${eg_digraph}`);

	// fetch ticket status from REST API
	var endpoint = '//www.ebi.ac.uk/panda/jira/rest/api/latest/issue';
	var tickets = '<?php //echo json_encode($ticket_map) ?>';// don't use quotes
	var tickets = <?php echo $ticket_json ?>;// don't use quotes
	// console.log(`tickets: ${tickets}`);
	$.each(tickets, function(node_name, jira_id) {
	    console.log('ticket : ' + node_name + ", " + jira_id);

	    if ( jira_id == 'NOT_RUN' ) {
	    	eg_digraph = `${eg_digraph} "${node_name}" [style="filled",fillcolor="grey"];`;
	    	return true; // equiv to perl's next 
	    }

	    $.ajax(`${endpoint}/${jira_id}`, {
	        success: function(json) {
		      console.log('json: ', json);
		      status_name = json.fields.status.name
		      console.log('this_status: ', status_name);
		      if ( status_name == 'In Progress' ) {
		      		eg_digraph = `${eg_digraph} "${node_name}" [style="filled",fillcolor="yellow"];`;
		      }
		      if ( status_name == 'Resolved' ) {
		      		eg_digraph = `${eg_digraph} "${node_name}" [style="filled",fillcolor="DeepSkyBlue"];`;
		      }
		      if ( status_name == 'Closed' ) {
		      		eg_digraph = `${eg_digraph} "${node_name}" [style="filled",fillcolor="grey"];`;
		      }
	        },
	        // error: function(json) {
	        //   console.log(`Error fetching ${endpoint}/${jira_id}?fields=status! ${json}`);
	        // }
	        error: function(jqXHR, status, error) {
		      console.log('Error: ' + (error || jqXHR.crossDomain && 'Cross-Origin Request Blocked' || 'Network issues'));
		      window.alert('Having trouble contacting Jira - please check that you are logged in');
		    },
		    async: false,
		    crossDomain: true,
	    })
	});

	eg_digraph += '}'
	console.log(`eg_digraph final: ${eg_digraph}`);

	d3.select("#graph").graphviz()
    	.fade(false)
    	.renderDot(eg_digraph);
</script>
