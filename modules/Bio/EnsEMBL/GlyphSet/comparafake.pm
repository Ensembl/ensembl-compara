package Bio::EnsEMBL::GlyphSet::comparafake;

use strict;
use Bio::EnsEMBL::GlyphSet;
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
  my ($self) = @_;
  my $name = $self->{container}{_config_file_name_};
     $name =~ s/^([A-Z])([a-z]+_)/\1./;

  $self->init_label_text( $name );
}

sub _init {
  my ($self) = @_;
  $self->errorTrack( "no match with ".$self->{'container'}{_config_file_name_} );
}

1;
        
