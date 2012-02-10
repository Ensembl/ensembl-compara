package Bio::EnsEMBL::GlyphSet::bigbed;

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

use Data::Dumper;

use EnsEMBL::Web::Text::Feature::BED;
use Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment Bio::EnsEMBL::GlyphSet_wiggle_and_block);

use Carp qw(cluck);

sub my_helplink { return "bigbed"; }

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
  return (); # No error
}

sub feature_group { $_[1]->id; }
sub feature_label { $_[1]->id; }

sub feature_title {
  my ($self,$f,$db_name) = @_;

  my @title = (
    [$self->{'track_key'}, $f->id],
    ["Start", $f->seq_region_start],
    ["End", $f->seq_region_end],
    ["Strand", ("-","Forward","Reverse")[$f->seq_region_strand]], # remember, [-1] = at end
    ["Hit start", $f->hstart],
    ["Hit end", $f->hend],
    ["Hit strand", $f->hstrand],
    ["Score", $f->score],
  );
  my %extra = $f->extra_data && ref($f->extra_data) eq 'HASH' ? %{$f->extra_data} : ();
  foreach my $k (sort keys %extra) {
    next if $k eq '_type' or $k eq 'item_colour';  
    push @title,[$k,join(", ",@{$extra{$k}})];
  }
  return join("; ",map { join(': ',@$_) } grep { $_->[1] } @title);
}


# XXX  WRONG
sub href {
  # Links to /Location/Genome

  my ($self,$f) = @_;

  my $href = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'url'};
  $href =~ s/\$\$/$f->id/e;
  return $href;
}

sub features {
  my ($self) = @_;

  my $slice = $self->{'container'};
  $self->{'_default_colour'} = $self->SUPER::my_colour($self->my_config('sub_type'));
  my $features = $self->bigbed_adaptor->fetch_features($slice->seq_region_name,$slice->start,$slice->end);
  $_->map($slice) for @$features;
  my $config = {};

  # Check if any scores present to enable score-based colouring
  if(grep { defined $_->score } @$features) {
    # A score: let's enable greyscale
    $config->{'useScore'} = 1;
    $config->{'implicit_colour'} = 1;
  } else {
    # No scores
  }

  if(grep {     defined $_->external_data 
            and defined $_->external_data->{'item_colour'} 
            and @{$_->external_data->{'item_colour'}} 
            and $_->external_data->{'item_colour'}->[0] } @$features) {

    foreach (@$features) {
      next if defined $_->external_data->{'item_colour'};
      $_->external_data->{'item_colour'} = $self->{'_default_colour'};
    }
    $config->{'itemRgb'} = 'on';

  }

  return( 
    'url' => [ $features, $config ],
  );
}
 
sub draw_features {
  my ($self,$wiggle) = @_;

  my @error;
  if($wiggle) {
    push @error,$self->_draw_wiggle();
  }
  return 0 unless @error;
  return join(" or ",@error);
}

sub render_text { warn "No text renderer for bigbed\n"; return ''; }


sub my_colour {
  my ($self, $k, $v) = @_;
  my $c = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'color'} || $self->{'_default_colour'};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix($c, 'white', 0.8) : $c;
}

1;

