package Bio::EnsEMBL::GlyphSet::repeat_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;

@ISA = qw( Bio::EnsEMBL::GlyphSet_simple );

sub my_label { return "Repeats"; }

sub features {
  my $self = shift;
  return $self->{'container'}->get_all_RepeatFeatures(); # 'RepeatMask');
}

sub zmenu {
  my( $self, $f ) = @_;

  my $start = $f->start() + $self->{'container'}->start() - 1;
  my $end   = $f->end() + $self->{'container'}->start() - 1;
  my $len   = $end - $start + 1;
  

  ### Possibly should not use $f->repeat_consensus->name.... was f->{'hid'}
  return {
	  'caption' => $f->repeat_consensus()->name(),
	  "bp: $start-$end" => '',
	  "length: $len"    => ''
    }
}

1;
