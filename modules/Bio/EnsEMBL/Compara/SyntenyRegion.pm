

#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyRegion
#
# Cared for by Ewan Birney <ensembl-dev@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SyntenyRegion - Synteny region on one species

=head1 SYNOPSIS



=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyRegion;

use strict;
use Bio::EnsEMBL::Utils::Exception;

sub new {
    my( $class, $hash ) = @_;
    
    my $self = $hash||{};
    bless $self,$class;
    
    return $self;
}

=head2 start

 Title   : start
 Usage   : $obj->start($newval)
 Function: 
 Returns : value of start
 Args    : newvalue (optional)


=cut

sub start{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'start'} = $value;
    }
    return $obj->{'start'};

}

sub id { my $self = shift; return "$self->{'hit_chr_name'}:$self->{'hit_chr_start'}-$self->{'hit_chr_end'}"; }

=head2 end

 Title   : end
 Usage   : $obj->end($newval)
 Function: 
 Returns : value of end
 Args    : newvalue (optional)


=cut

sub end{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'end'} = $value;
    }
    return $obj->{'end'};

}

=head2 cluster_id

 Title   : cluster_id
 Usage   : $obj->cluster_id($newval)
 Function: 
 Returns : value of cluster_id
 Args    : newvalue (optional)


=cut

sub cluster_id{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'cluster_id'} = $value;
    }
    return $obj->{'cluster_id'};

}

=head2 dnafrag_id

 Title   : dnafrag_id
 Usage   : $obj->dnafrag_id($newval)
 Function: 
 Returns : value of dnafrag_id
 Args    : newvalue (optional)


=cut

sub dnafrag_id{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'dnafrag_id'} = $value;
    }
    return $obj->{'dnafrag_id'};

}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function: 
 Returns : value of dbID
 Args    : newvalue (optional)


=cut

sub dbID{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'dbID'} = $value;
    }
    return $obj->{'dbID'};

}


=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}
