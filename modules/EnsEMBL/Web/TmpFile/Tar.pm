package EnsEMBL::Web::TmpFile::Tar;

## EnsEMBL::Web::TmpFile::Tar - module for storing multiple tmp files into tar archive

use strict;
use IO::String ();
use Archive::Tar ();
use Compress::Zlib qw(gzopen $gzerrno);

use EnsEMBL::Web::SpeciesDefs;
use base 'EnsEMBL::Web::TmpFile';

__PACKAGE__->mk_accessors(qw(use_short_names));

sub new {
  my $class = shift;
  my %args  = @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $self = $class->SUPER::new(
    content         => [],
    species_defs    => $species_defs,
    compress        => 1,
    use_short_names => 0,
    extension       => (defined $args{compress} && !$args{compress})
                         ? 'tar'
                         : 'tar.gz',
    content_type    => (defined $args{compress} && !$args{compress})
                         ? 'application/x-tar'
                         : 'application/x-gzip',
    %args,
  );

  return $self;
}

sub save {
  my $self    = shift;
  my $content = $self->content(shift);
  my $params  = shift || {};
  
  if (ref($content) eq 'ARRAY' && @$content) {

    my $tar = Archive::Tar->new;
    $tar->add_data(
      ($self->use_short_names ? $_->shortname : $_->filename),
      $_->content,
    ) for @$content;
    
    my $tstr = $tar->write;

    if ($self->compress) {
      my $gz = gzopen( IO::String->new(my $tgzstr), 'wb' )
       or die "GZ Cannot open io handle: $gzerrno\n";
      $gz->gzwrite($tstr);
      $gz->gzclose();
      $tstr = $tgzstr;
    }

    my $result = $self->SUPER::save($tstr, {compress => 0});
    $self->content($content);
    return $result;

  } else {
    die "No files to make tar archive";
  }
  
}

sub add_file {
  my $self    = shift;
  my $content = $self->content;
  
  push @$content, @_;
}

1;