package EnsEMBL::Web::Memoize;

use strict;
use warnings;

use SiteDefs;
use JSON;
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path);

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

sub filebase {
  my ($hex) = @_;

  my $dir = join('/',
    $SiteDefs::ENSEMBL_TMP_DIR,'procedure',
    substr($hex,0,2),substr($hex,2,2)
  );
  make_path($dir);
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
# TODO num tidy
# TODO boot tidy
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
  use Data::Dumper;
  #warn Dumper($tag);
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
