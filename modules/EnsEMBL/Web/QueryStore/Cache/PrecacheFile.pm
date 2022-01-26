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

package EnsEMBL::Web::QueryStore::Cache::PrecacheFile;

use strict;
use warnings;

use bytes;

use JSON;
use Fcntl qw(SEEK_SET SEEK_END SEEK_CUR :flock);
use Compress::Zlib;
use DB_File;
use File::Copy;
use List::Util qw(max);
use List::MoreUtils qw(any);
use Digest::MD5 qw(md5_base64);
use File::Basename;

use EnsEMBL::Web::QueryStore::Cache::PrecacheBuilder qw(identity);

our $DEBUG = 1;

sub new {
  my ($proto,$conf) = @_;

  my $class = ref($proto) || $proto;
  my @parts = ($conf->{'base'},$conf->{'dir'});
  $parts[0] ||= 'precache';
  if($conf->{'filename'}) {
    @parts = fileparse($conf->{'filename'},qr{\.(idx|dat)$});
  }
  my $self = {
    dir => $parts[1],
    base => $parts[0],
    write => $conf->{'write'},
  };
  bless $self,$class;
  $self->cache_open;
  return $self;
}

sub systell { sysseek($_[0], 0, SEEK_CUR) }

sub fn {
  my ($self,$type,$base) = @_;

  $base ||= $self->{'base'};
  return "$self->{'dir'}/$base.$type";
}

sub _remove_undef {
  my ($self,$obj) = @_;

  if(ref($obj) eq 'HASH') {
    foreach my $k (keys %$obj) {
      if(defined $obj->{$k}) {
        $self->_remove_undef($obj->{$k});
      } else {
        delete $obj->{$k};
      }
    }
  } elsif(ref($obj) eq 'ARRAY') {
    $self->_remove_undef($_) for @$obj;
  }
}

sub _open {
  my ($self,$mode,$datop,$name) = @_;

  return if $self->{'open'};
  my %idx;
  if(tie(%idx,'DB_File',$self->fn("idx"),$mode,0600,$DB_HASH)) {
    $self->{'idx'} = \%idx;
  } else {
    if($name eq 'reading') {
      $self->{'idx'} = {};
    } else {
      warn "Cannot open '".$self->fn('dat')."' $name: $!\n";
      return;
    }
  }
  unless(open($self->{'dat'},$datop,$self->fn('dat'))) {
    if($name ne 'reading') {
      warn "Cannot open '".$self->fn('dat')."' $name: $!\n";
      return;
    }
  }
  $self->{'open'} = 1;
}

sub cache_open {
  my ($self,$write) = @_;

  if($self->{'write'}) {
    $self->_open(O_RDWR|O_CREAT,'+>>:raw','writing');
  } else {
    $self->_open(O_RDONLY,'<:raw','reading');
  }
}

sub cache_close {
  my ($self) = @_;

  return unless $self->{'open'};
  $self->{'open'} = 0;
  untie $self->{'idx'};
  $self->{'idx'} = {};
  close $self->{'dat'};
}

sub _keys {
  my ($self,$class,$ver,$args) = @_; 

  $args = {%$args};
  $self->_remove_undef($args->{'args'});
  my $json = JSON->new->canonical(1)->encode($args);
  warn "$json\n" if $DEBUG > 1;
  return [md5_base64($class),$ver,md5_base64($json)];
}

sub launch_as {
  my ($self,$name,$suffix) = @_;

  my $id = identity();
  $self->cache_close;
  if($suffix) {
    my $idx = 0;
    my $newname = "$name.$id.$idx";
    while(-e $self->fn('dat',$newname)) { $idx++; }
    $name = $newname;
    open(DAT,'>',$self->fn('dat',$name)) or die "$!: ".$self->fn('dat',$name);
    close DAT;
  }
  rename($self->fn('dat'),$self->fn('dat',$name)) or die "$!";
  rename($self->fn('idx'),$self->fn('idx',$name)) or die "$!";
}

sub set {
  my ($self,$class,$ver,$keyin,$valuein,$build) = @_;

  return undef unless $self->{'open'} and $self->{'write'};
  my $key = join(':',@{$self->_keys($class,$ver,$keyin)});
  #warn "set $class $ver ".JSON->new->canonical(1)->encode($keyin)."\n";
  my $value = Compress::Zlib::memGzip(JSON->new->encode($valuein));
  return $self->_set_key($key,$value,$build);
}

