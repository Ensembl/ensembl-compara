package EnsEMBL::Web::Factory::GeneTree;

### NAME: EnsEMBL::Web::Factory::GeneTree
### Simple factory to create a gene tree object from a stable ID 

### STATUS: Stable

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self     = shift;    
  
  my $gt = $self->param('gt');
     
  return $self->problem('fatal', 'Valid Gene Tree ID required', 'Please enter a valid gene tree ID in the URL.') unless $gt;

  my $cdb = ($gt =~ /^EGGT/) ? 'compara_pan_ensembl' : 'compara';
  my $database = $self->database($cdb);
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the compara database.') unless $database;
  
  my $tree = $database->get_ProteinTreeAdaptor->fetch_by_stable_id($gt);
 
  if ($tree) {
    $self->DataObjects($self->new_object('GeneTree', $tree, $self->__data));
  }
  else { 
    return $self->problem('fatal', "Could not find Marker $gt", "Either $gt does not exist in the current Ensembl database, or there was a problem retrieving it.");
  }
  
  $self->param('gt', $gt);
}

1;
  
