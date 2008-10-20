package Bio::EnsEMBL::GlyphSet::_das;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use Data::Dumper;

sub _das_type {  return 'das'; }

sub features       { 
  my $self = shift;
## Fetch all the das features...
  unless( $self->cache('das_features') ) {
    $self->cache('das_features', $self->cache('das_coord')->fetch_Features( $self->{'container'} )||{} ); 
  } 
  local $Data::Dumper::Indent = 1;
  warn Dumper( $self->cache('das_features') );
  my %T = %{$self->cache('das_features')};
  warn "DAS: ",join "\t",@{$self->my_config('logicnames')};
  my @features = @T{ @{$self->my_config('logicnames')} };

## Filter for my source...
  foreach( @features ) {
    warn "\tDAS: ", join "\n\tDAS: ", keys %{$_};
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
