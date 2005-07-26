#!/usr/local/bin/perl

BEGIN {
    if (defined($ENV{GO_ROOT})) {
	use lib "$ENV{GO_ROOT}/software";
    }
}

use CGI qw/:standard :netscape/;
use strict;
#use GO::CorbaClient::Session;
#use GO::CorbaClient::Session;
use GO::DatabaseLoader;
use GO::Parser;
use GO::AppHandle;
use GO::Browser::HTMLPlugin1;
use GO::Browser::HTMLFilter;
use GO::Browser::Tree;
use GO::Browser::Parents;
use Benchmark;

my @connect_params = (-dbname=>"go_suzi\@bdgp1");

#$ENV{DBMS}='mysql';
#$ENV{DBMS}=mysql;

my $acc = param('accession') || 3673;
my $depth = param('depth') || 2;
my $cgi = new CGI;
my $urlpost;


my $frame_name = path_info();
$frame_name =~ s!^/!!;
my $boolean=0;
my $accnum=0;
foreach my $name (param()) {
  if ($name ne 'search' && $name ne 'accession') {
    if ($boolean == 0) {
      $urlpost .= $name . '=' . param($name);
      $boolean = 1;
    } else {
      #if ($name ne 'accession' && $name ne 'search') {
      $urlpost .= '&' . $name . '=' . param($name);
    }
  }# elsif ($name eq 'accession') {
#    if ($accnum == 0 && $boolean == 0) {
#      $urlpost .= $name . '=' . param($name);
#      $accnum  = 1;
#      $boolean = 1;
#    } elsif ($accnum == 0 && $boolean == 1) {
#      $urlpost .= '&' . $name . '=' . param($name);
#      $accnum  = 1;
#    }
}



if (!$frame_name) {
  print_frameset();
  exit 0;
}


print_form() if $frame_name eq 'theform';
print_main() if $frame_name eq 'main';
print_term() if $frame_name eq 'term';
print_tree() if $frame_name eq 'tree';


sub print_frameset {
  my $script=url();
  print $cgi->header,
    $cgi->title('GO Browser'),
    $cgi->frameset({-rows=>'60,*', -framespacing=>0, -frameborder=>'no', -border=>0},
    $cgi->frame({-name=>'search', -src=>"$script/theform?accession=$acc&$urlpost"}),
    $cgi->frame({-name=>'main', -src=>"$script/main?accession=$acc&$urlpost"})
		  )
     ;
}

sub print_form {
  my $script=url();
  print $cgi->header; 
  print $cgi->title('GO Search'),
  $cgi->start_html(-bgcolor=>'#9bbad6'),
  $cgi->start_form(-action=>"$script/main", -target=>'main'),
  ' Enter a GO term - cap sensitive - * is the wildcard:  ',
  $cgi->textfield(-name=>'search'),
  '   Depth :  ',
  $cgi->radio_group(-name=>'depth', -value=>[1,2,3], -default=>2),
  '  ',
  $cgi->submit, 
  $cgi->end_form;
}

sub print_main {
  print $cgi->header;
  if (param('search')) { 
    eval {
      my $dbh = GO::AppHandle->connect(-dbname=>"go_suzi\@bdgp1");

      print $cgi->start_html(-bgcolor=>'white');
      my $html = new GO::Browser::HTMLFilter($urlpost);
      my $links = $html->search($dbh, param('search'));  
      print $links;
    }
  }
  else {
    my $script=url();
    print $cgi->title('GO Browser'),
    $cgi->frameset({-rows=>'35%,*', -framespacing=>0, -frameborder=>'no', -border=>0},
		   $cgi->frame({-name=>'term', -src=>"$script/term?accession=$acc&$urlpost"}),
		   $cgi->frame({-name=>'tree', -src=>"$script/tree?accession=$acc&$urlpost"})
		  );
  }
}


  
sub print_term {
  my $dbh = GO::AppHandle->connect(@connect_params);
  print header, start_html(-bgcolor=>'white');
  my $HTML = new GO::Browser::HTMLFilter($urlpost);
  my $HTMLString .= $HTML->draw_term($dbh, $acc);
  print $HTMLString;
}


sub print_tree {
  my $script=url();
  print header,
  start_html(-bgcolor=>'white');
  my $dbh = GO::AppHandle->connect(@connect_params);
  my $term = $dbh->get_term({acc=>$acc});
  my $ParentHTML;
  ### initialize a parents object
  my $par = GO::Browser::Parents->new($dbh);
  ###  populate the parent object
  my $parents = $par->set_parents($acc);
  if ($parents->[0][-1] > 0) {
    ###  Create a new "filter"
    my $filter= new GO::Browser::HTMLFilter();
    ###  Give the filter the parent tree and a plugin to get an html table.
    $ParentHTML=$filter->draw_parents($parents, 
					 new GO::Browser::HTMLPlugin1({urlpost=>$urlpost, rooturl=>"<a target=term href=$script/term"}) );
  } else {
    $ParentHTML = 'none';
  }

  
  ###  The same process is repeated with a descendants tree
  my $tre = GO::Browser::Tree->new($dbh);
  my $tree = $tre->build_tree({acc=>$acc, depth=>$depth});
  my $filter= new GO::Browser::HTMLFilter();


  my $TreeHTML = $filter->draw_tree($tree, $depth,
				    new GO::Browser::HTMLPlugin1({urlpost=>$urlpost, rooturl=>"<a target=term href=$script/term"}) );
  ### same thing for term - but we already have the term.
  my $filter= new GO::Browser::HTMLFilter();
  my $TermHTML = $filter->draw_selected_term($term,
				    new GO::Browser::HTMLPlugin1({urlpost=>$urlpost, rooturl=>"<a target=term href=$script/term"}) );
  ### and again for siblings.
  my $sibs = GO::Browser::Tree->new($dbh);
  my $sibsHTML;
  if ($parents->[0][-1] > 0) {
    my $siblings = $sibs->build_tree({acc=>$parents->[0][-1]->{acc}, depth=>1});
    my $filter = new GO::Browser::HTMLFilter();
    my $start = time;
    $sibsHTML = $filter->draw_tree($siblings, 1, new GO::Browser::HTMLPlugin1({urlpost=>$urlpost, rooturl=>"<a target=term href=$script/term"}), "sibs", $acc) ;
    my $end = time;
  } else {
    $sibsHTML="";
  }

  $TermHTML .= $sibsHTML;
  
  print $cgi->table({-border=>'', -valign=>'top'}, $cgi->Tr ( $cgi->td({-valign=>'top'}, [$ParentHTML] ), $cgi->td ({-valign=>'top'}, [$TermHTML] ), ( $cgi->td({-valign=>'top'}, [$TreeHTML]))));

}
