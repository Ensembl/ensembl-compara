=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Search::Results;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Search);
use EnsEMBL::Web::Document::HTML::HomeSearch;

# --------------------------------------------------------------------
# An updated version of Summary.pm enabling: 
# - specification of the order the result categories are displayed in
# - more user friendly descriptions of the search categories. 
# - display of the search term above the results
#  NJ, Eagle Genomics
# Replaces UniSearch::Summary - ap5, Ensembl webteam
# --------------------------------------------------------------------

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $search = $self->object->Obj;
  my $html;

  if ($hub->species ne 'Multi' && $hub->param('q')) {
    if ($search->{total_hits} < 1) {
      $html = $self->no_results($hub->param('q'));
    }
    else {
      $html = "<p>Your search for <strong>" . $hub->param('q')  . "</strong> returned <strong>"
              .$search->{total_hits}."</strong> hits.</p>";
      $html .= "<p>Please note that because this site uses a direct MySQL search,  we limit the search to 10 results per category and search term, in order to avoid overloading the database server.";

      # Eagle change to order the results differently
      # we can either order the results by our own @order_results array, the species.ini files ( @idxs ), or just by sorting by keys as below. 	
      # ## Filter by configured indices

      # # These are the methods for the current species that we want to try and run
      # # The array is ordered in the way that they are listed in the .ini file
      # my @idxs = @{$hub->species_defs->ENSEMBL_SEARCH_IDXS};
	
      # the first value is the search method/species ini term. The second value is the display label.
      my @order_results = ( ['Gene', 'Gene or Gene Product' ], [ 'Marker', 'Genetic Marker']);
      if ($hub->species_defs->databases->{'DATABASE_FUNCGEN'}) {
        push @order_results,  [ 'OligoProbe', 'Array Probe Set' ];
      }
      if ($hub->species_defs->databases->{'DATABASE_VARIATION'}) {
        push @order_results, [ 'SNP', 'Variants'];
      }
      push @order_results, [ 'Domain', 'InterPro Domain'];
      if ($hub->species_defs->databases->{'COMPARA'}) {
        push @order_results, [ 'Family', 'Gene Family'];
      }
      push @order_results, (['GenomicAlignment', 'Sequence Aligned to Genome, eg. EST or Protein' ], [ 'Sequence', 'Genomic Region, eg. Clone or Contig' ], [ 'QTL', 'QTL' ]); 

      foreach my $search_ref ( @order_results ) {
        my $search_index = $search_ref->[0];
        my $display_term = $search_ref->[1]; 
        if ( $search->{'results'}{$search_index} ) { 
	        my( $results ) = @{ $search->{'results'}{$search_index} };
          my $count = scalar(@$results);
	        $html .= "<h3>$display_term</h3><p>$count entries matched your search strings.</p><ol>";
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
  }
  else {
    if ($hub->species eq 'Multi') {
     $html .= '<p class="space-below">Simple text search cannot be executed on all species at once. Please select a species from the dropdown list below and try again.</p>';
    }
    elsif (!$hub->param('q')) {
     $html .= '<p class="space-below">No query terms were entered. Please try again.</p>';
    }
    my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new($self->hub);
    $html .= $search->render
  }

  return $html;
}

1;
