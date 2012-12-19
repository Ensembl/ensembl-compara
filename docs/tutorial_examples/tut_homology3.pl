use Bio::AlignIO;

my $simple_align = $homology->get_SimpleAlign();
my $alignIO = Bio::AlignIO->newFh(
    -interleaved => 0,
    -fh => \*STDOUT,
    -format => "clustalw",
    -idlength => 20);

print $alignIO $simple_align;
