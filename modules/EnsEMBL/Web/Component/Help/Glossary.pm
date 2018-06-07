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
  my ($html, $table);

  if ($ols) {
    ## Use the new Ontology Lookup Service

    ## Embedded search
    #$html .= '<h2>Search for a term</h2>';

    ## Show table of terms
    my $rest = EnsEMBL::Web::REST->new($self->hub, $ols);
    if ($rest) {
      my $endpoint = 'terms?size=500';
      my ($response, $error) = $rest->fetch($endpoint);
      unless ($error) {
        $html .= '<h2>Browse full list of terms</h2>';
        my $terms    = $response->{'_embedded'}{'terms'};
        warn sprintf '<p>Found %s terms:</p>', scalar @{$terms||[]};
        #use Data::Dumper; $Data::Dumper::Sortkeys = 1;
        #warn Dumper($terms);
        $table = $self->new_table([
                {'key' => 'term', 'title' => 'Term'},
                {'key' => 'desc', 'title' => 'Description'},
              ]);

        foreach my $term (sort {$a->{'label'} cmp $b->{'label'}} @{$terms||[]}) {
          $table->add_row({'term' => $term->{'label'}, 'desc' => join(' ', @{$term->{'description'}||[]})}); 
        }
      }
    }
    else {
      my $site_url = $ols.'ontologies/ensemblglossary/';
      $html .= $self->_warning('REST error', qq(Could not contact EBI Ontology Lookup Service. Please try again later, or visit the <a href="$site_url">OLS website</a> to browse the ontology directly.));
    }
  }
  else {
    ## Fallback - get old glossary from database
    ## TODO - remove once OLS is completed
    my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
    my $words   = [];
    $table      = $self->new_twocol({'striped' => 1});

    if ($hub->param('word')) {
      $words = [$adaptor->fetch_glossary_by_word($hub->param('word'))];
    }
    elsif ($hub->param('id')) {
      $words = $adaptor->fetch_help_by_ids([ $hub->param('id') ]);
    }
    else {
      $words = $adaptor->fetch_glossary;
    }

    $table->add_row(
      $_->{'word'} . ( $_->{'expanded'} ? " ($_->{'expanded'})" : '' ),
      $_->{'meaning'}
    ) for @$words;
  }
  $html .= $table->render;

  return $html;
} 

1;
