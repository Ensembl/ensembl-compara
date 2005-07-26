=head1 SYNOPSIS

package GO::CGI::HTML

=head2  Usage

use FileHandle;
use GO::CGI::Query;
use GO::CGI::Session;
use CGI 'param';

my $q = new CGI;

my $session = new GO::CGI::Session(-q=>$q);

$session->cleanQueryValues();

my $params = $session->get_param_hash;

my $data = GO::CGI::Query->do_query(-session=>$session);
$session->set_data($data);

require GO::CGI::HTML;
my $out = new FileHandle(">-");
$session->set_output($out);

GO::CGI::HTML->draw_tree(-session=>$session);

=head2 draw_tree

    Arguments  - GO::CGI::Session; 

Returns - formatted GO HTML browser page with tree view and query top-bar

=cut

package GO::CGI::XML;

use GO::IO::XML;
use GO::Utils qw(rearrange);

sub drawTree {
  my $self = shift;
  my ($session) = 
      rearrange([qw(session)], @_);

  my $out = $session->{'out'};
  my $graph = $session->{'data'};

  my $gen = new GO::IO::XML(-output=>$out);


  $gen->xml_header;
  $gen->start_document();
  
  $gen->draw_node_graph(-graph=>$graph,
		       -show_xrefs=>'no');

  $gen->end_document;
  
}

sub drawDetails {
  my $self = shift;
  my ($session) = 
    rearrange([qw(session)], @_);
  
  my $apph = $session->apph;
  my $out = $session->{'out'};
  my $graph = $session->{'data'};
  
  my $gen = new GO::IO::XML(-output=>$out);

  $gen->xml_header;
  $gen->start_document();

  if ($session->get_param('search_constraint') eq 'terms') {
    foreach my $term (@{$graph->focus_nodes}) {
      my $tl = $apph->get_terms_with_associations({acc=>$term->acc});
      foreach my $term (@$tl) {
	
	$gen->draw_term(-term=>$term,
			-show_associations=>'yes'
		       );
      }
    }
  } else {
    foreach my $term(@$graph) {
      my $tl = $apph->get_terms_with_associations({acc=>$term->acc});
      foreach my $term (@$tl) {
	
	$gen->draw_term(-term=>$term,
			-show_associations=>'yes'
		       );
      }
    }
    
    
}
  $gen->end_document;
  
}


1;
