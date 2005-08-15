use POSIX qw(ceil);
my $species       = "Bos_taurus";
my @chromosomes   = (1..30);
my $column_width  = 16;
my @row_heights   = qw(115 69);
my $left_offset   = 0;
my $top_offset    = 0;

my $columns    = ceil( @chromosomes / @row_heights );
my $left       = $left_offset;
my $top        = $top_offset;
my $row_height = shift @row_heights;
my $counter    = 0;

print qq(<map id="karyotypes" name="karyotypes">\n);
foreach my $chr (@chromosomes) {
  my $right  = $left + $column_width;
  my $bottom = $top  + $row_height - 1;
  print qq(  <area shape="rect" coords="$left,$top,$right,$bottom" href="/$species/mapview?chr=$chr"  alt="chromosome $chr" title="chromosome $chr" />\n);
  $counter ++;
  $left += $column_width;
  if( $counter > $columns ) {
    $counter = 0;
    $left    = $left_offset;
    $top     += $row_height;
    $row_height = shift @row_heights;
  }
}
print "</map>\n";
