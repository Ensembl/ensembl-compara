package Bio::EnsEMBL::GlyphSet::generic_protein;
use strict;
use Bio::EnsEMBL::GlyphSet_feature;
@Bio::EnsEMBL::GlyphSet::generic_protein::ISA = qw(Bio::EnsEMBL::GlyphSet_feature);

sub my_label { 
  my $self = shift;
  return $self->my_config('TEXT_LABEL') || 'Missing label';
}

sub colour {
  my( $self, $id ) = @_;
  return ref($self->my_config('COLOUR')) eq 'CODE' ? &{$self->my_config('COLOUR')}($self->my_config('colours'), $id) : $self->my_config('col');
}

sub features {
  my ($self) = @_;
  my $method = $self->my_config('CALL')||'get_all_ProteinAlignFeatures';
  return map { $self->{'container'}->$method($_ ,80) } split /\s+/, ($self->my_config( 'FEATURES' ) || $self->check() ) ;
}

sub object_type {
  my($self,$id)=@_;
  my $F = $self->my_config('TYPE');
  return $self->{'type_cache'}{$id} ||= ref($F) eq 'CODE' ? &$F($id) : '';
}

sub SUB_ID {
  my( $self, $id ) = @_;
  my $type = $self->object_type($id);
  if( $type ) {
    return &{$self->my_config("ID_$type")}( $id ) if ref($self->my_config("ID_$type")) eq 'code';
  }
  return ref($self->my_config('ID')) eq 'CODE' ? &{$self->my_config('ID')}( $id ) : $id;
}

sub SUB_LABEL {
  my( $self, $id ) = @_;
  my $type = $self->object_type($id);
  if( $type ) {
    return &{$self->my_config("LABEL_$type")}( $id ) if ref($self->my_config("LABEL_$type")) eq 'code';
  }
  return ref($self->my_config('LABEL')) eq 'CODE' ? &{$self->my_config('LABEL')}( $id ) : $id;
}

sub SUB_HREF { return href( @_ ); }

sub href {
  my ( $self, $id ) = @_;
  my $type = $self->object_type($id);
  return $self->ID_URL( 
    $self->my_config( "URL_KEY_$type" ) || $self->my_config( 'URL_KEY' ) || 'SRS_PROTEIN',
    $self->SUB_ID($id)
  );
}

sub zmenu {
  my ($self, $id ) = @_;
  my $type = $self->object_type($id);
  if( my $zmenu = $self->my_config( "ZMENU_$type" ) || $self->my_config( 'ZMENU' ) ) { 
    if( ref($zmenu) eq 'ARRAY' ) {
      my @Q = @$zmenu;
      $id =~ s/'/\'/g;
      return {( 'caption', map { s/###(\w+)###/my $M="SUB_$1";$self->$M($id)/eg; $_ } @Q )};
    }
  }
  return { 'caption' => $self->SUB_ID($id),  ($self->my_config('ZMENU_LABEL')||"Protein homology") => $self->href( $id ) };
}
1;
