#!/usr/local/bin/perl

#############################################################################
#
# SCRIPT TO CONVERT RAW PDOC FRAMESETS INTO SOMETHING WE CAN EMBED IN THE 
# ENSEMBL SITE 
#
#############################################################################


use strict;
use FindBin qw($Bin);
use File::Basename qw( dirname );
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);

######################### cmdline options #####################################
my ($dir);
&GetOptions(
      'dir=s' => \$dir,
);

use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
}

my $path = "$SERVERROOT/$dir";

########################## Process files #######################################

my @files;

## Get all INPUT files from this directory
opendir(DIR, $path) or die "can't open dir $path:$!";
while (defined(my $f = readdir(DIR))) {
  next unless $f =~ /html$/;
  push (@files, $f);
}
close DIR;

my $title;

## Process each one
foreach my $file (@files) {
  open (INPUT, "<", $path.$file) or die "Couldn't open html page $file: $!";
  my $content = qq(<!--#set var="decor" value="none"-->\n);
  my $title_start = 0;
  while (<INPUT>) {
    my $line = $_;
    ## remove body tags to make frameset work!
    next if $line =~ /body>/;
    ## grab page title
    if ($file eq 'index.html') {
      if ($line =~ /<title>/i) {
        if ($line =~ /<title>(\s?)(\w+)/i) {
          ($title = $line) =~ s#</title>##i;
        }
        else {
          $title_start = 1;
          next;
        }
      }
      if ($title_start) {
        ($title = $line) =~ s#</title>##i;
        $title_start = 0;
      }
    }
    ## make all links local (so works correctly on archives)
    $line =~ s#http://www.ensembl.org##g;
    $content .= $line;
  }
  close INPUT;
  ## Copy original index page to iframe page
  my $output = $file eq 'index.html' ? 'iframe.html' : $file;
  open (OUTPUT, ">", $path.$output) or die "Couldn't open html page $output: $!";
  print OUTPUT $content;
  close OUTPUT;
}

## Create new index page

my $index = qq(
<html>
<head>
<title>$title</title>
</head>
<body>
<iframe src="iframe.html  id="pdoc_iframe" width="100%" height="1000px"></iframe>
</body>
</html>
);

open (INDEX, ">", $path.'index.html') or die "Couldn't open index.html: $!";
print INDEX $index;
close INDEX;

exit;
