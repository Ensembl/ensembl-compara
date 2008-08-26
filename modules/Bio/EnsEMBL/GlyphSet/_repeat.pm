package Bio::EnsEMBL::GlyphSet::_repeat;

use strict;
use base qw( Bio::EnsEMBL::GlyphSet_simple );

sub features {
  my $self = shift;
## Need to add code to restrict by logic_name and by db!

  my $types      = $self->my_config( 'types'      );
  my $logicnames = $self->my_config( 'logicnames' );

  my @repeats = sort { $a->seq_region_start <=> $b->seq_region_end }
                 map { my $t = $_; map { @{ $self->{'container'}->get_all_RepeatFeatures( $t, $_ ) } } @$types }
                @$logicnames;
  
  return \@repeats;
}

1 ;
