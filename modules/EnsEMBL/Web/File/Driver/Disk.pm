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
  my ($self, $file, $args) = @_;

  my $content = '';
  if ($args->{compress}) {
    my $gz      = gzopen( $file, 'rb' );
    if ($gz) {
      my $buffer  = 0;
      $content   .= $buffer while $gz->gzread( $buffer ) > 0;
      $gz->gzclose;
    }
  } else {
    local $/ = undef;
    open FILE, $file;
    $content = <FILE>;
    close FILE;    
  }
  return $content;  
}

sub save {
  my ($self, $content, $file, $args) = @_;

  $self->make_directory($file);

  eval {
    if ($args->{compress}) {
      my $gz = gzopen($file, 'wb');
      $gz->gzwrite($content);
      $gz->gzclose();
    } else {
      open(FILE, ">$file") || warn qq(Cannot open temporary image file $file: $!);
      binmode FILE;
      print FILE $content;
      close FILE;
    }
  };

  if ($@) {
    warn $@;
    return undef;
  }
  
  return 1;
}

sub imgsize {
  my ($self, $file) = @_;
  return Image::Size::imgsize($file);
}

1;
