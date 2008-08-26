package Bio::EnsEMBL::GlyphSet::_alignment;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { 
  my $self = shift;
  return $self->my_config('TEXT_LABEL') || 'Missing label';
}

sub das_link {
  my($self) = shift;
  my $type     = $self->my_config( 'CALL' ) =~ /Protein/ ? 'protein_align' : 'dna_align';
  my $database = $self->my_config( 'DATABASE' ) || 'core' ;
  my @logic_names;
  if( $self->my_config( 'FEATURES' ) eq 'UNDEF' ) {
    @logic_names = () ;
  } else {
    @logic_names = split( /\s+/,
                          ( $self->my_config( 'FEATURES' ) ||
                            $self->check() ) );
  }
  my $slice   = $self->{container}; 
  my $species = $slice->{_config_file_name_};
  my $assembly = $self->{'config'}->species_defs->other_species($species, 'ENSEMBL_GOLDEN_PATH' );

  my $dsn = "$species.$assembly.".join('-',$type, $database, @logic_names);
  my $das_link = "/das/$dsn/features?segment=".$slice->seq_region_name.':'.$slice->start.','.$slice->end;
  return $das_link;
}

sub colour {
  my( $self, $id ) = @_;
  my $colours =  $self->{'colours'}->{ $self->object_type($id) } || 
                 $self->{'colours'}->{ 'default' } ||
                 $self->my_config('col') || 'black';
}

sub features {
  my ($self) = @_;
  my $method    = $self->my_config('CALL')||'get_all_DnaAlignFeatures';
  my $database  = $self->my_config('DATABASE') || undef;
  my $threshold = defined( $self->my_config('THRESHOLD')) ? $self->my_config('THRESHOLD') : 80;

  my @logic_names;
  if( $self->my_config( 'FEATURES' ) eq 'UNDEF' ) {
    @logic_names = ( undef() );
  } else {
    @logic_names = split( /\s+/, 
                          ( $self->my_config( 'FEATURES' ) ||
                            $self->check() ) );
  }   
  my @feats;
  foreach my $nm( @logic_names ){
    push( @feats, @{$self->{'container'}->$method($nm,undef,$database)} );
  }
  return [@feats];
}

sub object_type {
  my($self,$id)=@_;
  my $F = $self->my_config('SUBTYPE');
  return $self->{'type_cache'}{$id} ||= ref($F) eq 'CODE' ? &$F($id) : $F;
}

sub SUB_ID {
  my( $self, $id ) = @_;
  my $T = $self->my_config('ID');
  if( ref( $T ) eq 'HASH' ) {
    $T = $T->{ $self->object_type($id) }  || $T->{'default'};
  }
  return ( $T && ref( $T ) eq 'CODE' ) ? &$T( $id ) : $id;
}

sub SUB_LABEL {
  my( $self, $id ) = @_;
  my $T = $self->my_config('LABEL');
  if( ref( $T ) eq 'HASH' ) {
    $T = $T->{ $self->object_type($id) }  || $T->{'default'};
  }
  return ( $T && ref( $T ) eq 'CODE' ) ? &$T( $id ) : $id;

}

sub SUB_HREF { return href( @_ ); }

sub href {
  my ( $self, $id ) = @_;
  my $T = $self->my_config('URL_KEY');
  if( ref( $T ) eq 'HASH' ) {
    $T = $T->{ $self->object_type($id) };
  }
  return $self->ID_URL( $T || 'SRS_PROTEIN' , $self->SUB_ID( $id ) );
}

sub zmenu {
  my ($self, $id) = @_;
  my $T = $self->my_config('ZMENU');
  if( ref( $T ) eq 'HASH' ) {
    $T = $T->{ $self->object_type($id) } || $T->{'default'};
  }
  $id =~ s/'/\'/g; #'

  my @T = @{$T||[]};
  my @zmenus=('caption');
  foreach my $t(@T){
    if( $t =~ m/###(\w+)###/ ){
      if( $self->can( "SUB_$1" ) ){
        my $m="SUB_$1";
        $t =~ s/###(\w+)###/$self->$m($id)/eg 
      }                                 
      else{ $t =~ s/###(\w+)###/$self->ID_URL( $1, $self->SUB_ID( $id ) )/eg }
    }
    push @zmenus, $t;
  }

  my $extra_URL  = "/@{[$self->{container}{_config_file_name_}]}/featureview?type=";
     $extra_URL .= ( $self->my_config('CALL') eq 'get_all_ProteinAlignFeatures' ? 'ProteinAlignFeature' : 'DnaAlignFeature' );
     $extra_URL .= ";id=$id";
     $extra_URL .= ";db=".$self->my_config('DATABASE') if $self->my_config('DATABASE');
  push @zmenus, 'View all hits',  $extra_URL;
  push @zmenus, '<pre id="pfetch"></pre>', 'pfetch:'.$id;
  return {@zmenus};
}
1;
