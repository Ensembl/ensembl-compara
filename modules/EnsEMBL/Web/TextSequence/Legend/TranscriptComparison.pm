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

package EnsEMBL::Web::TextSequence::Legend::TranscriptComparison;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Legend);

sub configured {
  my ($self,$config,$entry,$type,$m) = @_;

  return 1 if $type eq 'exons/Introns';
  return 0 if $type eq 'exons';
  return $self->SUPER::configured($config,$entry,$type,$m);
}

sub extra_keys {
  return {
    exons           => {},
    'exons/Introns' => {
      exon1   => { class => 'e1',     text => 'Translated sequence'  },
      eu      => { class => 'eu',     text => 'UTR'                  },
      intron  => { class => 'ei',     text => 'Intron'               },
      exon0   => { class => 'e0',     text => 'Non-coding exon'      },
      gene    => { class => 'eg',     text => 'Gene sequence'        },
    }
  };
}

1;
