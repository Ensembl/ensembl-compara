package EnsEMBL::Web::Component::Gene::ComparaTreeAlign;

use strict;
use warnings;
use Bio::AlignIO;
use IO::Scalar;
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self           = shift;
  my $object         = $self->object;

  #----------
  # Get the ProteinTree object 
  my $tree   = $object->get_ProteinTree;

  #----------
  # Return the text representation of the tree
  my $htmlt = qq(
<p>Multiple sequence alignment in FASTA format:</p>
<p>The species included in the tree can be configured using the
'configure tree' link in the left panel.<p> 
<pre>%s</pre>);
  my $align_format = 'fasta'; # TODO: user configurable format
  my $formatted; # Variable to hold the formatted alignment string
  my $SH = IO::Scalar->new(\$formatted);
  #print $SH "FOO\n";
  my $aio = Bio::AlignIO->new( -format => $align_format, -fh => $SH );
  $aio->write_aln( $tree->get_SimpleAlign );

  return sprintf( $htmlt, $formatted );
}

1;
