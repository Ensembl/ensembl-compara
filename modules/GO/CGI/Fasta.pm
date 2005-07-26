=head1 SYNOPSIS

package GO::CGI::Fasta

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

require GO::CGI::Fasta;
my $out = new FileHandle(">-");
$session->set_output($out);

GO::CGI::HTML->draw_tree(-session=>$session);

=head2 draw_tree

    Arguments  - GO::CGI::Session; 

Returns - formatted GO HTML browser page with tree view and query top-bar

=cut

package GO::CGI::Fasta;

use GO::IO::Fasta;
use GO::Utils qw(rearrange);
use strict;

sub drawFasta {
  my $self = shift;
  my ($session) = 
      rearrange([qw(session)], @_);

  my $out = $session->{'out'};

  my $writer = new GO::IO::Fasta(-output=>$out);
  $writer->header;
  my $product_list = $session->get_data();

  if (scalar(@{$product_list}) == 0) {
    print $out "Sorry, your selected sequences are not available.";
  } else {
    my %products;
    
    foreach my $product(@{$product_list}) {    
      $writer->drawFastaSeq($product);
    }
  }
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

  foreach my $term (@{$graph->focus_nodes}) {
    my $tl = $apph->get_terms_with_associations({acc=>$term->acc});
    foreach my $term (@$tl) {
      
      $gen->draw_term(-term=>$term, 
		      -graph=>$graph,
		      -show_associations=>'yes'
		     );
    }
  }
  $gen->end_document;
  
}
1;
