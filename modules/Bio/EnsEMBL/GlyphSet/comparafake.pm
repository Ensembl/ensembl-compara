package Bio::EnsEMBL::GlyphSet::comparafake;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Text;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
  my ($self) = @_;
  my $name = $self->{container}{_config_file_name_};
     $name =~ s/^([A-Z])([a-z]+_)/\1./;

  my $label = new Sanger::Graphics::Glyph::Text({
   'text'      => $name,
   'font'      => 'Small',
   'absolutey' => 1,
  });
  $self->label($label);
}


sub _init {
  my ($self) = @_;
  $self->errorTrack( "no match with ".$self->{'container'}{_config_file_name_} );
}

1;
        
