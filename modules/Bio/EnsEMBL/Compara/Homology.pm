package Bio::EnsEMBL::Compara::Homology;
use strict;
use Bio::Root::Object;
use DBI;



=head2 new

 Title   : new
 Usage   : 
 Function: 
 Example : 
 Returns : SeqTag object
 Args    :


=cut


sub new {
    my ($class) = @_;

    my $self = {};
    bless $self,$class;

    return $self;
   
}


=head2 species

 Title   : species
 Usage   : $obj->species($newval)
 Function: 
 Example : 
 Returns : value  of species
 Args    : newvalue (optional)


=cut

sub species {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_species'} = $value;
    }
    return $obj->{'_species'};

}


=head2 stable_id

 Title   : stable_id
 Usage   : $obj->stable_id($newval)
 Function: 
 Example : 
 Returns : value  of stable_id
 Args    : newvalue (optional)


=cut

sub stable_id {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_stable_id'} = $value;
    }
    return $obj->{'_stable_id'};

}



=head2 display_id

 Title   : display_id
 Usage   : $obj->display_id($newval)
 Function: 
 Example : 
 Returns : value  of display_id
 Args    : newvalue (optional)

=cut

sub display_id {
   my ($obj,$value) = @_;

   warn "
Deprecated method, you should get this info now going through the core DBAdaptor
of the corresponding species. This can be done easily specifying a conf file
when connecting to a compara (look in the perldoc) and then using the get_db_adaptor.
Then use the fetch_by_stable_id in the core GeneAdaptor module.
WARN: returning undef\n";

   return undef;

   if( defined $value) {
      $obj->{'_display_id'} = $value;
    }
    return $obj->{'_display_id'};

}



=head2 description

 Title   : description
 Usage   : $obj->description($newval)
 Function: 
 Example : 
 Returns : value  of description
 Args    : newvalue (optional)

=cut

sub description {
   my ($obj,$value) = @_;

   warn "
Deprecated method, you should get this info now going through the core DBAdaptor
of the corresponding species. This can be done easily specifying a conf file
when connecting to a compara (look in the perldoc) and then using the get_db_adaptor.
Then use the fetch_by_stable_id in the core GeneAdaptor module.
WARN: returning undef\n";

   return undef;

   if( defined $value) {
      $obj->{'_description'} = $value;
    }
    return $obj->{'_description'};

}



=head2 chrom_start

 Title   : chrom_start
 Usage   : $obj->chrom_start($newval)
 Function: 
 Example : 
 Returns : value  of chromosome start
 Args    : newvalue (optional)


=cut

sub chrom_start {
   my ($obj,$value) = @_;

   warn "
Deprecated method, you should get this info now going through the core DBAdaptor
of the corresponding species. This can be done easily specifying a conf file
when connecting to a compara (look in the perldoc) and then using the get_db_adaptor.
Then use the fetch_by_stable_id in the core GeneAdaptor module.
WARN: returning undef\n";

   return undef;

   if( defined $value) {
      $obj->{'_chrom_start'} = $value;
    }
    return $obj->{'_chrom_start'};

}


=head2 chrom_end

 Title   : chrom_end
 Usage   : $obj->chrom_end($newval)
 Function: 
 Example : 
 Returns : value  of chromosome end
 Args    : newvalue (optional)


=cut

sub chrom_end {
   my ($obj,$value) = @_;

   warn "
Deprecated method, you should get this info now going through the core DBAdaptor
of the corresponding species. This can be done easily specifying a conf file
when connecting to a compara (look in the perldoc) and then using the get_db_adaptor.
Then use the fetch_by_stable_id in the core GeneAdaptor module.
WARN: returning undef\n";

   return undef;

   if( defined $value) {
      $obj->{'_chrom_end'} = $value;
    }
    return $obj->{'_chrom_end'};

}



=head2 chromosome

 Title   : chromomosome
 Usage   : $obj->chromosome($newval)
 Function: 
 Example : 
 Returns : chromosome
 Args    : newvalue (optional)


=cut

sub chromosome {
   my ($obj,$value) = @_;

   warn "
Deprecated method, you should get this info now going through the core DBAdaptor
of the corresponding species. This can be done easily specifying a conf file
when connecting to a compara (look in the perldoc) and then using the get_db_adaptor.
Then use the fetch_by_stable_id in the core GeneAdaptor module.
WARN: returning undef\n";

   return undef;

   if( defined $value) {
      $obj->{'_chromosome'} = $value;
    }
    return $obj->{'_chromosome'};

}


1;

