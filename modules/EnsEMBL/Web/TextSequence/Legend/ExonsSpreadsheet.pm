package EnsEMBL::Web::TextSequence::Legend::ExonsSpreadsheet;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Legend);

sub extra_keys {
  return {
    'exons/Introns' => {
      exon0    => { class => 'e0', text => 'Non-coding exon'     },
      exon1    => { class => 'e1', text => 'Translated sequence' },
      intron   => { class => 'ei', text => 'Intron sequence'     },
      utr      => { class => 'eu', text => 'UTR'                 },
      flanking => { class => 'ef', text => 'Flanking sequence'   },
    }
  };
}

1;
