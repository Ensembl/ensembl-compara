package Bio::EnsEMBL::Compara::SpeciesSet;

use strict;

use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

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
  my ($self, $arg) = @_;

  if (defined $arg) {
    ## Check content
    my $genome_dbs = {};
    foreach my $gdb (@$arg) {
      throw("undefined value used as a Bio::EnsEMBL::Compara::GenomeDB\n")
        if (!defined($gdb));
      throw("$gdb must be a Bio::EnsEMBL::Compara::GenomeDB\n")
        unless UNIVERSAL::isa($gdb, "Bio::EnsEMBL::Compara::GenomeDB");

      unless (defined $genome_dbs->{$gdb->dbID}) {
        $genome_dbs->{$gdb->dbID} = $gdb;
      } else {
        warn("GenomeDB (".$gdb->name."; dbID=".$gdb->dbID .
             ") appears twice in this Bio::EnsEMBL::Compara::SpeciesSet\n");
      }
    }
    $self->{'genome_dbs'} = [ values %{$genome_dbs} ] ;
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

    my $name = $self->get_tagvalue('name');
    return ref($self).": dbID=".($self->dbID || '?').", name='".($name || '?')."', genome_dbs=[".join(', ', map { $_->name.'('.($_->dbID || '?').')'} @{ $self->genome_dbs })."]";
}



1;

