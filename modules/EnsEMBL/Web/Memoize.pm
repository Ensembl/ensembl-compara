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

my $MAX_FILES = 8; # $MAX_FILES*65536 in total
sub prune_partners {
  my ($dir,$live) = @_;

  opendir(DIR,$dir) || return;
  my @files = grep { -f "$dir/$_" and $_ ne $live } readdir(DIR);
  closedir DIR;
  if(@files>$MAX_FILES) {
    my @age =
      map { $_->[0] } sort { $a->[1] <=> $b->[1] }
      map { [$_,[stat("$dir/$_")]->[9]] } @files;
    unlink "$dir/$age[0]";
  }
}

sub filebase {
  my ($hex) = @_;

  my $boottime = [stat("$SiteDefs::ENSEMBL_SERVERROOT/ensembl-webcode/conf/started")]->[9];
  my $mach = join('/',$SiteDefs::ENSEMBL_TMP_DIR,'procedure',
                  substr(md5_hex($SiteDefs::ENSEMBL_BASE_URL),0,8));
  my $boot = join('/',$mach,$boottime);
  my $dir = join('/',$boot,substr($hex,0,2),substr($hex,2,2));
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
