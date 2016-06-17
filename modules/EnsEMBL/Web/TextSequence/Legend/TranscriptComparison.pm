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
