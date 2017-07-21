=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Transcript::Haplotypes;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self       = shift;
  my $defaults   = {
    show_variants    => 'off',
    filter_enabled   => 'off',
    filter_frequency => 0.01,
  };
  
  $self->set_default_options($defaults);
}

sub field_order {
  return qw(show_variants filter_enabled filter_frequency);
}

sub form_fields {
  my $self = shift;

  return {'show_variants' => {
                              type    => 'CheckBox',
                              label   => 'Show contributing variants in table',
                              name    => 'show_variants',
                              value   => 'on',
                              checked => 0,
                              class   => '_stt',
                              },
          'filter_enabled' => {
                              type    => 'CheckBox',
                              label   => 'Filter variants',
                              name    => 'filter_enabled',
                              value   => 'on',
                              checked => 0,
                              class   => '_stt',
                            },
          'filter_frequency' => {
                                  type  => 'string',
                                  label => 'Filter out variants with frequency less than',
                                  name  => 'filter_frequency',
                                  value => 0.01,
                                  field_class => '_stt_filter_enabled',
                                },
  };
}

1;
