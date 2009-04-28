package EnsEMBL::Web::TmpFile::Image;

## EnsEMBL::Web::TmpFile::Image - module for dealing with temporary png images
## see base module for more information

use strict;
use Image::Size;
use EnsEMBL::Web::SpeciesDefs;
use base 'EnsEMBL::Web::TmpFile';

## Some extra accessors specific for png images
__PACKAGE__->mk_accessors(qw(height width size mtime));

sub new {
  my $class = shift;
  my %args  = @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $self = $class->SUPER::new(
    species_defs => $species_defs,
    compress     => 0,
    extension    => 'png',
    content_type => 'image/png',
    file_root    => $species_defs->ENSEMBL_TMP_DIR_IMG,
    URL_root     => $species_defs->ENSEMBL_TMP_URL_IMG,
    %args,
  );

  return $self;
}

sub content {
  my $self = shift; 

  if (@_ && defined $_[0]) {
    my ($x, $y, $z) = Image::Size::imgsize(\$_[0]);
      die "imgsize failed: $z" unless defined $x;
    $self->width($x);
    $self->height($y);
    $self->size(length($_[0]));
    $self->mtime(time);
  }

  return $self->SUPER::content(@_);
}

sub save {
  my $self    = shift;
  my $content = $self->content(shift);
  my $params  = shift || {};

  $params = {
    %$params,
    width  => $self->width,
    height => $self->height,
    size   => length($content),
    mtime  => time,
  };

  return $self->SUPER::save(undef, $params);
}

1;