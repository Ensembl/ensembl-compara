package EnsEMBL::Web::Startup::XS;

use strict;
use warnings;

use FindBin;
use Config;

use JSON qw(from_json);

sub load_exs {
  my ($exs) = @_;

  my $module = $exs->{'module'};
  my $path = "$module.pm";
  $path =~ s!::!/!g;
  require $path;
  $path->import();
  if($exs->{'test'}) {
    no strict;
    my $test = $exs->{'test'};
    $test =~ /^(.*)::(.*?)$/;
    my ($root,$rest) = ($1,$2);
    die "Test $root/$rest failed" unless exists ${"${root}::"}{"${rest}::"};
  } 
  return "$exs->{'name'}: $exs->{'purpose'}";
}

sub bootstrap_begin {
  my @found;

  my $root = "$FindBin::Bin/../xs";
  my $libroot = "$root/inst/lib/perl5";
  my $arch = $Config{'archname'};
  my $version = $Config{'version'};
  my @dirs = ("","/$version","/$version/auto",
              "/$version/$arch","/$version/$arch/auto");
  @dirs = map { ("$libroot$_","$libroot/site_perl$_") } @dirs;
  unshift @INC,@dirs;
  foreach my $exs (split(/\n/,qx(find $libroot $root/external -name \\*.exs 2>/dev/null))) {
    eval {
      local $/ = undef;
      open(EXS,$exs) || die;
      push @found,load_exs(from_json(<EXS>)); 
      close EXS;
    };
  }
  return \@found;
}

1;
