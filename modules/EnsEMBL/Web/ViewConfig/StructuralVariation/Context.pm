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

package EnsEMBL::Web::ViewConfig::StructuralVariation::Context;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::ViewConfig);

sub init_cacheable {
  ## Abstract method implementation
  my $self     = shift;
  my %options  = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults = {'context' => 5000};

  foreach (keys %options) { ## TODO - defaults are being added but where are the corresponding fields?
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }

  $self->set_default_options($defaults);
  $self->image_config_type('structural_variation');
  $self->title('Genomic context');
}

sub field_order {
  ## Abstract method implementation
  return qw(context);
}

sub form_fields {
  ## Abstract method implementation
  return {
    'context' => {
      'fieldset'  => 'Display options',
      'type'      => 'DropDown',
      'name'      => 'context',
      'label'     => 'Context',
      'values'    => [
        { 'value' => 1000,  'caption' => '1kb'  },
        { 'value' => 5000,  'caption' => '5kb'  },
        { 'value' => 10000, 'caption' => '10kb' },
        { 'value' => 20000, 'caption' => '20kb' },
        { 'value' => 30000, 'caption' => '30kb' }
      ]
    }
  };
}

1;
