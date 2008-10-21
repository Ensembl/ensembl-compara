package Bio::EnsEMBL::GlyphSet::_das;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;

sub _das_type {  return 'das'; }

sub features       { 
  my $self = shift;
  
  ## Fetch all the das features...
  unless( $self->cache('das_features') ) {
    # Query by slice:
    $self->cache('das_features', $self->cache('das_coord')->fetch_Features( $self->{'container'} )||{} );
  }
  
  my $data = $self->cache('das_features');
  
  for my $logic_name ( @{ $self->my_config('logicnames') } ) {
    
    my $stylesheet = $data->{ $logic_name }{ 'stylesheet' } || Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new();
    my @features   = @{ $data->{ $logic_name }{ 'features' } };
    my @errors     = @{ $data->{ $logic_name }{ 'errors'   } };
    
    warn sprintf "DAS / %s / %d features / %d errors / %s", $logic_name, scalar @features, scalar @errors, $stylesheet;
    
    for my $error ( @errors ) {
      warn "DAS / $logic_name / $error";
    }
    
  }
  
  return [];
}

sub colour_key {
  my( $self, $f ) = @_;
  return '';
}

sub feature_label {
  return undef;
}

sub title {
  my( $self, $f ) = @_;
  return 'DAS'
}

sub href {
  my ($self, $f ) = @_;
  return undef;
}

sub tag {
  my ($self, $f ) = @_;
  return; 
}
1;
