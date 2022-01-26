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

package EnsEMBL::Web::Memoize;

use strict;
use warnings;

use JSON;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path remove_tree);

my %SPECIAL_TYPES = (
  'JSON::XS::Boolean' => sub { return 0+$_[0]; },
  'JSON::PP::Boolean' => sub { return 0+$_[0]; },
);

sub _build_argument {
  my ($args,$impossible,$path) = @_;

  $path ||= [];
  if(ref($args) eq 'ARRAY') {
    return [ map { _build_argument($_,$impossible,[@$path,$_]) } @$args ];
  } elsif(ref($args) eq 'HASH') {
    return { map { $_ => _build_argument($args->{$_},$impossible,[@$path,$_]) } keys %$args };
  } elsif(ref($args)) {
    if($args->can('memo_argument')) {
      return _build_argument($args->memo_argument,$impossible,[@$path,'_magic']);
    } elsif($SPECIAL_TYPES{ref($args)}) {
      return $SPECIAL_TYPES{ref($args)}->($args);
    } else {
      if(defined $impossible) {
        $$impossible = 1;
        return undef;
      }
      die "Unknown blessed object, cannot memoize: $args [".ref($args)."] at ".join(", ",@$path)."\n";
    }
  } else {
    return $args;
  }
}

sub hexkey {
  my ($tag) = @_;

  my $json = JSON->new->canonical->encode($tag);
  my $out = md5_hex($json);
  return $out;
}

sub clear_old_boots {
  my ($base,$live) = @_;

  opendir(BASE,$base) || return;
  my @files = grep { /^\d+$/ and $_ ne $live } readdir(BASE);
  closedir BASE;
  remove_tree("$base/$_") for @files;
}

# $MEMOIZE_SIZE contains [mult,size,mbs]
# Maximum total cache size = mbs*2^mult
# Maximum number files = size*2^mult
# Maximum individual file size = mbs
# To help filesystems, size should not be larger than 4096
# dev [12,32,1024*1024*2] =>
#   max total size = 8Gb, max files = 131072, max file size = 2Mb
# live [14,32,1024*1024*4] =>
#   max total size = 64Gb, max files = 524208, max file size = 4Mb

sub prune_partners {
  my ($dir,$live) = @_;

  opendir(DIR,$dir) || return;
  my @files = grep { -f "$dir/$_" and $_ ne $live } readdir(DIR);
  closedir DIR;
  my (%size,%age);
  foreach my $file (@files) {
    my @s = stat("$dir/$file");
    $size{$file} = $s[7];
    $age{$file} = $s[9];
  }
  if(@files>$SiteDefs::MEMOIZE_SIZE->[1]) {
    my @age = sort { $age{$a} <=> $age{$b} } @files;
    unlink "$dir/$age[0]";
  }
  my $size = 0;
  my @size = sort { $size{$a} <=> $size{$b} } @files;
  foreach my $file (@size) {
    $size += $size{$file};
    if($size>$SiteDefs::MEMOIZE_SIZE->[2]) {
      unlink "$dir/$file";
    }
  }
}

sub mult {
  my ($hex) = @_;

  my $val = hex(substr($hex,0,8)) & ((1<<$SiteDefs::MEMOIZE_SIZE->[0])-1);
  my $digits = int(($SiteDefs::MEMOIZE_SIZE->[0]+3)/4);
  my $out = sprintf("%0${digits}x",$val);
  my @mult;
  while(length $out) { push @mult,substr($out,0,2,''); }
  return join('/',@mult);
}

sub filebase {
  my ($hex) = @_;

  my $bootfile = "$SiteDefs::ENSEMBL_TMP_DIR/procedure/started";
  my $boottime = [stat($bootfile)]->[9];
  my $mach = join('/',$SiteDefs::ENSEMBL_TMP_DIR,'procedure',
                  substr(md5_hex($SiteDefs::ENSEMBL_BASE_URL),0,8));
  my $boot = join('/',$mach,$boottime);
  my $dir = join('/',$boot,mult($hex));
  make_path($dir);
  clear_old_boots($mach,$boottime);
  prune_partners($dir,$hex);
  return "$dir/$hex";
}

sub _get_cached {
  my ($base) = @_;
  local $/ = undef;

  my $fn = "$base.data";
  return (0,undef) unless -e $fn;
  open(FN,$fn) || return (0,undef);
  my $raw = <FN>;
  close FN;
  utime(undef,undef,$fn);
  return (1,JSON->new->decode($raw)->{'value'});
}


sub _set_cached {
  my ($base,$data) = @_;

  open(FN,'>',"$base.tmp.$$") || return;
  print FN JSON->new->encode({value => $data });
  close FN;
  rename("$base.tmp.$$","$base.data");
}

sub _memoized {
  my ($name,$fn,$args) = @_;

  return $fn->(@$args) unless $SiteDefs::MEMOIZE_ENABLED;
  my $impossible = 0;
  my $tag = {
    call => $name,
    arguments => _build_argument($args,\$impossible),
    machine => $SiteDefs::ENSEMBL_BASE_URL,
    version => $SiteDefs::ENSEMBL_VERSION,
    boottime => [stat("${SiteDefs::ENSEMBL_TMP_DIR}/procedure/started")]->[9],
  };
  my $base;
  unless($impossible) {
    my $hex = hexkey($tag);
    $base = filebase($hex);
    my ($found,$value) = _get_cached($base);
    warn "CACHE $name : hit=$found\n" if $SiteDefs::MEMOIZE_DEBUG;
    return $value if $found;
  }
  my $out = $fn->(@$args);
  _set_cached($base,$out) if $base;
  if(!$impossible and $SiteDefs::MEMOIZE_DEBUG) {
    open(FN,'>',"$base.key") || return;
    print FN JSON->new->encode($tag);
    close FN;
  }
  return $out;
}

sub memoize {
  my ($fn) = @_;
  my ($pkg) = caller;

  no strict;
  my $name = "${pkg}::${fn}";
  *{"${name}_cached"} = sub { return _memoized($name,\&{$name},\@_); };
}

1;
