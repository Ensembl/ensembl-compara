package EnsEMBL::Web::File::Driver::Memcached;

use strict;
use Image::Size;
use Compress::Zlib;

use EnsEMBL::Web::Cache;
use base 'EnsEMBL::Web::Root';

sub new {
  my $class = shift;
  my $self  = {};
  
  warn 'TRUGINGGGGGGGGGGGGGGGGGG';
  
  bless $self, $class;
  $self->memd = EnsEMBL::Web::Cache->new or return undef;

  warn 'OKKKKKKKKKKKKKKKKKKKKKKKKKKKKK';
  
  return $self;
}

sub memd :lvalue { $_[0]->{'memd'}; }

sub exists {
  my ($self, $key) = @_;
  return $self->memd->get($key);
}

sub get {
  my ($self, $key, $format) = @_;

  warn "!!!!!!!!!!!!!!!!!!!!!! GET $key";

#  if ($format eq 'imagemap') {
#    $self->memd->enable_compress(1);
#  } else {
#    $self->memd->enable_compress(0);
#  }

  return $self->memd->get($key);
}

sub save {
  my ($self, $data, $key, $format) = @_;

  warn "!!!!!!!!!!!!!!!!!!!!!!! SAVE! $key";

#  if ($format eq 'imagemap') {
#    $self->memd->enable_compress(1);
#  } else {
#    $self->memd->enable_compress(0);
#  }
  warn "SETTING DATA: ".$data;
  my $result = $self->memd->set($key, $data, undef, 'IMG', $format);
  warn "DONE: ".$result;
  return $result eq "OK\r?\n";
}

1;