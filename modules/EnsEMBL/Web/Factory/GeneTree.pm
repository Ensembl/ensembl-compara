package EnsEMBL::Web::Factory::GeneTree;

### NAME: EnsEMBL::Web::Factory::GeneTree
### Simple factory to create a gene tree object from a stable ID 

### STATUS: Stable

use strict;
use warnings;
no warnings 'uninitialized';

use Carp qw(cluck);
use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self     = shift;    
  my $database = $self->database('compara');
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the compara database.') unless $database;
  
  my $id = $self->param('genetree_id');
  cluck "CREATING OBJECT $id";
     
  return $self->problem('fatal', 'Valid Gene Tree ID required', 'Please enter a valid gene tree ID in the URL.') unless $id;
  
  my $tree = $database->get_ProteinTreeAdaptor->fetch_by_stable_id($id);
 
  if ($tree) {
    $self->DataObjects($self->new_object('GeneTree', $tree, $self->__data));
  }
  else { 
    return $self->problem('fatal', "Could not find Marker $id", "Either $id does not exist in the current Ensembl database, or there was a problem retrieving it.");
  }
  
  $self->param('genetree_id', $id);
}

1;
  
