#!/usr/local/bin/perl

use strict;
use Image::Size;
use CGI qw(escapeHTML);

use FindBin qw($Bin);
use File::Basename qw( dirname );

# Load libraries needed for reading config -----------------------------------
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  unshift @INC, "$SERVERROOT";
  eval{ require SiteDefs };
}

our $MAX_WIDTH  = 400;
our $MAX_HEIGHT = 300;
my @directory_listing = reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS;

@ARGV = qw(i img) unless @ARGV;
while( my $dir = shift @ARGV) {
  $dir =~ s/\/+$//;
  my $last = undef;
  my %images = ();
  my %dirs   = ();
  my $flag = $dir =~ s/^!//;
  foreach my $root ( @directory_listing ) {
    my $dfp = "$root/$dir";
    next unless -e $dfp && -d $dfp && opendir( DH, $dfp );
    $last = $dfp;
    while( my $fn=readdir(DH) ) {
      my $fp = "$dfp/$fn";
      next if $fn =~ /^\./ || $fn =~ /CVS/;
      if( -d $fp ) {
        $dirs{$fn} = $fn;
        push @ARGV, "!$dir/$fn";
      } else {
        next unless $fn =~ /^(\S+)\.(gif|png|jpg)$/;
        my ($x,$y) = imgsize $fp;
        $images{$fn} = {
          'fn'   => $fn,
          'type' => $2,
          'h'    => $y,
          'w'    => $x,
          'sz'   => -s $fp
        };
      }
    }
  }
  next unless $last && ( keys %images || keys %dirs );
  open O, ">$last/index.html" || die "cant open dir to write";
  printf O '<html>
<head>
  <title>Images in directory %s</title>
</head>
<body>
  <h2>Images in directory %s</h2>
  <p>There are %d sub-directories and %d images in this directory.</p>
  <table class="img-table">
    <thead>
    <tr>
      <th>File</th>
      <th>Image</th>
      <th>Type</th>
      <th>Size</th>
      <th>Bytes</th>
    </tr>
    </thead>
    <tbody>', escapeHTML($dir), escapeHTML($dir), scalar( keys %dirs), scalar(keys %images);
  my $class=1;
  $dirs{'..'} = '[up]' if $flag;
  foreach( sort { lc($a) cmp lc($b) } keys %dirs ) {
    printf O '
    <tr class="img-%s">
      <td colspan="2"><a href="%s/">%s</a></td>
      <td>dir</td>
      <td colspan="2">&nbsp;</td>
    </tr>', $class, escapeHTML($_),escapeHTML($dirs{$_});
    $class = 3 - $class;
  }
  foreach( sort { lc($a) cmp lc($b) } keys %images ) {
    my $i = $images{$_};
    my $t = escapeHTML($i->{'fn'});
    my $a = '';
    if( $i->{w}<$MAX_WIDTH && $i->{h}<$MAX_HEIGHT ) {
      $a = sprintf '<img src="%s" title="%s" alt="%s" style="height:%dpx;width:%dpx" />', 
        $t, $t, $t, $i->{h}, $i->{w};
    } else {
      my $r = $i->{w}/$MAX_WIDTH;
         $r = $i->{h}/$MAX_HEIGHT if $i->{h}/$MAX_HEIGHT > $r;
      $a = sprintf '<a rel="external" href="%s"><img src="%s" title="Click to see full version of %s" alt="%s" style="border: 1px solid red;height:%dpx;width:%dpx" /></a>',
        $t, $t, $t, $t, $i->{h}/$r, $i->{w}/$r
    }
    
    printf O '
    <tr class="img-%s">
      <td>%s</td>
      <td>%s</td>
      <td>%s</td>
      <td>%d x %d</td>
      <td>%d</td>
    </tr>',
      $class, $t, $a, $i->{type},$i->{w}, $i->{h}, $i->{sz};
    $class = 3 - $class;
  }
  print O '
    </tbody>
  </table>
</body>
</html>';
  close O;
}

1;
