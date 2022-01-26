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

package EnsEMBL::Web::Factory::Regulation;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Factory);

sub createObjects {
  my $self       = shift;
  my $regulation = shift;
  my $rf;
  
  my $db = $self->species_defs->databases->{'DATABASE_FUNCGEN'};

  return $self->problem ('fatal', 'Database Error', 'There is no functional genomics database for this species.') unless $db;

  if (!$regulation) {
    my $db_adaptor = $self->database('funcgen');
    
    return $self->problem('fatal', 'Database Error', 'Could not connect to the functional genomics database.') unless $db_adaptor;
  
    $rf = $self->param('rf');
    
    return $self->problem('fatal', 'Regulatory Feature ID required', $self->_help('A regulatory feature ID is required to build this page.')) unless $rf;
  
    my $rf_adaptor = $db_adaptor->get_RegulatoryFeatureAdaptor;
    
    $regulation = $rf_adaptor->fetch_by_stable_id($rf);
    
    $self->param('fdb', 'funcgen');
  }
  
  if ($regulation) {
    my $context = $self->param('context') || 1000;
   
    my $obj = $self->new_object('Regulation', $regulation, $self->__data);
    $self->DataObjects($obj);
    $self->generate_object('Location', $regulation->feature_Slice->expand($context, $context));
  } else {
    return $self->problem('fatal', "Could not find regulatory feature $rf", $self->_help("Either $rf does not exist in the current Ensembl database, or there was a problem retrieving it."));
  }
}

sub _help {
  my ($self, $string) = @_;

  my %sample    = %{$self->species_defs->SAMPLE_DATA || {}};
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Summary', rf => $sample{'REGULATION_PARAM'} });
  
  $help_text .= sprintf('
  <p>
    This view requires a regulatory feature identifier in the URL. For example:
  </p>
  <div class="left-margin bottom-margin word-wrap"><a href="%s">%s</a></div>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url)
  );

  return $help_text;
}


1;

