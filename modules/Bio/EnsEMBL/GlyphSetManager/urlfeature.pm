package Bio::EnsEMBL::GlyphSetManager::urlfeature;

use strict;
use Sanger::Graphics::GlyphSetManager;
use Bio::EnsEMBL::GlyphSet::urlfeature;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::GlyphSetManager);

sub init {
  use Data::Dumper;
  my ($self) = @_;
  $self->label("URL sourced tracks");
  my $Config = $self->{'config'};
  return unless exists $Config->{'__url_source_data__'};
  my $data = $Config->{'__url_source_data__'};
  foreach my $track ( keys %{ $data ||{} } ) {
## Add a glyphset with the contents of this track.....
    my $T = $data->{$track};
    my $url_glyphset;
    $T->{'config'}||={};
    eval {
      my $ExtraConfig = { 
          'name'        => "$track",
          'colour'      => $Config->colourmap->add_colour( $T->{'config'}{'color'} ) || $Config->get('urlfeature','col'),
          'data'        => $T->{'features'}||[],
      };
      
      foreach my $key (qw(description url dataMin dataMax cgGrades cgColour1 cgColour2 cgColour3)) {
         $ExtraConfig->{$key} = defined($T->{'config'}{$key}) ? $T->{'config'}{$key} : undef;
      }
      foreach my $key (qw(height useScore)) {
         $ExtraConfig->{$key} = $T->{'config'}{$key}||0;
      }

      $url_glyphset = new Bio::EnsEMBL::GlyphSet::urlfeature(
        $self->{'container'}, $self->{'config'}, $self->{'highlights'}, $self->{'strand'}, $ExtraConfig
      );
    };
    if($@) {
      print STDERR "URL GLYPHSET $track failed ($@)\n";
    } else {
      push @{$self->{'glyphsets'}}, $url_glyphset;
    }
  }
}

1;
