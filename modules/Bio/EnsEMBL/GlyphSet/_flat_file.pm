package Bio::EnsEMBL::GlyphSet::_flat_file;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub _das_link {
  my $self = shift;
  return undef;
}

sub feature_group {
  my( $self, $f ) = @_;
  return $f->id;
}

sub feature_label {
  my( $self, $f ) = @_;
  return $f->id;
}


sub draw_features {
  my ($self, $wiggle)= @_; 
 
  my %data = $self->features;
  return 0 unless keys %data;

  if ( $wiggle ){
    while (my ($key, $track) = each (%data)) {
      my ($features, $config) = @$track;
      my ($min_score,$max_score) = split(':', $config->{'viewLimits'});
      $min_score = $config->{'min_score'} unless $min_score;
      $max_score = $config->{'max_score'} unless $max_score;
      my $graph_type = $config->{'graphType'} || $config->{'useScore'};
      $self->draw_wiggle_plot(
        $features, { 
          'min_score' => $min_score, 'max_score' => $max_score, 
          'score_colour' => $config->{'color'}, 'axis_colour' => 'black',
          'description' => $config->{'description'}, 'graph_type' => $graph_type,
      });
    }
  }

 return 1;
}


sub features {
  my ($self) = @_;
  ## Get the features from the URL or session...
  my $sub_type = $self->my_config('sub_type');
  $self->{_default_colour} = $self->SUPER::my_colour( $sub_type );
## Initialise the parser and set the region!
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->{'config'}->species_defs);
  my $features = [];
  $parser->filter( $self->{'container'}->seq_region_name, $self->{'container'}->start, $self->{'container'}->end );
  $self->{'parser'} = $parser;
  if( $sub_type eq 'url' ) {
    my $data = EnsEMBL::Web::Tools::Misc::get_url_content($self->my_config('url') );
    $parser->parse($data);
  }
  else {
    my $file = new EnsEMBL::Web::TmpFile::Text( filename => $self->my_config('file') );
    return $self->errorTrack("The file ".$self->my_config('caption')." could not be found") if !$file->exists && $self->
strand < 0;

    my $data = $file->retrieve;
    return [] unless $data;

    $parser->parse($data, $self->my_config('format') );
  }

## Now we translate all the features to their rightful co-ordinates...
  my %results;

  my $sl = $self->{'container'};
  while (my ($key, $T) = each (%{$parser->{'tracks'}}) ) {
    foreach( @{$T->{'features'}}) {
      $_->map( $sl );
#      warn "$track_key -> ",$_->id," (",$_->start,":",$_->end,")\n";
    }
    $results{$key} = [$T->{'features'}, $T->{'config'}];
  }
  return %results;
}

our @strand_name = qw(- Forward Reverse);

sub feature_title {
  my( $self, $f, $db_name ) = @_;
  my $title = sprintf "%s: %s; Start: %d; End: %d; Strand: %s",
    $self->{'track_key'},
    $f->id,
    $f->seq_region_start,
    $f->seq_region_end,
    $strand_name[$f->seq_region_strand];

  $title .= '; Hit start: '.$f->hstart if $f->hstart;
  $title .= '; Hit end: '.$f->hend if $f->hend;
  $title .= '; Hit strand: '.$f->hstrand if $f->hstrand;
  $title .= '; Score: '.$f->score if $f->score;
  my %extra = $f->extra_data && ref($f->extra_data) eq 'HASH' ? %{$f->extra_data||{}} : ();
  foreach my $k ( sort keys %extra ) {
    next if $k eq '_type';
    $title .= "; $k: ".join( ', ', @{$extra{$k}} );
  }
  return $title;
}

sub href {
### Links to /Location/Genome
  my( $self, $f ) = @_;
  my $href = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'url'};
  $href=~s/\$\$/$f->id/e;
  return $href;
}

sub colour_key {
  my( $self, $k ) = @_;
  return $k;
}

sub my_colour {
  my( $self, $k, $v ) = @_;
  my $c = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'color'} || $self->{_default_colour};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix( $c, 'white', 0.8 ) : $c;
}

1;
