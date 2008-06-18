package EnsEMBL::Web::File::Driver::Disk;

use strict;
use Image::Size;
use Compress::Zlib;
use base 'EnsEMBL::Web::Root';

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;

  return $self;
}

sub exists {
  my ($self, $file) = @_;
  return -e $file && -f $file;
}

sub get {
  my ($self, $file, $format) = @_;

  if ($format eq 'imagemap') {
    my $gz = gzopen( $file, 'rb' );
    my $imagemap = '';
    my $buffer = 0;
    $imagemap .= $buffer while $gz->gzread( $buffer ) > 0;
    $gz->gzclose;
    return $imagemap;  
  } else {
    ## We dont read non-imagemap files
  }
}

sub save {
  my ($self, $image, $file, $format) = @_;

  $self->make_directory($file);

  if ($format eq 'imagemap') {
    my $gz = gzopen($file, 'wb');
    $gz->gzwrite($image);
    $gz->gzclose();
  } else {
    open(IMG_OUT, ">$file") || warn qq(Cannot open temporary image file for $format image: $!);
    binmode IMG_OUT;
    print IMG_OUT $image;
    close(IMG_OUT);
  }
}

sub imgsize {
  my ($self, $file) = @_;
  return Image::Size::imgsize($file);
}

1;