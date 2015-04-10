#! /usr/bin/env perl

use FindBin;

my $op = "build";

$op = $ARGV[0] if @ARGV;

my @skip = qw(external inst);

opendir(HERE,$FindBin::Bin) || die "Cannot read directory";
foreach my $f (readdir HERE) {
  my $path = "$FindBin::Bin/$f";
  next unless -d $path;
  next if $f =~ /^\./;
  next if grep { $f eq $_ } @skip;
  if($op eq "build") {
    warn "Building in $path\n";
    chdir($path) || die "Cannot chidr: $!";
    system("perl Makefile.PL PREFIX=../inst") && die "making Makefile failed:$!";
    system("make") && die "make failed:$!";
    system("make install") && die "make failed: $!";
  } elsif($op eq "clean") {
    warn "Cleaning $path\n";
    chdir($path) || die "Cannot chidr: $!";
    next unless -e "$path/Makefile"; # probably cleaned already
    system("make distclean") && die "make failed: $!";
  }
}
closedir HERE;

