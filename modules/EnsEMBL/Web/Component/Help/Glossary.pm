=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Help::Glossary;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::REST;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $ols     = $hub->species_defs->ENSEMBL_GLOSSARY_REST;
  my $html;

  if ($ols) {
    ## Use the new Ontology Lookup Service

    ## Embedded search
    #$html .= '<h2>Search for a term</h2>';

    ## Show table of terms
    my %glossary = $hub->species_defs->multiX('ENSEMBL_GLOSSARY');
    if (keys %glossary) {
      $html .= '<h2>Browse full list of terms</h2>';
      my $table = $self->new_table([
                                  {'key' => 'term', 'title' => 'Term'},
                                  {'key' => 'type', 'title' => 'Category'},
                                  {'key' => 'desc', 'title' => 'Description'},
                                  {'key' => 'more', 'title' => 'Read more'},
                                ], [], {'class' => 'padded-cell'});

      foreach my $term (sort { lc $a cmp lc $b } keys %glossary) {
        ## Show parent, to disambiguate similar terms
        my $entry = $glossary{$term};
        my $type;
        if ($entry->{'parents'}) {
          $type = join(', ', @{$entry->{'parents'}});
        }
        else {
          $type = '-';
        }

        ## Link to Wikipedia if available
        my $more = '';
        if ($entry->{'wiki'}) {
          $more = sprintf '<a href="%s">Wikipedia</a>', $entry->{'wiki'};
        }      

        $table->add_row({
                          'term' => $term, 
                          'type' => $type,
                          'desc' => $entry->{'desc'},
                          'more' => $more,
                        }); 
      }
      $html .= $table->render;
    }
  }

  return $html;
} 

1;
