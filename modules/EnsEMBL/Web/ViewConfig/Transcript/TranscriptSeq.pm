=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::TranscriptSeq;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    exons          => 'yes',
    codons         => 'yes',
    utr            => 'yes',
    coding_seq     => 'yes',
    translation    => 'yes',
    rna            => 'no',
    snp_display    => 'yes',
    line_numbering => 'sequence',
  });
  
  $self->title = 'cDNA sequence';
  $self->SUPER::init;
}

sub form {
  my $self = shift;

  $self->add_form_element({ type => 'YesNo', name => 'exons',       select => 'select', label => 'Show exons'            });
  $self->add_form_element({ type => 'YesNo', name => 'codons',      select => 'select', label => 'Show codons'           });
  $self->add_form_element({ type => 'YesNo', name => 'utr',         select => 'select', label => 'Show UTR'              });
  $self->add_form_element({ type => 'YesNo', name => 'coding_seq',  select => 'select', label => 'Show coding sequence'  });
  $self->add_form_element({ type => 'YesNo', name => 'translation', select => 'select', label => 'Show protein sequence' });
  $self->add_form_element({ type => 'YesNo', name => 'rna',         select => 'select', label => 'Show RNA features'     });
  $self->variation_options({ populations => [ 'fetch_all_HapMap_Populations', 'fetch_all_1KG_Populations' ], snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};
  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',
    name   => 'line_numbering',
    label  => 'Line numbering',
    values => [
      { value => 'sequence', caption => 'Yes' },
      { value => 'off',      caption => 'No'  },
    ]
  });
}

1;
