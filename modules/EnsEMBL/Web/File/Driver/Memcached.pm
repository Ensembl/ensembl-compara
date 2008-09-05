package EnsEMBL::Web::File::Driver::Memcached;

use strict;
use Image::Size;
use Compress::Zlib;

use EnsEMBL::Web::Cache;
use base 'EnsEMBL::Web::Root';

sub new {
  my $class = shift;
  my $self  = {};
  
  bless $self, $class;
  $self->memd = EnsEMBL::Web::Cache->new or return undef;

  return $self;
}

sub memd :lvalue { $_[0]->{'memd'}; }

sub exists {
  my ($self, $key) = @_;
  return $self->memd->get($key);
}

sub get {
  my ($self, $key, $args) = @_;

  $self->memd->enable_compress($args->{compress});
  return $self->memd->get($key);
}

sub save {
  my ($self, $data, $key, $args) = @_;

  $args ||= {};  
  $self->memd->enable_compress($args->{compress});

  if ($args->{format} eq 'png') {
    my ($x, $y) = Image::Size::imgsize(\$data);
    $data = {
      width  => $x,
      height => $y,
      size   => length($data),
      image  => $data,
      mtime  => time,
    };
  }
  
  my $result = $self->memd->set($key, $data, $args->{exptime}, 'TMP', $args->{format});
  return $result eq "OK\r?\n";
}

sub imgsize {
  my ($self, $key) = @_;
  if (my $data = $self->get($key)) {
    return ($data->{width}, $data->{height});
  }

  return undef;
}

1;