package EnsEMBL::Web::Memoize;

use strict;
use warnings;

use SiteDefs;
use JSON;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path remove_tree);

my %SPECIAL_TYPES = (
  'JSON::XS::Boolean' => sub { return 0+$_[0]; },
  'JSON::PP::Boolean' => sub { return 0+$_[0]; },
);

sub _build_argument {
  my ($args) = @_;

  if(ref($args) eq 'ARRAY') {
    return [ map { _build_argument($_) } @$args ];
  } elsif(ref($args) eq 'HASH') {
    return { map { $_ => _build_argument($args->{$_}) } keys %$args };
  } elsif(ref($args)) {
    if($args->can('memo_argument')) {
      return _build_argument($args->memo_argument);
    } elsif($SPECIAL_TYPES{ref($args)}) {
      return $SPECIAL_TYPES{ref($args)}->($args);
    } else {
      die "Unknown blessed object, cannot memoize: $args [".ref($args)."]\n";
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
  my $tag = {
    call => $name,
    arguments => _build_argument($args),
    machine => $SiteDefs::ENSEMBL_BASE_URL,
    version => $SiteDefs::ENSEMBL_VERSION,
    boottime => [stat("${SiteDefs::ENSEMBL_TMP_DIR}/procedure/started")]->[9],
  };
  my $hex = hexkey($tag);
  my $base = filebase($hex);
  my ($found,$value) = _get_cached($base);
  warn "CACHE $name : hit=$found\n" if $SiteDefs::MEMOIZE_DEBUG;
  return $value if $found;
  my $out = $fn->(@$args);
  _set_cached($base,$out);
  if($SiteDefs::MEMOIZE_DEBUG) {
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
