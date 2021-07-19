=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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
  my $html    = '<div id="Glossary" class="js_panel">';

  if ($ols) {
    ## Use the new Ontology Lookup Service

    ## Embedded search
    $html .= '<input type="hidden" class="panel_type" value="Glossary">';
    $html .= '<h2>Search for a term</h2>';

    my $search = $hub->species_defs->OLS_REST_API.'search?ontology=ensemblglossary';

    my $form = $self->new_form({'class' => 'freeform _glossary_search', 'method' => 'get'});
    $form->add_field({'type' => 'String', 'name' => 'query'});
    $form->add_hidden({'name' => 'glossary_search_endpoint', 'value' => $search, 'class' => 'js_param' });
    $form->add_button({'type' => 'Submit', 'value' => 'Search', 'class' => '_rest_search'});
    $html .= $form->render;
    $html .= '<div class="_glossary_results hidden"></div>';

    ## Show table of terms
    my %glossary = $hub->species_defs->multiX('ENSEMBL_GLOSSARY');
    if (keys %glossary) {
      $html .= '<h2 class="top-margin">Browse full list of terms</h2>';
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

  $html .= '</div>';

  return $html;
} 

1;
