package Bio::EnsEMBL::GlyphSet::bigbed;

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

use Data::Dumper;

use Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub my_helplink { return "bigbed"; } # XXX check it's there and works

sub bigbed_adaptor {
  my $self = shift;

  my $url = $self->my_config('url');
  return $self->{'_cache'}->{'_bigbed_adaptor'} ||= Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor->new($url);
}

sub wiggle_features {
  my ($self,$bins) = @_;

  return $self->{'_cache'}->{'wiggle_features'} if exists $self->{'_cache'}->{'wiggle_features'};
 
  my $slice = $self->{'container'}; 
  my $summary_e = $self->bigbed_adaptor->fetch_extended_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins);
  my $binwidth = $slice->length/$bins;
  my $flip = ($slice->strand == 1) ? ($slice->length + 1) : undef;
  my @features;

  for(my $i=0; $i<$bins; $i++) {
    my $s = $summary_e->[$i];
    my $mean = 0;
    $mean = $s->{'sumData'}/$s->{'validCount'} if $s->{'validCount'} > 0;
    my ($a,$b) = ($i*$binwidth+1, ($i+1)*$binwidth);
    push @features,{
      start => $flip ? $flip - $b : $a,
      end => $flip ? $flip - $a : $b,
      score => $mean,
    };
  }
  
  return $self->{'_cache'}->{'wiggle_features'} = \@features;
}

sub _draw_wiggle {
  my ($self) = @_;

  my $slice = $self->{'container'};

  my $max_bins = min $self->{'config'}->image_width, $slice->length;
  my $features = $self->wiggle_features($max_bins);
  my @scores = map { $_->{'score'} } @$features;
 
  $self->draw_wiggle_plot(
    $features, {
      min_score => min(@scores),
      max_score => max(@scores),
      description => $self->my_config('caption'),
      score_colour => $self->my_config('colour'),
  }); 
  $self->draw_space_glyph();
  return ('error'); # No error
}

sub draw_features {
  my ($self,$wiggle) = @_;

  my @error;
  if($wiggle) {
    push @error,$self->_draw_wiggle();
  }
  return 0 unless @error;
  print STDERR @error;
  return join(" or ",@error);
}

sub render_text { warn "No text renderer for bigbed\n"; return ''; }

1;

