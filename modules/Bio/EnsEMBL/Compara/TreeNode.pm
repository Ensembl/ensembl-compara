=head1 NAME

TreeNode - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::TreeNode;

use strict;
use Bio::Species;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;


sub new {
  my ($class, @args) = @_;
  my $self = {};

  bless $self,$class;
  
  $self->{'_children_nodes'} = [];
  
  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $adaptor) = rearrange([qw(DBID ADAPTOR)], @args);

    $self->dbID($dbid)               if($dbid);
    $self->adaptor($adaptor)         if($adaptor);
  }

  return $self;
}

=head2 dbID

  Arg [1]    : int $dbID (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: give the adaptor if known
 Example :
 Returns :
 Args    :

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


sub parent_node {
  my ($self,$arg) = @_;

  if (defined($arg)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::TreeNode] not a [$arg]")
        unless($arg->isa('Bio::EnsEMBL::Compara::TreeNode'));
    $self->{'_parent_node'} = $arg;
  }
  return $self->{'_parent_node'};
}


sub children_nodes {
  my $self = shift;
  return $self->{'_children_nodes'};
}


sub add_child_node {
  my ($self, $node) = @_;

  return unless(defined($node));
  
  throw("arg must be a [Bio::EnsEMBL::Compara::TreeNode] not a [$node]")
        unless($node->isa('Bio::EnsEMBL::Compara::TreeNode'));

  $node->parent_node($self);
  push @{$self->{'_children_nodes'}}, $node;
}


sub left_id {
  my $self = shift;
  $self->{'_left_id'} = shift if(@_);
  return $self->{'_left_id'};
}

sub right_id {
  my $self = shift;
  $self->{'_right_id'} = shift if(@_);
  return $self->{'_right_id'};
}

sub name {
  my $self = shift;
  $self->{'_name'} = shift if(@_);
  $self->{'_name'} = '' unless(defined($self->{'_name'}));
  return $self->{'_name'};
}

sub external_data_id {
  my $self = shift;
  $self->{'_external_data_id'} = shift if(@_);
  return $self->{'_external_data_id'};
}

sub external_data {
  my $self = shift;
  $self->{'_external_data'} = shift if(@_);
  return $self->{'_external_data'};

}


sub print_tree {
  my $self  = shift;
  my $indent = shift;
  
  $indent = '' unless(defined($indent));
  printf("%s(%d)%s\n", $indent, $self->dbID, $self->name);
  
  $indent .= "  ";
  my $children = $self->children_nodes;
  foreach my $child_node (@$children) {  
    $child_node->print_tree($indent);
  }
}

##################################
#
# search methods
#
##################################

sub find_node_by_name {
  my $self = shift;
  my $name = shift;
  
  return $self if($name eq $self->name);
  
  my $children = $self->children_nodes;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_name($name);
    return $found if(defined($found));
  }
  
  return undef;
}

sub find_node_by_dbID {
  my $self = shift;
  my $dbID = shift;
  
  return $self if($dbID eq $self->dbID);
  
  my $children = $self->children_nodes;
  foreach my $child_node (@$children) {
    my $found = $child_node->find_node_by_dbID($dbID);
    return $found if(defined($found));
  }
  
  return undef;
}

1;

