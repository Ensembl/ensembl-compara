package EnsEMBL::Web::Object::Server;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

use Storable qw(lock_retrieve);

sub caption { return 'Server information'; }
sub short_caption { return 'Server'; }

sub counts { return {}; }

sub unpack_db_tree {
  my $self = shift;
  my $f = $self->param('file');
  $f = $self->species.'.db' unless $f;
  warn "**".$f;
  $f =~ s/[^\.\w]+//g;
  warn "**".$f;
  $f =~ s/^\.+//;
  warn "**".$f;
  warn "SETTING PARAMETER FILE $f";
  $self->param( 'file', $f );
  $f = "packed/$f" if $f ne 'config';
  my $file = $self->species_defs->ENSEMBL_SERVERROOT."/conf/$f.packed";
  warn "FILE $file";
  return -e $file ? lock_retrieve $file : undef;
}
  
sub get_all_packed_files {
  my $self = shift;
  my $dir = $self->species_defs->ENSEMBL_SERVERROOT."/conf/packed";
  my @files = ();
  if( opendir( DH, $dir ) ) {
    while(my $n = readdir DH ) {
      push @files, $1 if $n =~ /^(\w+(\.\w+)?)\.packed$/;
    }
  }
  closedir DH;
  @files = sort @files;
  unshift @files, 'config';
  return @files;
}

sub get_all_species {
  my $self = shift;
  my @species = @{ $self->species_defs->ENSEMBL_SPECIES };
  my @data = ();
  foreach my $species (@species) {
    (my $name = $species ) =~ s/_/ /g;
    push @data, {
      'species'  => $name,
      'common'   => $self->species_defs->get_config( $species, 'SPECIES_COMMON_NAME' ),
      'link'     => $self->full_URL( 'species'=>$species ),
      'gp'       => $self->species_defs->get_config( $species, 'ENSEMBL_GOLDEN_PATH' ),
      'version'  => $self->species_defs->get_config( $species, 'SPECIES_RELEASE_VERSION' ),
    };
  }
  return @data;
}

1;
