package Bio::EnsEMBL::GlyphSet::_flat_file;
use strict;
use warnings;
no warnings 'uninitialized';
use Data::Dumper;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::Text;

sub _das_link {
  my $self = shift;
  return undef;
}

sub feature_group {
  my( $self, $f ) = @_;
  return $f->id;
}

our @strand_name = qw(- Forward Reverse);

sub feature_title {
  my( $self, $f, $db_name ) = @_;
  return sprintf "%s: %s; Start: %d; End: %d; Strand: %s",
    $self->{'track_key'},
    $f->id,
    $f->seq_region_start,
    $f->seq_region_end,
    $strand_name[$f->seq_region_strand]
}

sub features {
  my ($self) = @_;
## Get the features from the URL or from the database...
  my $sub_type = $self->my_config('subtype');
## Initialise the parser and set the region!
  my $parser = EnsEMBL::Web::Text::FeatureParser->new();
  my $features = [];
  $parser->set_filter( $self->{'container'}->seq_region_name, $self->{'container'}->start, $self->{'container'}->end );
  $self->{'parser'} = $parser;
  if( $sub_type eq 'url' ) {
    $parser->parse_URL( $self->my_config('url') );
  } else {
    my $file = new EnsEMBL::Web::File::Text( $self->species_defs, $self->my_config('file') );
    return [] unless $file;
    my $data = $file->retrieve;
    return [] unless $data;
    $parser->init($data);
    $parser->parse($data, $self->my_config('format') );
  }

## Now we translate all the features to their rightful co-ordinates...
  my %results;

  my $sl = $self->{'container'};
  foreach my $track_key ( sort keys %{$parser->{'tracks'}} ) {
    my $T = $parser->{'tracks'}{$track_key};
    foreach( @{$T->{'features'}}) {
      $_->map( $sl );
#      warn "$track_key -> ",$_->id," (",$_->start,":",$_->end,")\n";
    }
    $results{$track_key} = [$T->{'features'}];
  }
  return %results;
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
  return $v eq 'join' ? 'yellow' : $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'color'}||'red';
}

1;
