package Bio::EnsEMBL::GlyphSet::repeat_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;

@ISA = qw( Bio::EnsEMBL::GlyphSet_simple_hash );

sub my_label { return "Repeats"; }

sub features {
  my $self = shift;
    
  my $max_length = $self->{'config'}->get('repeat_lite', 'threshold') || 2000;
  return $self->{'container'}->get_all_RepeatFeatures('RepeatMask');
}

sub zmenu {
  my( $self, $f ) = @_;

  my $start = $f->start() + $self->{'container'}->chr_start() - 1;
  my $end = $f->end() + $self->{'container'}->chr_end() - 1;
  my $len = $f->length();
  

  ### Possibly should not use $f->repeat_consensus->name.... was f->{'hid'}
  return {
	  'caption' => $f->repeat_consensus()->name(),
	  "bp: $start-$end" => '',
	  "length: $len"    => ''
    }
}

1;
