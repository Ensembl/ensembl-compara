=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Variation::FlankingSequence;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  $self->SUPER::init;
  
  $self->set_defaults({
    flank_size      => 400,
    snp_display     => 'on',
    select_sequence => 'both',
  });

  $self->title = 'Flanking sequence';
}

sub field_order {
  my $self = shift;
  my @order = qw(flank_size select_sequence);
  push @order, $self->variation_fields;
  return @order;
}

sub form_fields {
  my $self            = shift;
  my $markup_options  = EnsEMBL::Web::Constants::MARKUP_OPTIONS;
  my $fields = {};
  
  $markup_options->{'flank_size'} = {
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Length of reference flanking sequence to display',
    name   => 'flank_size',
    values => [
      { value => '100',  caption => '100bp'  },
      { value => '200',  caption => '200bp'  },
      { value => '300',  caption => '300bp'  },
      { value => '400',  caption => '400bp'  },
      { value => '500',  caption => '500bp'  },
      { value => '1000', caption => '1000bp' },
    ]
  };  

  $markup_options->{'select_sequence'} = {
    type   => 'DropDown', 
    select => 'select',
    name   => 'select_sequence',
    label  => 'Sequence selection',
    values => [
      { value => 'both', caption => "Upstream and downstream sequences"   },
      { value => 'up',   caption => "Upstream sequence only (5')"   },
      { value => 'down', caption => "Downstream sequence only (3')" },
    ]
  };
  
  $self->add_variation_options($markup_options, 
                                {'label' => 'Show variations in flanking sequence',
                                 'snp_link' => 'no'}
                              ); 
  
  foreach ($self->field_order) {
    $fields->{$_} = $markup_options->{$_};
    $fields->{$_}{'value'} = $self->get($_);
  }

  return $fields;
}

1;
