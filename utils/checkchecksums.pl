#! /usr/bin/env perl

use strict;
use warnings;

=pod

chechchecksums.pl verifies the checksums on the website. It has two modes:
one generates new checksum files, and one verifies existing ones are
correct.  This is a laborious business and so the script is designed to
recover from crashing by carrying on where it left off.

Both modes involve first traversing the site and building a current list of
checksums, the only difference is what's done with this information. So the
first stage is to generate a single file containing all the current
checksums. This is created in the same directory as which the script runs.
Checksums listed in this file are not recreated on subsequent runs. If the
--reset flag is given, then this file is removed and all checksums
generated afresh. 

This generation step is a separate run of the script, --generate. Longer
term it might make sense to make this a cronjob. The file it creates is
called CHECKSUMS.txt

Once the current list has been generated, the --check flag verifies the
current checksums are correct and complains if not. The --replace flag
replaces the checksums on the FTP site with the generated ones.

All three invocations take a directory to use as the base of the check,
which is relative to the FTP site (ie begins /pub/...). Checksums for
different releases etc are stored separately in the various files and so
there's no need to reset between releases, checks or replaces. All three
modes only consider/manipulate those files and checksums within the given
path.

The relevant files are only visible on ensweb-1-19, so the hard work is
done via ssh by this script, which can be run anywhere you can get
passwordless ssh access to ensweb-1-19 as the current user.

=cut

use List::Util qw(sum);
use List::MoreUtils qw(uniq);
use Getopt::Long;
use FindBin qw($Bin);

my ($generate,$reset,$check,$replace,$masterfile,$redo);

GetOptions("generate" => \$generate,
           "reset" => \$reset,
           "redo" => \$redo,
           "check" => \$check,
           "replace" => \$replace,
           "masterfile=s" => \$masterfile);

my $mode = 0;
$mode |= 1 if $generate;
$mode |= 2 if $check;
$mode |= 4 if $replace;
$mode = { 1 => 'generate', 2 => 'check', 4 => 'replace'}->{$mode};
die "Must specify exactly one of generate, check, replace\n" unless $mode;
die "Must specify path" unless @ARGV;
my $root = $ARGV[0];
$root = "/$root" unless $root =~ m!^/!;
$root =~ s!/$!!;
$masterfile = "$Bin/CHECKSUMS.txt" unless $masterfile;

my $BASE = "/nfs/ftp_ensembl_int";

sub investigate_files {
  my %files;

  my $cmd = "ssh ensweb-1-19 find $BASE$root -type f";
  open(DIRS,"$cmd |") or die "Cannot run '$cmd': $!";
  while(<DIRS>) {
    chomp; chomp;
    s!^$BASE!!;
    my @dir = split(m!/!);
    my $fn = pop @dir;
    push @{$files{join("/",@dir)}||=[]},$fn;
  }
  close DIRS;
  return \%files;
}

sub eliminate_seen {
  my ($files,$master) = @_;

  foreach my $d (keys %$files) {
    my $e = [];
    foreach my $f (@{$files->{$d}}) {
      push @$e,$f unless exists $master->{"$d/$f"};
    }
    $files->{$d} = $e;
  }
}

sub redo_master {
  my ($master) = @_;
  foreach my $k (keys %$master) {
    delete $master->{$k} if $k =~ m!^$root($|/)!;
  }
}

sub load {
  unless(-e $masterfile) {
    warn "Cannot find '$masterfile'\n  Starting it afresh.\n";
    return {};
  }
  my %master;
  open(MASTER,$masterfile) || die "Cannot read '$masterfile' $!";
  while(<MASTER>) {
    chomp; chomp;
    my ($path,$rest) = split(/ /,$_,2);
    $master{$path} = $rest;
  }
  return \%master;
}

sub generate {
  my ($master,$d,$f) = @_;

  # Also index /bin/ls to ensure reporting of filename even when
  #   @$f == 1. That it is ls is not significant, we just know it is small
  #   and always there.
  my $cmd = "cd $BASE$d; sum /bin/ls ".join(' ',@$f);
  $cmd = "bash -c '$cmd'";
  $cmd = "ssh ensweb-1-19 \"$cmd\"";
  open(DIRS,"$cmd |") or die "Cannot run '$cmd': $!";
  while(<DIRS>) {
    chomp; chomp;
    my $fn = $_;
    $fn =~ s!^\s*\d+\s+\d+\s+!!;
    next if $fn eq '/bin/ls';
    $master->{"$d/$fn"} = $_;
  }
  close DIRS;
}

sub save {
  my ($master) = @_;

  open(MASTER,">","$masterfile.new") || die "Cannot write '$masterfile' $!";
  foreach my $k (keys %$master) {
    print MASTER "$k $master->{$k}\n";
  }
  close MASTER;
  rename("$masterfile.new",$masterfile);
}

sub hashify_checksum_file {
  my ($in) = @_;

  my %out;
  foreach (split(m!\n!,$in)) {
    chomp; chomp;
    my $fn = $_;
    $fn =~ s!^\s*\d+\s+\d+\s+!!;
    $out{$fn} = $_;
  }
  return \%out;
}

