package Bio::EnsEMBL::GlyphSet::_user_data;
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
  my $title = sprintf "%s: %s; Start: %d; End: %d; Strand: %s",
    $self->my_config('caption'),
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

sub features {
  my ($self) = @_;
## Get the features from the URL or from the database...
  return unless $self->my_config('data_type') eq 'DnaAlignFeature';
  my $sub_type   = $self->my_config('sub_type');
warn ">>> $sub_type...";
  $self->{_default_colour} = $self->SUPER::my_colour( $sub_type );
warn ">>> $self->{_default_colour}";
  my $logic_name = $self->my_config('logic_name');

## Initialise the parser and set the region!
  my $dbs      = EnsEMBL::Web::DBSQL::DBConnection->new( $self->{'container'}{'web_species'} );
  my $dba      = $dbs->get_DBAdaptor('userdata');
  return ( $logic_name => [[]] ) unless $dba;

  my $dafa     = $dba->get_adaptor( 'DnaAlignFeature' );

  my $features = $dafa->fetch_all_by_Slice( $self->{'container'}, $logic_name );
  my %results  = ( $logic_name => [ $features||[] ] );
  return %results;
}

sub href {
### Links to /Location/Genome
  my( $self, $f ) = @_;
  my $href = $self->my_config('style')->{'url'};
  $href=~s/\$\$/$f->id/e;
  return $href;
}

sub colour_key {
  my( $self, $k ) = @_;
  return $k;
}

sub my_colour {
  my( $self, $k, $v ) = @_;

  my $c = $self->my_config('style')->{'color'} || $self->{_default_colour};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix( $c, 'white', 0 ) : $c;
}

1;

