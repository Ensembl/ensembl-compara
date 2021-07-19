#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#############################################################################
#
# SCRIPT TO CONVERT RAW PDOC FRAMESETS INTO SOMETHING WE CAN EMBED IN THE 
# ENSEMBL SITE 
#
#############################################################################


use strict;
use Getopt::Long qw(:config no_ignore_case);

######################### cmdline options #####################################
my $dir;
&GetOptions(
      'dir=s' => \$dir,
);

########################## Process files #######################################

## Remove trailing slash, just to be on safe side! (add it back in manually)
(my $path = $dir) =~ s#/$##;
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
  open (INPUT, "<", $path.'/'.$file) or die "Couldn't open html page $path/$file: $!";
  my $content = qq(<!--#set var="decor" value="none"-->\n);
  my $title_start = 0;
  while (<INPUT>) {
    my $line = $_;
    ## remove body tags to make frameset work!
    next if $line =~ /body>/;
    if ($file eq 'index.html') {
      ## remove borders from framesets
      if ($line =~ /<frameset/i) {
        chomp($line);
        $line =~ s/>//;
        $line .= qq( border="0" frameborder="0" framespacing="0">\n);
      }
      ## grab page title
      if ($line =~ /<title>/i) {
        if ($line =~ /<title>(\s?)(\w+)/i) {
          ($title = $line) =~ s#</title>##i;
        }
        else {
          $title_start = 1;
          $content .= $line;
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
  open (OUTPUT, ">", $path.'/'.$output) or die "Couldn't open html page $output: $!";
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
<iframe src="iframe.html" id="pdoc_iframe" width="100%" height="1000px"></iframe>
</body>
</html>
);

open (INDEX, ">", $path.'/index.html') or die "Couldn't open index.html: $!";
print INDEX $index;
close INDEX;

exit;
