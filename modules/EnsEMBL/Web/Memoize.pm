package EnsEMBL::Web::Memoize;

use strict;
use warnings;

use SiteDefs;
use JSON;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path remove_tree);

sub _build_argument {
  my ($args) = @_;

  if(ref($args) eq 'ARRAY') {
    return [ map { _build_argument($_) } @$args ];
  } elsif(ref($args) eq 'HASH') {
    return { map { $_ => _build_argument($args->{$_}) } keys %$args };
  } elsif(ref($args)) {
    if($args->can('memo_argument')) {
      return $args->memo_argument;
    } else {
      die "Unknown blessed object, cannot memoize: $args\n";
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

  return if int rand 1000;
  opendir(BASE,$base) || return;
  my @files = grep { /^\d+$/ and $_ ne $live } readdir(BASE);
  closedir BASE;
  remove_tree("$base/$_") for @files;
}

my $MULT = 3; # 2^(4*$MULT) buckets
my $MAX_FILES = 32; # $MAX_FILES*$MULT in total
my $MAX_BUCKET_SIZE = 1024*1024*2;
# Max total cache size = $MAX_BUCKET_SIZE*number of buckets
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
  if(@files>$MAX_FILES) {
    my @age = sort { $age{$a} <=> $age{$b} } @files;
    unlink "$dir/$age[0]";
  }
  my $size = 0;
  my @size = sort { $size{$a} <=> $size{$b} } @files;
  foreach my $file (@size) {
    $size += $size{$file};
    if($size>$MAX_BUCKET_SIZE) {
      unlink "$dir/$file";
    }
  }
}

sub filebase {
  my ($hex) = @_;

  my $boottime = [stat("$SiteDefs::ENSEMBL_SERVERROOT/ensembl-webcode/conf/started")]->[9];
  my $mach = join('/',$SiteDefs::ENSEMBL_TMP_DIR,'procedure',
                  substr(md5_hex($SiteDefs::ENSEMBL_BASE_URL),0,8));
  my $boot = join('/',$mach,$boottime);
  my $mult = substr($hex,0,$MULT);
  my @mult;
  while(length $mult) { push @mult,substr($mult,0,2,''); }
  my $dir = join('/',$boot,@mult);
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

my $DEBUG = 1;

sub _set_cached {
  my ($base,$data) = @_;

  open(FN,'>',"$base.tmp.$$") || return;
  print FN JSON->new->encode({value => $data });
  close FN;
  rename("$base.tmp.$$","$base.data");
}

# TODO skip cache
# TODO dump tag debug
# TODO size tidy
# TODO num tidy Y
# TODO boot tidy Y
# TODO boottime config

sub _memoized {
  my ($name,$fn,$args) = @_;

  my $tag = {
    call => $name,
    arguments => _build_argument($args),
    machine => $SiteDefs::ENSEMBL_BASE_URL,
    version => $SiteDefs::ENSEMBL_VERSION,
    boottime => [stat("${SiteDefs::ENSEMBL_SERVERROOT}/ensembl-webcode/conf/started")]->[9],
  };
  my $hex = hexkey($tag);
  my $base = filebase($hex);
  my ($found,$value) = _get_cached($base);
  warn "CACHE $name : hit=$found\n";
  return $value if $found;
  my $out = $fn->(@$args);
  _set_cached($base,$out);
  if($DEBUG) {
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
