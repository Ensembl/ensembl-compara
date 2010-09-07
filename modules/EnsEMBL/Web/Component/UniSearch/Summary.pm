package EnsEMBL::Web::Component::UniSearch::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);

# --------------------------------------------------------------------
# An updated version of Summary.pm enabling: 
# - specification of the order the result categories are displayed in
# - more user friendly descriptions of the search categories. 
# - display of the search term above the results
#  NJ, Eagle Genomics
# --------------------------------------------------------------------

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  if ($object->species eq 'Multi') {
    $html .= 'UniSearch cannot be executed on all species at once. Please resubmit your search from a species page.';
    return $html;
  }

  if ($object->param('q')) {
    $html = "<h2>Search Results for \'" . $object->Obj->{'q'}  . "\'</h2>";

    # Eagle change to order the results differently
    # we can either order the results by our own @order_results array, the species.ini files ( @idxs ), or just by sorting by keys as below. 	
    # ## Filter by configured indices
    # my $SD = EnsEMBL::Web::SpeciesDefs->new();

    # # These are the methods for the current species that we want to try and run
    # # The array is ordered in the way that they are listed in the .ini file
    # my @idxs = @{$SD->ENSEMBL_SEARCH_IDXS};
	
    # the first value is the search method/species ini term. The second value is the display label.
    my @order_results = ( ['Gene', 'Gene or Gene Product' ], [ 'Marker', 'Genetic Marker'], [ 'OligoProbe', 'Array Probe Set' ], [ 'SNP', 'SNP'], [ 'Domain', 'Interpro Domain'], [ 'Family', 'Gene Family'], ['GenomicAlignment', 'Sequence Aligned to Genome, eg. EST or Protein' ], [ 'Sequence', 'Genomic Region, eg. Clone or Contig' ], [ 'QTL', 'QTL' ]  ); 

    foreach my $search_ref ( @order_results ) {
      my $search_index = $search_ref->[0];
      my $display_term = $search_ref->[1]; 
#    foreach my $search_index ( sort keys %{$object->Obj->{'results'} } ) {
      if ( $object->Obj->{'results'}{$search_index} ) { 
	my( $results, $count ) = @{ $object->Obj->{'results'}{$search_index} };
	$html .= "<h3>Search results for $display_term</h3><p>$count entries matched your search strings.</p><ol>";
	foreach my $result ( @$results ) {
	  $html .= sprintf(qq(<li><strong>%s:</strong> <a href="%s">%s</a>),
			   $result->{'subtype'}, $result->{'URL'}, $result->{'ID'}
			 );
	  if( $result->{'URL_extra'} ) {
	    foreach my $E ( @{[$result->{'URL_extra'}]} ) {
	      $html .= sprintf(qq( [<a href="%s" title="%s">%s</a>]),
			       $E->[2], $E->[1], $E->[0]
			     );
	    }
	  }
	  if( $result->{'desc'} ) {
	    $html .= sprintf(qq(<br />%s), $result->{'desc'});
	  }
	  $html .= '</li>';
	}
	$html .= '</ol>';
      }
    }
  }
  else {
    my $species = $object->species || '';
    my $dir = $species ? '/'.$species : '';

    my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
    my $sp_name = $object->species_defs->DISPLAY_NAME || '';
    $html = qq(<h3>Search $sitename $sp_name</h3>);

    my $form = EnsEMBL::Web::Form->new( 'unisearch', "$dir/UniSearch/Summary", 'get' );

    $form->add_element(
      'type'    => 'String',
      'name'    => 'q',
      'label'   => 'Search for',
    );

    $form->add_element(
      'type'  => 'Hidden',
      'name'  => 'species',
      'value' => $species,
    );

    $form->add_element(
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Go',
    );

    $html .= $form->render;
  }

  return $html;
}

1;
