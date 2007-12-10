package EnsEMBL::Web::Document::Renderer::GzCacheFile;

use strict;
use Compress::Zlib;
use Digest::MD5 qw(md5_hex);
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Document::Renderer::GzFile;
our @ISA = qw(EnsEMBL::Web::Document::Renderer::GzFile);

sub new {
  my $class = shift;
  my $type     = shift;
  my $filename = shift;

  my $path = $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_TMP_DIR_CACHE;
  my $MD5 = hex(substr( md5_hex($filename), 0, 6 )); ## Just the first 6 characters will do!
  my $c1  = $EnsEMBL::Web::Root::random_ticket_chars[($MD5>>5)&31];
  my $c2  = $EnsEMBL::Web::Root::random_ticket_chars[$MD5&31];

  $filename = "$path/$type/$c1/$c2/$filename.gz";

  my $self      = { 'filename' => $filename };
  bless $self, $class;
  return $self if $self->exists( $filename );

  $self->make_directory( $filename );

  if( my $gz = gzopen( $filename, 'wb' ) ) {
    $self->{'file'} = $gz;
  } else {
    $self->{'file'} = undef;
  }
  return $self;
}

1;
