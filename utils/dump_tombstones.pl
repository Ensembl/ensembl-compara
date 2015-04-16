#! /usr/bin/env perl

# Dump tombstones in human-readable form. By default creates HTML file
# to go into sandbox.
#
# --filename=full-path
#    only dump tombstones in the given file.
#    Default is to dump all tombstone files in log directory
#
# --format=text|full|html [default: html]
#   html: dump to file in htdocs,             most recent first
#   text: dump to stdout without stacktraces, most recent last
#   full: dump to stdout with    stacktraces, most recent last

use strict;
use warnings;

use FindBin qw($Bin);

use POSIX qw(strftime);

BEGIN {
  require "$Bin/../ctrl_scripts/include.pl";
};

use SiteDefs;
use JSON qw(from_json);
use Getopt::Long;

my $MAXLEN = 100;

my $reverse = 0;

my ($filename,$format);

$format = "html";
GetOptions("filename=s" => \$filename,
           "format=s"   => \$format);
$reverse = 1 if $format eq 'html';

my @tombstones;

my @filenames;
if($filename) {
  push @filenames,$filename;
} else {
  my $log_dir = $SiteDefs::ENSEMBL_LOGDIR;
  opendir(LOGS,$log_dir) || exit 1;
  foreach my $f (readdir LOGS) {
    next if $f !~ /tombstone/;
    my $fn = "$log_dir/$f";
    next unless -f $fn;
    push @filenames,$fn;
  }
  closedir LOGS;
}
foreach my $fn (@filenames) {
  open(FILE,$fn) || next;
  while(my $line = <FILE>) {
    eval {
      push @tombstones,from_json($line);
    };
  } 
  close FILE;
}

foreach my $t (@tombstones) {
  $t->{'epoch'} = strftime("%s",@{$t->{'gmtime'}});
}
@tombstones = sort { $a->{'epoch'} <=> $b->{'epoch'} } @tombstones;

my $truncated = 0;
if(@tombstones > $MAXLEN) {
  @tombstones = splice(@tombstones,-$MAXLEN,$MAXLEN);
  $truncated = 1;
}

@tombstones = reverse @tombstones if $reverse;

my %fmt = (
  text => "  %23s (tombstone: %10s %10s)\n    %s\n    %s:%s\n    %s\n\n",
  full => "  %23s (tombstone: %10s %10s)\n    %s\n    %s:%s\n    %s\n\n%s\n\n",
  html => q(
    <div style="margin: 8px; padding: 8px; border: 1px solid #cccccc;">
      <h2>%s (%s %s)</h2>
      <dl>
        <dt>SERVER_ROOT</dt>
        <dd>%s</dd>
        <dt>file:line</dt>
        <dd>%s:%s</dd>
        <dt>subroutine</dt>
        <dd>%s</dd>
      </dl>
      <dl>
        <dt><a href="#" onclick="$(this).parents('dl').find('dd').toggle(); return false">Click for stack trace</a></dt>
        <dd style="display: none;"><pre>%s</pre></dd>
      </dl>
    </div>
)
);
my $all = '';
my $fmt = $fmt{$format};
foreach my $t (@tombstones) {
  my $time = strftime("%Y-%m-%d %H:%M:%S UTC",@{$t->{'gmtime'}});
  my $file = $t->{'filename'};
  $file =~ s!^$SiteDefs::ENSEMBL_SERVERROOT/!!;
  my $str = sprintf($fmt,$time,$t->{'author'},$t->{'rip'},
                    $SiteDefs::ENSEMBL_SERVERROOT,$file,
                    $t->{'line'},$t->{'subroutine'},$t->{'stack_trace'});
  $all .= $str;
  print $str unless $format eq 'html';
}
if($truncated) {
  print "Truncated to $MAXLEN most recent entries\n" unless $format eq 'html';
  $all .= "Truncated to $MAXLEN most recent entries\n";
}

if($format eq 'html') {
  open(HTML,">$SiteDefs::ENSEMBL_SERVERROOT".
            "/ensembl-webcode/htdocs/tombstones.html")
    or die "Cannot write html file: $!";
  print HTML $all;
  close HTML;
  print "Dumped to:\n  ${SiteDefs::ENSEMBL_SITE_URL}tombstones.html\n";
}

1;

