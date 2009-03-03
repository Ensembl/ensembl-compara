package EnsEMBL::Web::TmpFile::Driver::Disk;

use strict;
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

sub delete {
  my ($self, $file) = @_;
  return unlink $file;
}

sub get {
  my ($self, $file, $params) = @_;

  my $content = '';
  if ($params->{compress}) {
    my $gz = gzopen( $file, 'rb' )
         or warn "GZ Cannot open $file: $gzerrno\n";
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
  my ($self, $file, $content, $params) = @_;

  $self->make_directory($file);

  eval {
    if ($params->{compress}) {
      my $gz = gzopen($file, 'wb')
           or die "GZ Cannot open $file: $gzerrno\n";
      $gz->gzwrite($content)
           or die "GZ Cannot srite content: $gzerrno\n";
      $gz->gzclose();
    } else {
      open(FILE, ">$file")
        or die "Cannot open file $file: $!";
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


1;