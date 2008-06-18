package EnsEMBL::Web::File::Driver::Memcached;

use strict;
use Image::Size;
use Compress::Zlib;

use EnsEMBL::Web::Cache;
use base 'EnsEMBL::Web::Root';

our $cache = {};

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
  return exists($cache->{$key}) || $self->memd->get($key);
}

sub get {
  my ($self, $key, $format) = @_;

#  if ($format eq 'imagemap') {
#    $self->memd->enable_compress(1);
#  } else {
#    $self->memd->enable_compress(0);
#  }

  return $cache->{$key} || $self->memd->get($key);
}

sub save {
  my ($self, $data, $key, $format) = @_;
  
  if ($format eq 'imagemap') {
    $self->memd->enable_compress(1);
  } else {
    $self->memd->enable_compress(0);
    my ($x, $y) = Image::Size::imgsize(\$data);
    $cache->{$key} = {
      width  => $x,
      height => $y,
      size   => length($data),
      image  => $data,
    };
  }

  
  my $result = $self->memd->set($key, $cache->{$key}, undef, 'IMG', $format);
  return $result eq "OK\r?\n";
}

sub imgsize {
  my ($self, $key) = @_;
  if (my $data = $self->get($key)) {
    return ($data->{width}, $data->{height});
  }
}

1;