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
  my ($self, $obj) = @_;
  return $self->memd->get($obj->URL);
}

sub delete {
  my ($self, $obj) = @_;
  return $self->memd->delete($obj->URL);
}

sub get {
  my ($self, $obj) = @_;

  $self->memd->enable_compress($obj->compress);
  return $self->memd->get($obj->URL);
}

sub save {
  my ($self, $obj) = @_;

  $self->memd->enable_compress($obj->compress);

  return $self->memd->set(
    $obj->URL,
    $obj->content,
    $obj->exptime,
    ( 'TMP', $obj->format, keys %{ $ENV{CACHE_TAGS}||{} } ),
  );
}


1;