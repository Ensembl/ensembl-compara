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
  return sprintf "%s: %s; Start: %d; End: %d; Strand: %s",
    $self->my_config('caption'),
    $f->id,
    $f->seq_region_start,
    $f->seq_region_end,
    $strand_name[$f->seq_region_strand];
}

sub features {
  my ($self) = @_;
## Get the features from the URL or from the database...
  return unless $self->my_config('data_type') eq 'DnaAlignFeature';

  my $sub_type   = $self->my_config('subtype');
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
  my $href = $self->my_config('style')->{'link'};
  $href=~s/\$\$/$f->id/e;
  return $href;
}

sub colour_key {
  my( $self, $k ) = @_;
  return $k;
}

sub my_colour {
  my( $self, $k, $v ) = @_;
  return $v eq 'join' ? 'yellow' : $self->my_config('style')->{'color'}||'grey_50';
}

1;

