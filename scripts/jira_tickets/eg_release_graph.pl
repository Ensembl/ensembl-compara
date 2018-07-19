#!/usr/local/bin/perl

use strict;
use CGI qw(:standard);
use HTTP::Request;
# use JSON;
# use Net::SSL;
use LWP::UserAgent;
use Data::Dumper;

my $dot_file = 'compara_eg.dot';
my $jira_tickets = 'eg_jira_tickets.tsv';
# my $live_dot_file = 'compara_eg.live.dot';
# my $live_png_file = 'compara_eg.live.png';

print "Content-Type: text/html\n\n";
# print "<html><body><p>\n";

# system('pwd -P; ls');

# grab .dot file
open(DOT, '<', $dot_file) or die "Cannot open $dot_file";
my @dot_lines = <DOT>;
chomp @dot_lines;
@dot_lines = grep { length($_) > 0 } @dot_lines;
close DOT;

# # limit redrawing the image to twice per hour
# # check last modification time on png file
# my $should_redraw = 1;
# if ( -e $live_png_file ) {
# 	open(PNG, '<', $live_png_file);
# 	my $modtime = (stat(PNG))[9]; # value is in seconds
# 	$should_redraw = 0 if $modtime < 1800; # 1800s = 30m
# }

# if ( $should_redraw ) {
	# parse tickets
	my @tickets;
	open(JIRA, '<', $jira_tickets) or die "Cannot open $jira_tickets";
	while( my $line = <JIRA> ) {
		chomp $line;
		my ( $node_name, $jira_id ) = split("\t", $line);
		push( @tickets, [$node_name, $jira_id] );
	}
	close JIRA;

	# get ticket info and add graph colours
	my $endpoint = 'http://www.ebi.ac.uk/panda/jira/rest/api/latest/issue';
	foreach my $t ( @tickets ) {
		my ( $node_name, $jira_id ) = @$t;
		my $request = HTTP::Request->new(GET => "$endpoint/$jira_id?fields=status");
		$request->authorization_basic( 'anonymous' );
	    $request->header( 'Content-Type' => 'application/json' );

		# my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
		my $ua = LWP::UserAgent->new;
		my $response = $ua->request($request);
		my $content = $response->content();
		$content =~ s/,"statusCategory":\S+//g;
		print "$content<br>\n";
		# my $ticket = decode_json( $response->content() );
		# my $this_status = $ticket->{fields}->{status}->{name};
		$content =~ /"name":"([^"]+)"/;
		my $this_status = $1;
		print "$node_name status : $this_status<br>\n";
		if ( $this_status eq 'In Progress' ) {
			pop @dot_lines;
			my $node_style = '"' . $node_name . '" [style="filled",fillcolor="yellow"];';
			push( @dot_lines, $node_style, '}' );
		}
		elsif ( $this_status eq 'Resolved' || $this_status eq 'Closed' ) {
			pop @dot_lines;
			my $node_style = '"' . $node_name . '" [style="filled",fillcolor="DeepSkyBlue"];';
			push( @dot_lines, $node_style, '}' );
		}
	}

	my $dot = join('', @dot_lines);
	$dot =~ s/\s+/ /g;

# 	open(DOT, '>', $live_dot_file);
# 	print DOT $dot;
# 	close DOT;

# 	system("dot -Tpng -o $live_png_file $live_dot_file; chmod a+rx $live_png_file");
# }

# print generate_html_with_image($live_png_file);
print generate_html_with_digraph($dot);

sub generate_html_with_image {
	my $image_path = shift;

	my $html;
	# $html .= "Content-Type: text/html\n\n";
	$html .= "<!DOCTYPE html>\n";
	$html .= "<meta charset=\"utf-8\">\n";
	$html .= "<html> <body>\n";
	$html .= "<img src=\"$image_path\">\n";
	$html .= "</body> </html>\n";
	return $html;
}

sub generate_html_with_digraph {
	my $digraph_str = shift;
	my $html;
	# $html .= "Content-Type: text/html\n\n";
	$html .= "<!DOCTYPE html>\n";
	$html .= "<meta charset=\"utf-8\">\n";
	$html .= "<html> <body>\n";
	$html .= "<script src=\"//d3js.org/d3.v4.min.js\"></script>\n";
	$html .= "<script src=\"https://unpkg.com/viz.js\@1.8.0/viz.js\" type=\"javascript/worker\"></script>\n";
	$html .= "<script src=\"https://unpkg.com/d3-graphviz\@1.4.0/build/d3-graphviz.min.js\"></script>\n";
	$html .= "<div id=\"graph\" style=\"text-align: center;\"></div>\n";
	$html .= "<script>\n";
	$html .= "eg_digraph = '$digraph_str';\n\n";
	$html .= "console.log('eg_digraph:')\n";
	$html .= "console.log(eg_digraph);\n";
	$html .= "d3.select(\"#graph\").graphviz().fade(false).renderDot(eg_digraph);\n";
	$html .= "</script>\n";
	$html .= "</body> </html>\n";
	return $html;
}
