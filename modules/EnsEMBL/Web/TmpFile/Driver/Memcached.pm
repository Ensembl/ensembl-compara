package EnsEMBL::Web::TmpFile::Driver::Memcached;

use strict;
use Compress::Zlib;

use EnsEMBL::Web::Cache;
use base 'EnsEMBL::Web::Root';

sub new {
  my $class = shift;
  my $self  = {};
  
  bless $self, $class;
  $self->{'memd'} = EnsEMBL::Web::Cache->new or return undef;

  return $self;
}

sub memd { $_[0]->{'memd'}; }

sub exists {
  my ($self, $key) = @_;
  return $self->memd->get($key);
}

sub delete {
  my ($self, $key) = @_;
  return $self->memd->delete($key);
}

sub get {
  my ($self, $key, $params) = @_;

  $self->memd->enable_compress($params->{compress});
  return $self->memd->get($key);
}

sub save {
  my ($self, $key, $content, $params) = @_;

  $self->memd->enable_compress($params->{compress});

  return $self->memd->set(
    $key,
    {
      content => $content,
      %{ $params || {} },
    },
    $params->{exptime},
    ( 'TMP', $params->{format}, keys %{ $ENV{CACHE_TAGS}||{} } ),
  );
}


1;