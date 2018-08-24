=head
This file takes as input a file at least columns containing a slice (Chromosome:Start-End)
and a parent protein/Transcript/Gene and fetches all pseudogenes in the slice.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::FilterInput::SplitFiles;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Capture::Tiny':all';

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input
{
  my $self = shift;

  die "The path to the file has to be defined.\n" unless $self->param('path');
  die sprintf("Could not read the file %s \n", $self->param('path')) unless -e $self->param('path'); 
}

sub run
{
  my $self = shift @_;

  open(my $fd, '<', $self->param('path'));
  my $execs = 0;  
  my $size = 0;
  my @lines = ();

  ## For each line of the file
  while(defined(my $line = <$fd>))
  {
    $execs ++;
    next if($self->param("header") && $execs == 1);

    push @lines, $line;    
    if(scalar @lines % 100 == 0)
    {
      $self->dataflow_output_id({'initial' => $execs, 'lines' => \@lines}, 2);
      @lines = ();
    }
  }
}

1;
