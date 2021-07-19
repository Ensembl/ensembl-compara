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

package EnsEMBL::Web::Factory::LRG;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self       = shift;
  my $db         = $self->param('db') || 'core'; 
  my $db_adaptor = $self->database($db);
  
  return $self->problem('fatal', 'Database Error', $self->_help("Could not connect to the $db database.")) unless $db_adaptor; 
	
  my $adaptor = $db_adaptor->get_SliceAdaptor;
  my $identifier;
  
  if ($identifier = $self->param('lrg')) {
    my $slice;
    
    eval { $slice = $adaptor->fetch_by_region('LRG', $identifier); }; ## Get the slice
    
    if ($slice) {
      $self->DataObjects($self->new_object('LRG', $slice, $self->__data));
    } else {
      $self->delete_param('lrg');
    }
  }
  elsif (!$self->hub->param('lrg') && $self->hub->action ne 'Genome') {
    return $self->problem('fatal', 'LRG ID required', $self->_help('An LRG ID is required to build this page.'))
  }
}

sub _help {
  my ($self, $string) = @_;
  my $help_text = $string ? sprintf '<p>%s</p>', encode_entities($string) : '';
  my $url       = $self->hub->url({ __clear => 1, action => 'Summary', lrg => 'LRG_1' });

  $help_text .= sprintf('
    <p>
      This view requires a LRG identifier in the URL. For example:
    </p>
    <div class="left-margin bottom-margin word-wrap"><a href="%s">%s</a></div>',
    encode_entities($url),
    encode_entities($self->species_defs->ENSEMBL_BASE_URL . $url)
  );

  return $help_text;
}

1;
