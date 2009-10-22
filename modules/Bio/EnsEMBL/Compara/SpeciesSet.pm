package Bio::EnsEMBL::Compara::SpeciesSet;

use strict;

use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

# FIXME: add throw not implemented for those not tag related?
# use Bio::EnsEMBL::Compara::Graph::CGObject qw(add_tag store_tag has_tag get_tagvalue get_all_tags get_tagvalue_hash _load_tags name);
use Bio::EnsEMBL::Compara::Graph::CGObject;

our @ISA = qw(Bio::EnsEMBL::Compara::Graph::CGObject);


sub new {
  my($class, @args) = @_;

  my $self = {};
  bless $self,$class;

  my ($dbID, $adaptor, $genome_dbs) =
      rearrange([qw(DBID ADAPTOR GENOME_DBS)], @args);

  $self->dbID($dbID) if (defined ($dbID));
  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->genome_dbs($genome_dbs) if (defined ($genome_dbs));

  return $self;
}

=head2 dbID

  Arg [1]    : (opt.) integer dbID
  Example    : my $dbID = $species_set->dbID();
  Example    : $species_set->dbID(12);
  Description: Getter/Setter for the dbID of this object in the database
  Returntype : integer dbID
  Exceptions : none
  Caller     : general

=cut


sub dbID {
  my $obj = shift;

  if (@_) {
    $obj->{'dbID'} = shift;
  }

  return $obj->{'dbID'};
}

=head2 species_set_id

  Arg [1]    : (opt.) integer species_set_id
  Example    : my $species_set_id = $species_set->species_set_id();
  Example    : $species_set->species_set_id(12);
  Description: Getter/Setter for the species_set_id of this object in the database
  Returntype : integer species_set_id
  Exceptions : none
  Caller     : general

=cut


sub species_set_id {
  my $obj = shift;

  if (@_) {
    $obj->{'dbID'} = shift;
  }

  return $obj->{'dbID'};
}



=head2 adaptor

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor
  Example    : my $species_set_adaptor = $species_set->adaptor();
  Example    : $species_set->adaptor($species_set_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor
  Exceptions : none
  Caller     : general

=cut


sub adaptor {
  my $obj = shift;

  if (@_) {
    $obj->{'adaptor'} = shift;
  }

  return $obj->{'adaptor'};
}


sub genome_dbs {
  my ($self, $arg) = @_;

  if ($arg && @$arg) {
    ## Check content
    my $genome_dbs;
    foreach my $gdb (@$arg) {
      throw("undefined value used as a Bio::EnsEMBL::Compara::GenomeDB\n")
        if (!defined($gdb));
      throw("$gdb must be a Bio::EnsEMBL::Compara::GenomeDB\n")
        unless $gdb->isa("Bio::EnsEMBL::Compara::GenomeDB");

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

1;
