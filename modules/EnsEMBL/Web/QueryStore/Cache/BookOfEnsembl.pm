=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl;

use strict;
use warnings;

use base qw(EnsEMBL::Web::QueryStore::Cache);

use JSON;
use Fcntl qw(SEEK_SET SEEK_END :flock);
use Sys::Hostname;
use DB_File;
use File::Copy;
use Compress::Zlib;
use List::Util qw(min max);

use EnsEMBL::Web::QueryStore::Cache::BookOfEnsemblFile;

use bytes;

sub new {
  my ($proto,$conf) = @_;

  my $class = ref($proto) || $proto;

  my $rnd = EnsEMBL::Web::QueryStore::Cache->_key({ pid => $$, now => localtime, host => hostname },undef);
  my $lockfile = $conf->{'dir'}."/lockfile";

  my ($master,$local);
  if($conf->{'part'}) {
    $master = EnsEMBL::Web::QueryStore::Cache::BookOfEnsemblFile->new(
      $conf->{'dir'}."/".$conf->{'part'},'part'
    );
  } else {
    $master = EnsEMBL::Web::QueryStore::Cache::BookOfEnsemblFile->new(
      $conf->{'dir'}."/boe",'finished'
    );
  }
  if($conf->{'replace'}) {
    $local = $master->stage_new;
  } else {
    $local = EnsEMBL::Web::QueryStore::Cache::BookOfEnsemblFile->new($conf->{'dir'}."/$rnd",'raw');
  }

  my $self = {
    dir => $conf->{'dir'},
    wfile => $local,
    rfile => $master,
    lockfile => $lockfile,
    replace => $conf->{'replace'},
    any => 0,
    open => 0,
    wopen => 0,
  };
  bless $self,$class;
  return $self;
}

sub merge {
  my ($self) = @_;

  my @parts = grep { $_->mode eq 'part' } @{[$self->_list_files()]->[0]};
  foreach my $p (@parts) {
    $self->{'wfile'}->merge($p);
  }
  $self->{'wfile'}->stage_release if $self->{'replace'};
}

sub cache_open {
  my ($self,$rebuild) = @_;

  $rebuild = $self->{'rebuild'} if defined $rebuild and $rebuild == -1;
  $self->{'rebuild'} = (defined $rebuild)?0:undef;
  return if $self->{'open'};
  $self->{'rfile'}->delete() if $rebuild;
  $self->{'rfile'}->open_read(1) or return;
  $self->{'wfile'}->open_write() if defined $rebuild;
  $self->{'open'} = 1;
  $self->{'wopen'} = (defined $rebuild)+0;
}

sub set {
  my ($self,$class,$ver,$args,$value,$build) = @_;

  return unless $self->{'open'};
  return unless $build;
  my $key = $self->_key($args,$class);
  $self->{'any'} = 1;
  $self->{'wfile'}->set($key,$value);
  $self->{'wfile'}->set_version($class,$ver);
}

sub get {
  my ($self,$class,$ver,$k) = @_;

  return undef unless $self->{'open'};
  my $rver = $self->{'rfile'}->get_version($class);
  if($rver and $ver!=$rver) {
    # Force consolidation
    $self->{'any'} = 1;
    $self->cache_close();
    $self->cache_open(-1);
    return undef;
  }
  return $self->{'rfile'}->get($self->_key($k,$class));
}
  
sub _into {
  my ($self,$in,$stage,$full) = @_;

  $in->open_read() or die "Open failed";
  my $in_vers = $in->get_versions;
  my %good_vers;
  foreach my $k (keys %$in_vers) {
    $stage->check_dated($k,$in_vers->{$k});
  }
  foreach my $k (keys %$in_vers) {
    next unless $stage->test_wanted($k,$in_vers->{$k});
    $good_vers{$self->_class_key($k)} = 1;
  }
  my ($hit,$miss,$all,$new) = (0,0,0,0);
  while(1) {
    my ($k,$v) = $in->each();
    last unless defined $k;
    $all++;
    next if $stage->has($k);
    $new++;
    my $vk = $k;
    $vk =~ s/^.*\.//;
    if($good_vers{$vk}) {
      $hit++;
      my $data = $in->get($k);
      $stage->set($k,$data);
    } else {
      $miss++;
    }
  }
  warn "new=$new all=$all current=$hit aged=$miss\n";
  $in->close();
  if($in->mode eq 'ready' and !$stage->test_dated()) {
    $in->delete();
  }
}