sub _set_key {
  my ($self,$key,$value,$build,$length) = @_;

  return 0 if exists $self->{'idx'}{$key};
  my $start = systell $self->{'dat'};
  syswrite $self->{'dat'},$value,length($value);
  my $end = systell $self->{'dat'};
  $self->{'idx'}{$key} = JSON->new->encode([$start,$end-$start,$build]);
  $$length += length $self->{'idx'}{$key} if $length;
  return 1;
}

sub _get_key {
  my ($self,$key) = @_;

  return undef unless exists $self->{'idx'}{$key};
  my $d = JSON->new->decode($self->{'idx'}{$key});
  sysseek($self->{'dat'},$d->[0],SEEK_SET);
  my $out;
  sysread($self->{'dat'},$out,$d->[1]);
  return ($out,$d->[2]);
}

sub get {
  my ($self,$class,$ver,$keyin) = @_;

  return undef unless $self->{'open'};
  my $key = join(':',@{$self->_keys($class,$ver,$keyin)});
  my ($data) = $self->_get_key($key);
  my $out;
  return undef unless defined $data;
  eval {
    $out = JSON->new->decode(Compress::Zlib::memGunzip($data));
  };
  die "Get failed" unless $out;
  return $out;
}

my $FILESIZE = 20_000_000;
sub _cat {
  my ($self,$target,$src) = @_;

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

sub addall {
  my ($self,$source) = @_;

  $self->cache_close;
  my $offset = $self->_cat($self->fn('dat'),$source->fn('dat'));
  $self->cache_open;
  foreach my $k (keys %{$source->{'idx'}}) {
    my $v = $source->{'idx'}{$k};
    my $d = JSON->new->decode($v);
    $self->{'idx'}{$k} = JSON->new->encode([$d->[0]+$offset,$d->[1],$d->[2]]); 
  }
}

sub addgood {
  my ($self,$source,$versions,$seen,$lengths,$kindin) = @_;

  my @good_prefixes =
    map { md5_base64($_).":".$versions->{$_}.":" } keys %$versions;
  my ($all,$ndups,$nold,$nskip) = (0,0,0,0);
  foreach my $k (keys %{$source->{'idx'}}) {
    $all++;
    my ($data,$kind) = $source->_get_key($k);
    next if $kindin and $kindin ne $kind;
    $nskip++;
    next if $self->{'idx'}{$k}; # duplicate
    $ndups++;
    next unless any { substr($k,0,length $_) eq $_ } @good_prefixes;
    $nold++;
    ($seen->{$kind}||=0)++ if $seen;
    my $length = $lengths->{$kind};
    $self->_set_key($k,$data,$kind,\$length);
    $lengths->{$kind} = $length;
  }
  my $f = $source->fn('idx');
  $f =~ s!^.*/!!;
  warn sprintf("add %s: keys=%d skipped=%d dups=%d old=%d\n",$f,$all,$all-$nskip,$nskip-$ndups,$ndups-$nold);
}

sub remove {
  my ($self) = @_;

  unlink $self->fn('idx');
  unlink $self->fn('dat');
}

sub _idx_to_dat {
  my $f = $_[1];
  $f =~ s/\.idx$/.dat/;
  return $f; 
}

sub select {
  my ($self,$pattern,$from,$to,$min,$max) = @_; 

  my %name_undo;
  my @files = sort { ((-s $a)||0) <=> ((-s $b)||0) } glob("$pattern.idx");
  return undef if @files < $min;

  splice(@files,$max) if $max and @files > $max;
  my @out;
  foreach my $f (@files) {
    my @parts = split('/',$f);
    my $tmpname = "selected.".identity().".idx";
    my @tparts = @parts;
    $tparts[-1] = $tmpname;
    my $tmp = join('/',@tparts);
    rename $f,$tmp;
    rename $self->_idx_to_dat($f),$self->_idx_to_dat($tmp);
    unless(-e $tmp and -e $self->_idx_to_dat($tmp)) {
      # one may have succeeded
      rename $tmp,$f;
      rename $self->_idx_to_dat($tmp),$self->_idx_to_dat($f);
      next;
    }   
    $parts[-1] =~ s/$from/$to/;
    my $out = join('/',@parts);
    rename $tmp,$out or die;
    rename $self->_idx_to_dat($tmp),$self->_idx_to_dat($out) or die;
    $name_undo{$out} = $f; 
    push @out,EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({ filename => $out });
  }
  if(@out < $min) {
    foreach my $new (keys %name_undo) {
      rename $new,$name_undo{$new} or die;
      rename $self->_idx_to_dat($new),$self->_idx_to_dat($name_undo{$new}) or die;
      return undef;
    }   
  }
  return \@out;
}

1;
