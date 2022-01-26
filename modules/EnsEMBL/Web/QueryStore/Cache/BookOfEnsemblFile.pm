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

package EnsEMBL::Web::QueryStore::Cache::BookOfEnsemblFile;

use strict;
use warnings;

use bytes;

use JSON;
use Fcntl qw(SEEK_SET SEEK_END SEEK_CUR :flock);
use Compress::Zlib;
use DB_File;
use File::Copy;
use List::Util qw(max);

sub new {
  my ($proto,$base,$mode,$suffix) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    base => $base,
    mode => $mode||'raw',
    suffix => $suffix||'',
    dated => {},
  };
  bless $self,$class;
  return $self;
}

sub mode { return $_[0]->{'mode'}; }

sub remode {
  my ($self,$mode) = @_;

  my $old_idx = $self->fn('idx');
  my $old_dat = $self->fn('dat');
  $self->{'mode'} = $mode;
  my $new_idx = $self->fn('idx');
  my $new_dat = $self->fn('dat');
  rename($old_idx,$new_idx);
  rename($old_dat,$new_dat);
}

sub stage_new {
  my ($self) = @_;

  my $out = $self->new($self->{'base'},$self->{'mode'},'tmp');
  unlink $out->fn('idx');
  unlink $out->fn('dat');
  $out->open_write('idx');
  return $out;
}

sub stage_copy {
  my ($self) = @_;

  my $out = $self->new($self->{'base'},$self->{'mode'},'tmp');
  copy($self->fn('idx'),$out->fn('idx'));
  copy($self->fn('dat'),$out->fn('dat'));
  $out->open_write('idx');
  return $out;
}

my $FILESIZE = 1_000_000;
sub _cat {
  my ($self,$target,$src) = @_;

  warn "$src -> $target\n";
  open(IN,'<:raw',$src) or die;
  open(OUT,'>>:raw',$target) or die;
  my $offset = tell OUT;
  while(1) {
    my $data;
    my $r = read(IN,$data,$FILESIZE);
    last if $r==0;
    print OUT $data;
  }
  close OUT;
  close IN;
  return $offset;
}

sub merge {
  my ($self,$part) = @_;

  my $offset = $self->_cat($self->fn('dat'),$part->fn('dat'));
  $part->open_read() or die "Cannot open ".$self->fn('dat')."\n";
  $self->open_write();
  my $in_ver = $part->get_versions;
  my $out_ver = $self->get_versions;
  foreach my $k (keys %$in_ver) {
    next unless exists $out_ver->{$k};
    next if $out_ver->{$k} == $in_ver->{$k};
    die "Incompatible versions for $k";
  }
  while(my ($k,$v) = each %{$part->{'idx'}}) {
    next if defined($k) and $k =~ /^\./;
    my $d = JSON->new->decode($v);
    $self->{'idx'}{$k} = JSON->new->encode([$d->[0]+$offset,$d->[1]]); 
  }
  $out_ver = { %$out_ver, %$in_ver };
  $self->set_versions($out_ver);
  $self->close();
  $part->close();
}

sub delete {
  my ($self) = @_;

  unlink $self->fn('idx');
  unlink $self->fn('dat');
}

sub stage_release {
  my ($self) = @_;

  rename($self->fn('idx'),$self->fn('idx',1)); 
  rename($self->fn('dat'),$self->fn('dat',1)); 
}

sub fn {
  my ($self,$type,$nsuf) = @_;

  my $out = "$self->{'base'}.$self->{'mode'}.$type";
  $out .= '.'.$self->{'suffix'} if $self->{'suffix'} and !$nsuf;
  return $out;
}

sub open_read {
  my ($self,$maybe) = @_;

  my %idx;
  unless(tie(%idx,'DB_File',$self->fn("idx"),
             O_CREAT|O_RDONLY,0600,$DB_HASH)) {
    warn "Cannot open '".$self->fn('idx')." for reading: $!\n" unless $maybe;
    return 0;
  }
  $self->{'idx'} = \%idx;
  unless(-e $self->fn('dat')) {
    open(TMP,">>",$self->fn('dat'));
    close TMP;
  }
  unless(open($self->{'dat'},'<:raw',$self->fn('dat'))) {
    warn "Cannot open '".$self->fn('dat')."' for reading: $!\n";
    return 0;
  }
  return 1;
}

sub open_write {
  my ($self,$type) = @_;

  my %idx;
  tie(%idx,'DB_File',$self->fn('idx'),O_CREAT|O_RDWR,0600,$DB_HASH)
    or die "Cannot open '".$self->fn('idx')." for writing: $!\n";
  $self->{'idx'} = \%idx;
  open($self->{'dat'},'>>:raw',$self->fn('dat'))
    or die "Cannot open '".$self->fn('dat')."' for writing: $!\n";
}

sub close {
  my ($self) = @_;

  untie %{$self->{'idx'}};
  close $self->{'dat'};
}

sub get_versions {
  my ($self) = @_;

  return JSON->new->decode($self->{'idx'}{'.versions'}||"{}");
}

sub get_version {
  my ($self,$class) = @_;

  my $vers = $self->get_versions;
  return $vers->{$class};
}

sub set_version {
  my ($self,$class,$ver) = @_;

  my $vers = $self->get_versions;
  $vers->{$class} = $ver;
  $self->set_versions($vers);
}

sub set_versions {
  my ($self,$val) = @_;

  $self->{'idx'}{'.versions'} = JSON->new->encode($val);
}

sub get {
  my ($self,$key) = @_;

  my $json = $self->{'idx'}{$key};
  return undef unless $json;
  my $d = JSON->new->decode($json);
  sysseek($self->{'dat'},$d->[0],SEEK_SET);
  my $out;
  sysread($self->{'dat'},$out,$d->[1]);
  eval {
    $out = JSON->new->decode(Compress::Zlib::memGunzip($out));
  };
  return $out unless $@;
  die "get failed";
} 

sub systell { sysseek($_[0], 0, SEEK_CUR) }

sub set {
  my ($self,$key,$valuei) = @_;

  return 0 if exists $self->{'idx'}{$key};
  my $value = Compress::Zlib::memGzip(JSON->new->encode($valuei));
  my $start = systell $self->{'dat'};
  syswrite $self->{'dat'},$value,length($value);
  my $end = systell $self->{'dat'};
  $self->{'idx'}{$key} = JSON->new->encode([$start,$end-$start]);
  return 1;
}

sub each {
  my ($self) = @_;

  while(1) {
    my ($k,$v) = each %{$self->{'idx'}};
    next if defined($k) and $k =~ /^\./;
    return undef unless defined $k;
    return ($k,$v);
  };
}

sub has {
  my ($self,$key) = @_;

  return exists $self->{'idx'}{$key};
}

sub check_dated {
  my ($self,$class,$new_ver) = @_;

  my $my_ver = $self->get_version($class);
  return if !$my_ver;            # Not dated because never heard of it
  return if $my_ver >= $new_ver; # Our version still current
  $self->{'dated'}{$class} = max($self->{'dated'}{$class}||0,$new_ver);
}

sub test_dated {
  my ($self) = @_;

  return !!scalar(keys %{$self->{'dated'}});
}

sub target { return $_[0]->{'dated'}; }

sub test_wanted {
  my ($self,$class,$new_ver) = @_;

  my $my_ver = $self->get_version($class);
  if(!$my_ver) {
    # Not heard of it, so want it
    $my_ver = $new_ver;
    $self->set_version($class,$my_ver);
  }
  return ($new_ver==$my_ver);
}

1;
