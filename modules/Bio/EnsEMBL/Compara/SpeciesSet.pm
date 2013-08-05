package Bio::EnsEMBL::Compara::SpeciesSet;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Compara::GenomeDB;

# FIXME: add throw not implemented for those not tag related?
use base (  'Bio::EnsEMBL::Storable',           # inherit dbID(), adaptor() and new() methods
            'Bio::EnsEMBL::Compara::Taggable'   # inherit everything related to tagability
         );


=head2 new

  Arg [..]   : Takes a set of named arguments
  Example    : my $my_species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                -dbID            => $species_set_id,
                                -genome_dbs      => [$gdb1, $gdb2, $gdb3 ],
                                -adaptor         => $species_set_adaptor );
  Description: Creates a new SpeciesSet object
  Returntype : Bio::EnsEMBL::Compara::SpeciesSet

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);  # deal with Storable stuff

    my ($genome_dbs) = rearrange([qw(GENOME_DBS)], @_);

    $self->genome_dbs($genome_dbs) if (defined ($genome_dbs));

    return $self;
}


=head2 genome_dbs

  Arg [1]    : (opt.) list of genome_db objects
  Example    : my $genome_dbs = $species_set->genome_dbs();
  Example    : $species_set->genome_dbs( [$gdb1, $gdb2, $gdb3] );
  Description: Getter/Setter for the genome_dbs of this object in the database
  Returntype : arrayref genome_dbs
  Exceptions : none
  Caller     : general

=cut

sub genome_dbs {
    my ($self, $args) = @_;

    if ($args) {
        my $hashed_genome_dbs = {};
        foreach my $gdb (@$args) {
            throw("undefined value used as a Bio::EnsEMBL::Compara::GenomeDB\n") if (!defined($gdb));

            if(ref($gdb) eq 'HASH') {
                $gdb = Bio::EnsEMBL::Compara::GenomeDB->new( %$gdb ) or die "Could not automagically create a GenomeDB\n";
            }

            my $hash_key = join('--', $gdb->name, $gdb->assembly, $gdb->genebuild );
        
            if($hashed_genome_dbs->{ $hash_key }) {
                warn("GenomeDB with hash key '$hash_key' appears twice in this Bio::EnsEMBL::Compara::SpeciesSet\n");
            } else {
                $hashed_genome_dbs->{ $hash_key } = $gdb;
            }
        }

        $self->{'genome_dbs'} = [ values %{$hashed_genome_dbs} ] ;
    }
    return $self->{'genome_dbs'};
}


=head2 toString

  Args       : (none)
  Example    : print $species_set->toString()."\n";
  Description: returns a stringified representation of the species_set
  Returntype : string

=cut

sub toString {
    my $self = shift;

    my $taxon_id    = $self->get_tagvalue('taxon_id');
    my $name        = $self->get_tagvalue('name');
    return ref($self).": dbID=".($self->dbID || '?').($taxon_id ? ", taxon_id=$taxon_id" : '').", name='".($name || '?')."', genome_dbs=[".join(', ', map { $_->name.'('.($_->dbID || '?').')'} @{ $self->genome_dbs })."]";
}



1;

