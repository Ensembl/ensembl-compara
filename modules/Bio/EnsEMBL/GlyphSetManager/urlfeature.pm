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
      $url_glyphset = new Bio::EnsEMBL::GlyphSet::urlfeature(
        $self->{'container'}, $self->{'config'}, $self->{'highlights'}, $self->{'strand'},
        {
          'name'        => "$track",
          'colour'      => $Config->colourmap->add_colour( $T->{'config'}{'color'} ) || $Config->get('urlfeature','col'),
          'description' => $T->{'config'}{'description'}||'',
          'url'         => $T->{'config'}{'url'}||'',
          'height'      => $T->{'config'}{'height'}||0,
          'data'        => $T->{'features'}||[],
        }
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