sub get_checksum_file {
  my ($dir) = @_;

  my $in = "";
  {
    local $/ = undef;
    open(CHECKSUMS,"ssh ensweb-1-19 zcat $BASE$dir/CHECKSUMS.gz |") or
      die "Cannot read checksums: $!";
    $in = <CHECKSUMS>;
    close CHECKSUMS;
  }
  return hashify_checksum_file($in); 
}

sub perdir {
  my ($master) = @_;

  my %out;
  foreach my $k (keys %$master) {
    my @dir = split(m!/!,$k);
    my $fn = pop @dir;
    next if $fn eq 'CHECKSUMS.gz';
    ($out{join("/",@dir)}||={})->{$fn} = $master->{$k};
  }
  return \%out;
}

sub compare_checksums {
  my ($d,$master,$exist) = @_;
  my @x = ($master,$exist);
  my ($diff,$miss) = (0,0);
  my %files;
  foreach my $i (0..@x) {
    foreach my $k (keys %{$x[$i]}) {
      (($files{$k}||=[])->[$i] = $x[$i]->{$k}) =~ s/\s+/ /g;
    }
  }
  my @eg=([],[],[]);
  my @eghead=('extra','missing','incorrect');
  foreach my $k (keys %files) {
    if(not defined $files{$k}->[0]) {
      push @{$eg[0]},$k;
    } elsif(not defined $files{$k}->[1]) {
      push @{$eg[1]},$k;
    } elsif($files{$k}->[0] ne $files{$k}->[1]) {
      push @{$eg[2]},$k;
    }
  }
  if(@{$eg[0]} or @{$eg[1]} or @{$eg[2]}) {
    warn "\n\n$d\n";
    foreach my $i (0..$#eg) {
      foreach my $j (0..$#{$eg[$i]}) {
        warn "    '$eg[$i]->[$j]' $eghead[$i]\n";
        if($j > 2) {
          warn "    ...\n";
          last;
        }
      }
    }
  }
}

sub update_file {
  my ($d,$contents) = @_;

  system("mkdir -p test/$d");
  open(CHECKSUMS,"| gzip -c >test/$d/CHECKSUMS.gz") || die "$d: $!";

  my $path = "$BASE/$d/CHECKSUMS.gz";
  open(CHECKSUMS,qq(| ssh ensweb-1-19 bash -c "gzip -9 >$path")) or
    die "Cannot write checksums: $!";
  print CHECKSUMS $contents;
  close CHECKSUMS;
}

sub file_changed {
  my ($old,$new) = @_;

  my %all;
  $all{$_} = 1 for keys %$old;
  $all{$_} = 1 for keys %$new;
  foreach my $f (keys %all) {
    my $x = $old->{$f};
    my $y = $new->{$f};
    return 1 unless defined $old->{$f} and defined $new->{$f};
    $x =~ s/\s+/ /g;
    $y =~ s/\s+/ /g;
    return 1 unless $x eq $y;
  }
  return 0;
}

if($mode eq 'generate' and $reset) {
  unlink($masterfile);
}

my $master = load();
if($mode eq 'generate') {
  warn "Investigating FTP site\n";
  my $files = investigate_files();
  my $total = sum(map { scalar(@$_) } values %$files);
  warn sprintf("%d files found in %d directories.\n",
               $total,scalar keys %$files);
  eliminate_seen($files,$master) unless $redo;
  redo_master($master) if $redo;
  my $total2 = sum(map { scalar(@$_) } values %$files);
  warn sprintf("%d files eliminated as already checked.\n",$total-$total2);
  my $i = 0;
  foreach my $d (keys %$files) {
    $i++;
    warn sprintf("  Investigating directory %d of %d\n",
                 $i,scalar keys %$files);
    while(my @f = splice($files->{$d},0,50)) {
      generate($master,$d,\@f);
      warn sprintf("    Checksummed %d files\n",scalar @f);
      save($master);
    }
  }
} elsif($mode eq 'check') {
  warn "Finding existing FTP files\n";
  my $perdir = perdir($master);
  my $files = investigate_files();
  my %current;
  my @ckdirs;
  foreach my $d (keys %$files) {
    next unless grep { $_ eq 'CHECKSUMS.gz' } @{$files->{$d}};
    push @ckdirs,$d;
  }
  my $i = 0;
  foreach my $d (@ckdirs) {
    $i++;
    warn sprintf("Getting CHECKSUM file %d/%d\n",$i,scalar @ckdirs);
    $current{$d} = get_checksum_file($d);
  }
  foreach my $d (keys %$perdir) {
    next unless $d =~ /^$root/;
    compare_checksums($d,$perdir->{$d},$current{$d});
  }
  warn "Done. If no warnings above, you are ok.\n";
} elsif($mode eq 'replace') {
  my $perdir = perdir($master);
  my @all;
  foreach my $d (keys %$perdir) {
    next unless $d =~ /^$root/;
    push @all,$d;
  }
  my $i = 0;
  my $n = @all;
  foreach my $d (@all) {
    $i++;
    warn "Generating $i/$n\n";
    my $contents = "";
    $contents .= join("\n",map { $perdir->{$d}{$_} } sort keys %{$perdir->{$d}})."\n";
    my $old = get_checksum_file($d);
    my $new = hashify_checksum_file($contents);
    if(file_changed($old,$new)) {
      warn "  updating\n";
      update_file($d,$contents);
    }
  }  
}

1;
