package Bio::EnsEMBL::GlyphSet::_simple;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub das_link {
  my($self) = shift;
  my $type     = 'simple';
  my $database = $self->my_config( 'DATABASE' ) || 'core' ;
  my @logic_names = $self->my_config( 'code' );
  
  my $slice   = $self->{container};
  my $species = $slice->{_config_file_name_};
  my $assembly = $self->{'config'}->species_defs->other_species($species, 'ENSEMBL_GOLDEN_PATH' );

  my $dsn = "$species.$assembly.".join('-',$type, $database, @logic_names);
  my $das_link = "/das/$dsn/features?segment=".$slice->seq_region_name.':'.$slice->start.','.$slice->end;
# warn $dsn;
# warn $das_link;
  return $das_link;
}


sub features       { 
  my $self = shift;
  my $call = 'get_all_'.( $self->my_config( 'type' ) || 'SimpleFeatures' ); 
  return $self->{'container'}->$call( $self->my_config( 'code' ), $self->my_config( 'threshold' ) );
}

sub href {
  my ($self, $f ) = @_;
  my $T = $self->my_config('URL_KEY');
  return $T ? $self->ID_URL( $T , $f->display_label ) : undef;
}

sub zmenu {
  my ($self, $f ) = @_;
  my $score = $f->score();
  my $name  = $f->display_label;
  my ($start,$end) = $self->slice2sr( $f->start, $f->end );
  my $href = $self->href( $f );
  my $caption  = $self->my_label;
     $caption .= " - $name" if $name;
  return {
    'caption' => $caption,
    "01:Score: $score"   => '',
    "02:bp: @{[$self->commify($start)]}-@{[$self->commify($end)]}" => '',
    $href ? ( "Link" => $href ) : ()
  };
}

1;
