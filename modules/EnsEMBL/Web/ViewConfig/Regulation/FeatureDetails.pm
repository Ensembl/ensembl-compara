=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Regulation::FeatureDetails;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self     = shift;
  my $analyses = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'analyses'} || {};
  
  $self->set_defaults({    
    context     => 200,
    opt_focus   => 'yes',
    map {( "opt_ft_$_" => 'on' )} keys %$analyses
  });

  $self->add_image_config('reg_summary_page');
  $self->title = 'Summary';
}

sub form {
  my $self = shift;  
  
  $self->add_fieldset('Display options');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => 20,   caption => '20bp'   },
      { value => 50,   caption => '50bp'   },
      { value => 100,  caption => '100bp'  },
      { value => 200,  caption => '200bp'  },
      { value => 500,  caption => '500bp'  },
      { value => 1000, caption => '1000bp' },
      { value => 2000, caption => '2000bp' },
      { value => 5000, caption => '5000bp' }
    ]
  });
  
  $self->add_form_element({ type => 'YesNo', name => 'opt_focus', select => 'select', label => 'Show Core Evidence track' });
}

1;