my @long_modes = qw(ready finished part);
sub _list_files {
  my ($self) = @_;

  opendir(DIR,$self->{'dir'}) or die;
  my (%found,%files);
  foreach my $f (readdir(DIR)) {
    my $full = "$self->{'dir'}/$f";
    next unless -f $full;
    $files{$full} = 1;
    next unless $f =~ s/\.([^\.]+)$//;
    my $ext = $1;
    if($ext eq 'dat') { $found{$f} |= 2; }
    if($ext eq 'idx') { $found{$f} |= 1; }
  }
  closedir DIR; 
  my (@out,@tmp);
  foreach my $k (keys %found) {
    next unless $found{$k} == 3;
    next unless $k =~ s/\.([^\.]+)$//;
    my $mode = $1;
    my $f = EnsEMBL::Web::QueryStore::Cache::BookOfEnsemblFile->new(
      "$self->{'dir'}/$k",$mode
    );
    push @out,$f;
    if(grep { $f->mode eq $_ } @long_modes) {
      delete $files{$f->fn('idx')};
      delete $files{$f->fn('dat')};
      delete $files{$f->fn('idx').".tmp"};
      delete $files{$f->fn('dat').".tmp"};
    }
  }
  delete $files{$self->{'dir'}."/lockfile"};
  return (\@out,[keys %files]);
}

sub _suitable_files {
  my ($self,$full) = @_;

  my @out;
  my ($readies,$tmps) = $self->_list_files();
  my @f = grep { $_->mode eq 'ready' } @$readies;
  push @f,$self->{'rfile'}->fn('idx') if $full;
  my $now = time();
  foreach my $t (@$tmps) {
    my @stat = stat($t);
    next unless $stat[9];
    my $age = $now-$stat[9];
    unlink $t if $age > 10*60;
  }
  return \@f;
}

sub _lock {
  my ($self) = @_;

  open($self->{'lock'},">>",$self->{'lockfile'}) or die;
  flock($self->{'lock'},LOCK_EX) or die;
}

sub _unlock {
  my ($self) = @_;
  
  flock($self->{'lock'},LOCK_UN);
  close($self->{'lock'});
}


sub _consolidate {
  my ($self,$files,$full) = @_;

  $self->_lock();
  my $stage;
  if($full) {
    warn "FULL CONSOLIDATE DUE TO DATED CACHE\n";
    $stage = $self->{'rfile'}->stage_new();
    $stage->set_version($_,$full->{$_}) for keys %$full;
  } else {
    $stage = $self->{'rfile'}->stage_copy();
  }
  foreach my $f (@$files) {
    $self->_into($f,$stage,$full);
  }
  $stage->close();
  $stage->stage_release();
  $self->_unlock();
  if($stage->test_dated()) {
    $self->_consolidate($files,$stage->target());
  }
}

sub cache_close {
  my ($self) = @_;

  return unless $self->{'open'};
  $self->{'open'} = 0;
  $self->{'rfile'}->close();
  $self->{'wfile'}->close() if $self->{'wopen'};
  if($self->{'any'}) {
    $self->{'wfile'}->remode('ready');
    my $inputs = $self->_suitable_files();
    $self->_consolidate($inputs);
    $self->{'wfile'}->remode('raw');
  } else {
    unlink $self->{'wfile'}->fn('idx');
    unlink $self->{'wfile'}->fn('dat');
  }
}

1;
