=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::QueryStore;

use strict;
use warnings;

use Carp qw(cluck);
use JSON;
use Digest::MD5 qw(md5_base64);

use EnsEMBL::Web::Query;

my $DEBUG = 0;

sub new {
  my ($proto,$sources,$cache) = @_;

  my $class = ref($proto) || $proto;
  my $self = { sources => $sources, cache => $cache, open => 0 };
  bless $self,$class;
  return $self;
}

sub get {
  my ($self,$query) = @_;

  return EnsEMBL::Web::Query->_new($self,"EnsEMBL::Web::Query::$query");
}

sub _source { return $_[0]->{'sources'}{$_[1]}; }

sub _clean_args {
  my ($self,$args) = @_;

  my %out = %$args;
  foreach my $k (keys %out) {
    delete $out{$k} if $k =~ /^__/;
  }
  return \%out;
}

sub version {
  no strict;
  my ($self,$class) = @_;

  return ${"${class}::VERSION"}||0;
}

sub _try_get_cache {
  my ($self,$class,$args) = @_;

  if(!$self->{'open'} && $DEBUG) {
    cluck("get on closed cache");
  }
  return undef unless $self->{'open'};
  return undef if $SiteDefs::ENSEMBL_PRECACHE_DISABLE;
  my $ver = $self->version($class);
  return undef if $ver < 1;
  my $out = $self->{'cache'}->get($class,$ver,{
    class => $class,
    args => $self->_clean_args($args),
  });
  if($DEBUG) { warn (($out?"hit ":"miss ")."${class}\n"); }
  return $out;
}

sub _set_cache {
  my ($self,$class,$args,$value,$build) = @_;

  return unless $self->{'open'};
  $self->{'cache'}->set($class,$self->version($class),{
    class => $class,
    args => $self->_clean_args($args)
  },$value,$build);
}

sub open {
  my ($self) = @_;

  $self->{'cache'}->cache_open();
  $self->{'open'} = 1;
}

sub close {
  my ($self) = @_;

  $self->{'cache'}->cache_close();
  $self->{'open'} = 0;
}

1;
