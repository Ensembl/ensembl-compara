package Bio::EnsEMBL::GlyphSet::repeat_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;

@ISA = qw( Bio::EnsEMBL::GlyphSet_simple );

sub my_label { return "Repeats"; }

sub features {
  my $self = shift;
  my @features = sort { $a->seq_region_start <=> $b->seq_region_start } @{$self->{'container'}->get_all_RepeatFeatures()};
  return \@features;
}

sub zmenu {
  my( $self, $f ) = @_;

  my($start,$end) = $self->slice2sr( $f->start(), $f->end() );
  my $len   = $end - $start + 1;

  ### Possibly should not use $f->repeat_consensus->name.... was f->{'hid'}
  return {
	  'caption' => $f->repeat_consensus()->name(),
	  "bp: $start-$end" => '',
	  "length: $len"    => ''
    }
}

1;
