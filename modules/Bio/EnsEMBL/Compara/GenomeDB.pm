=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::GenomeDB

=head1 DESCRIPTION

The GenomeDB object stores information about each species including the taxon id, species name, assembly, genebuild and the location of the core database.

=head1 SYNOPSIS

The end-user is probably only interested in the following methods:
 - dBID() # this value is also called genome_db_id
 - name() and get_short_name()
 - assembly()
 - taxon_id() and taxon()
 - genebuild()
 - has_karyotype()
 - is_high_coverage()
 - genome_component()
 - db_adaptor() (returns a Bio::EnsEMBL::DBSQL::DBAdaptor for this species)
 - toString()

More advanced use-cases include:
 - the methods exposed by StorableWithReleaseHistory
 - locator() (when the species is on a different server
 - sync_with_registry() (if you gradually build your Registry and the GenomeDB objects. Very unlikely !!)

The constructor is able to confront the asked parameters (taxon_id, assembly, etc) to the ones that are actually stored in the core database if the db_adaptor parameter is given.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=head1 METHODS

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Utils::Exception qw(deprecate warning throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use base ('Bio::EnsEMBL::Compara::StorableWithReleaseHistory');        # inherit dbID(), adaptor() and new() methods, and first_release() and last_release()


=head2 new

  Example :
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(
        -db_adaptor => $dba,
        -name       => 'Homo sapiens',
        -assembly   => 'GRCh38',
        -taxon_id   => 9606,
        -dbID       => 180,
        -genebuild  => '2006-12-Ensembl',
    );
  Description: Creates a new GenomeDB object
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);       # deal with Storable stuff

    my($db_adaptor, $name, $assembly, $taxon_id,  $genebuild, $has_karyotype, $genome_component, $is_high_coverage) =
        rearrange([qw(DB_ADAPTOR NAME ASSEMBLY TAXON_ID GENEBUILD HAS_KARYOTYPE GENOME_COMPONENT IS_HIGH_COVERAGE)], @_);

    # If there is a Core DBAdaptor, we can get most of the info from there,
    # but we'll have to check it is consistent with the required attributes
    my $core_genome_db = undef;
    if ($db_adaptor) {
        my $meta_container      = $db_adaptor->get_MetaContainer;
        my $genome_container    = $db_adaptor->get_GenomeContainer;

        $self->db_adaptor($db_adaptor);
        $self->name( $meta_container->get_production_name() );
        $self->assembly( $db_adaptor->assembly_name() );
        $self->taxon_id( $meta_container->get_taxonomy_id() );
        $self->genebuild( $meta_container->get_genebuild() );
        $self->has_karyotype( $genome_container->has_karyotype() );
        $self->is_high_coverage( $genome_container->is_high_coverage() );

        if ($genome_component and not scalar(grep {$_ eq $genome_component} @{$genome_container->get_genome_components})) {
            die "The required genome component '$genome_component' cannot be found in the database, please investigate\n";
        }
        $core_genome_db = bless \%{$self}, 'Bio::EnsEMBL::Compara::GenomeDB';
    }

    $name         && $self->name($name);
    $assembly     && $self->assembly($assembly);
    $taxon_id     && $self->taxon_id($taxon_id);
    $genebuild    && $self->genebuild($genebuild);
    defined $has_karyotype      && $self->has_karyotype($has_karyotype);
    defined $genome_component   && $self->genome_component($genome_component);
    defined $is_high_coverage   && $self->is_high_coverage($is_high_coverage);

    $self->_assert_equals($core_genome_db) if $core_genome_db;

    return $self;
}


=head2 db_adaptor

  Arg [1]    : (optional) Bio::EnsEMBL::DBSQL::DBAdaptor $dba
               The DBAdaptor containing sequence information for the genome
               represented by this object.
  Arg [2]    : (optional) Boolean $update_other_fields
               In setter mode, asks the object to update all the relevant
               fields from the new db_adaptor (genebuild, assembly, etc)
  Example    : $gdb->db_adaptor($dba);
  Description: Getter/Setter for the DBAdaptor containing sequence 
               information for the genome represented by this object.
  Returntype : Bio::EnsEMBL::DBSQL::DBAdaptor
  Caller     : general
  Status     : Stable

=cut

sub db_adaptor {
    my ( $self, $dba, $update_other_fields ) = @_;

    if($dba) {
        $self->{'_db_adaptor'} = ($dba && $dba->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'))
            ? $dba
            : undef;
        if ($self->{'_db_adaptor'} && $update_other_fields) {
            $self->name( $self->{'_db_adaptor'}->get_MetaContainer->get_production_name );
            $self->assembly( $self->{'_db_adaptor'}->assembly_name );
            $self->taxon_id( $self->{'_db_adaptor'}->get_MetaContainer->get_taxonomy_id );
            $self->genebuild( $self->{'_db_adaptor'}->get_MetaContainer->get_genebuild );
            $self->has_karyotype( $self->{'_db_adaptor'}->get_GenomeContainer->has_karyotype );
	    $self->{'_db_adaptor'}{_dbc}->disconnect_if_idle;
        }
    }

    unless (exists $self->{'_db_adaptor'}) {
        if ($self->locator and $self->locator ne '') {
            eval {$self->{'_db_adaptor'} = Bio::EnsEMBL::DBLoader->new($self->locator); };
            warn sprintf("The locator '%s' of %s could not be loaded because: %s\n", $self->locator, $self->name, $@) if $@;
        } else {
            $self->adaptor->_find_missing_DBAdaptors;
        }
    }

    return $self->{'_db_adaptor'};
}


=head2 _check_equals

  Example     : $genome_db->_check_equals($ref_genome_db);
  Description : Check that all the fields are the same as in the other object
                This is used to compare the fields automatically populated from
                the core database with the GenomeDB object preent in the Compara
                master database
  Returntype  : String: all the differences found between the two genome_dbs
  Exceptions  : none

=cut

sub _check_equals {
    my ($self, $ref_genome_db) = @_;

    my $diffs = '';
    foreach my $field (qw(assembly taxon_id genebuild name has_karyotype is_high_coverage)) {
        if (($self->$field() xor $ref_genome_db->$field()) or ($self->$field() and $ref_genome_db->$field() and ($self->$field() ne $ref_genome_db->$field()))) {
            $diffs .= sprintf("%s differs between this GenomeDB (%s) and the reference one (%s)\n", $field, $self->$field(), $ref_genome_db->$field());
        }
    }
    return $diffs;
}


=head2 _assert_equals

  Example     : $genome_db->_assert_equals($ref_genome_db);
  Description : Wrapper around _check_equals() that will throw if the GenomeDBs are different
  Returntype  : none
  Exceptions  : Throws if there are discrepancies

=cut

sub _assert_equals {
    my $self = shift;
    my $diffs = $self->_check_equals(@_);
    throw($diffs) if $diffs;
}


=head2 name

  Arg [1]    : (optional) string $value
  Example    : $gdb->name('Homo sapiens');
  Description: Getter setter for the name of this genome database, usually
               just the species name.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub name{
  my ($self,$value) = @_;

  if( defined $value) {
    $self->{'name'} = $value;
  }
  return $self->{'name'};
}


=head2 get_short_name

  Example    : $gdb->get_short_name;
  Description: The name of this genome in the Gspe ('G'enera
               'spe'cies) format. Can also handle 'G'enera 's'pecies
               's'ub 's'pecies (Gsss)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub get_short_name {
  my $self = shift;
  my $name = $self->name;
  $name =~ s/\b(\w)/\U$1/g;
  $name =~ s/\_/\ /g;
  unless( $name =~  s/(\S)\S*\s(\S)\S*\s(\S)\S*\s(\S).*/$1$2$3$4/ ){
    unless( $name =~  s/(\S)\S*\s(\S)\S*\s(\S{2,2}).*/$1$2$3/ ){
      unless( $name =~  s/(\S)\S*\s(\S{3,3}).*/$1$2/ ){
        $name = substr( $name, 0, 4 );
      }
    }
  }
  return $name;
}

=head2 short_name

  Description: DEPRECATED. GenomeDB::short_name() is deprecated in favour of get_short_name(), and will be removed in e84

=cut

sub short_name {
  my $self = shift;
  deprecate('GenomeDB::short_name() is deprecated in favour of get_short_name(), and will be removed in e84');
  return $self->get_short_name;
}


=head2 assembly

  Arg [1]    : (optional) string
  Example    : $gdb->assembly('NCBI36');
  Description: Getter/Setter for the assembly type of this genome db.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub assembly {
  my $self = shift;
  $self->{'assembly'} = shift if (@_);
  return $self->{'assembly'};
}

=head2 assembly_default

  Description: DEPRECATED. GenomeDB::assembly_default() is deprecated in favour of is_current(), and will be removed in e84. NOTE: it is not a setter any more

=cut

sub assembly_default {
  my $self = shift;
  my $boolean = shift;

  deprecate('GenomeDB::assembly_default() is deprecated in favour of is_current(), and will be removed in e84. NOTE: it is not a setter any more');
  return $self->is_current;
}

=head2 genebuild

  Arg [1]    : (optional) string
  Example    : $gdb->genebuild('2006-12-Ensembl');
  Description: Getter/Setter for the genebuild type of this genome db.
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub genebuild {
  my $self = shift;
  $self->{'genebuild'} = shift if (@_);
  return $self->{'genebuild'} || '';
}


=head2 taxon_id

  Arg [1]    : (optional) int
  Example    : $gdb->taxon_id(9606);
  Description: Getter/Setter for the taxon id of the contained genome db
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub taxon_id {
  my $self = shift;
  $self->{'taxon_id'} = shift if (@_);
  return $self->{'taxon_id'};
}

=head2 taxon

  Description: uses taxon_id to fetch the NCBITaxon object
  Returntype : Bio::EnsEMBL::Compara::NCBITaxon object 
  Exceptions : if taxon_id or adaptor not defined
  Caller     : general
  Status     : Stable

=cut

sub taxon {
  my $self = shift;

  return $self->{'_taxon'} if(defined $self->{'_taxon'});

  unless (defined $self->taxon_id and $self->adaptor) {
    throw("can't fetch Taxon without a taxon_id and an adaptor");
  }
  my $ncbi_taxon_adaptor = $self->adaptor->db->get_NCBITaxonAdaptor;
  $self->{'_taxon'} = $ncbi_taxon_adaptor->fetch_node_by_taxon_id($self->{'taxon_id'});
  return $self->{'_taxon'};
}


=head2 _species_tree_node_id

  Arg [1]    : (optional) int
  Example    : $gdb->_species_tree_node_id(9606);
  Description: Getter/Setter for the ID in the "reference" species-tree of this genome_db
  Returntype : int
  Exceptions : none
  Caller     : internal
  Status     : At risk

=cut

sub _species_tree_node_id {
  my $self = shift;
  $self->{'species_tree_node_id'} = shift if (@_);
  return $self->{'species_tree_node_id'};
}


=head2 locator

  Arg [1]    : string
  Description: Returns a string which describes where the external genome (ensembl core)
               database base is located. Locator format is:
               "Bio::EnsEMBL::DBSQL::DBAdaptor/host=ecs4port=3351;user=ensro;dbname=mus_musculus_core_20_32"
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub locator {
  my $self = shift;
  $self->{'locator'} = shift if (@_);
  return $self->{'locator'} || '';
}


=head2 has_karyotype

  Arg [1]    : (optional) boolean
  Example    : if ($gdb->has_karyotype()) { ... }
  Description: Whether the genomeDB has a karyotype
  Returntype : boolean
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub has_karyotype {
  my $self = shift;
  $self->{'has_karyotype'} = shift if (@_);
  return $self->{'has_karyotype'};
}


=head2 is_high_coverage

  Arg [1]    : (optional) boolean
  Example    : if ($gdb->is_high_coverage()) { ... }
  Description: Whether the genomeDB has a high-coverage genome
  Returntype : boolean
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub is_high_coverage {
  my $self = shift;
  $self->{'is_high_coverage'} = shift if (@_);
  return $self->{'is_high_coverage'};
}


#################################
# Methods for polyploid genomes #
#################################

=head2 genome_component

  Example     : my $genome_component = $genome_db->genome_component();
  Example     : $genome_db->genome_component($genome_component);
  Description : For polyploid genomes, the name of the sub-component.
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub genome_component {
    my $self = shift;
    $self->{'_genome_component'} = shift if @_;
    return $self->{'_genome_component'};
}


=head2 is_polyploid

  Example     : $genome_db->is_polyploid();
  Description : Returns 1 if this GenomeDB has some component GenomeDBs
  Returntype  : Boolean
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub is_polyploid {
    my $self = shift;
    return $self->{'_is_polyploid'} || 0;
}


=head2 make_component_copy

  Arg [1]     : string: the name of the new genome component
  Example     : my $new_component = $wheat_genome_db->make_component_copy('A');
  Description : Create a new GenomeDB that is a copy of this one, with the given
                component name
  Returntype  : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub make_component_copy {
    my ($self, $component_name) = @_;
    my $copy_genome_db = { %{$self} };
    bless $copy_genome_db, 'Bio::EnsEMBL::Compara::GenomeDB';
    $copy_genome_db->genome_component($component_name);
    $copy_genome_db->dbID(undef);
    $copy_genome_db->adaptor(undef);
    $self->component_genome_dbs($component_name, $copy_genome_db);
    return $copy_genome_db;
}


=head2 principal_genome_db

  Example     : $component_genome_db->principal_genome_db();
  Description : In case of polyploid genomes, return the main GenomeDB of the species.
                Returns undef otherwise
  Returntype  : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : throws if the adaptor isn't defined
  Caller      : general
  Status      : Stable

=cut

sub principal_genome_db {
    my $self = shift;

    return $self->{_principal_genome_db};
}


=head2 component_genome_dbs

  Arg [1]     : string (optional): the name of the genome component
  Arg [2]     : GenomeDB (optional): the new value for this component
  Example     : $genome_db->component_genome_dbs();
  Description : On a polyploid genome, returns all the GenomeDBs of its components.
                Returns an empty list otherwise
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub component_genome_dbs {
    my ($self, $component_name, $new_gdb) = @_;

    if ($component_name) {
        if ($new_gdb) {
            $self->{_component_genome_dbs}->{$component_name} = $new_gdb;
            $self->{_is_polyploid} = 1;
            $new_gdb->{_principal_genome_db} = $self;
        }
        return $self->{_component_genome_dbs}->{$component_name};
    } else {
        return [values %{$self->{_component_genome_dbs}}];
    }
}


=head2 toString

  Example    : print $dbID->toString()."\n";
  Description: returns a stringified representation of the object (basically, the concatenation of all the fields)
                Bio::EnsEMBL::Compara::GenomeDB: dbID=129, name='latimeria_chalumnae', assembly='LatCha1', genebuild='2011-09-Ensembl', default='1', taxon_id='7897', karyotype='0', high_coverage='1', locator=''
  Returntype : string
  Exceptions : none
  Status     : At risk (the format of the string would change if we add more fields to GenomeDB)

=cut

sub toString {
    my $self = shift;

    return ref($self).": dbID=".($self->dbID || '?')
        .", name='".$self->name
        ."', assembly='".$self->assembly
        ."', genebuild='".$self->genebuild
        ."', taxon_id='".$self->taxon_id
        ."', karyotype='".$self->has_karyotype
        ."', high_coverage='".$self->is_high_coverage
        .($self->genome_component ? "', genome_component='".$self->genome_component : '')
        ."', locator='".$self->locator
        ."', first_release='".($self->first_release || 'NULL')
        ."', last_release='".($self->last_release || 'NULL')
        ."'";
}


=head2 sync_with_registry

  Description: Synchronize all the cached genome_db objects
               db_adaptor (connections to core databases)
               with those set in Bio::EnsEMBL::Registry.
               Order of presidence is Registry.conf > ComparaConf > genome_db.locator
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  Status     : At risk

=cut

sub sync_with_registry {
  my $self = shift;

  return unless(eval "require Bio::EnsEMBL::Registry");

  #print("Registry eval TRUE\n");

    return if $self->locator and not $self->locator =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/;

    my $coreDBA;
    my $registry_name;
    if ($self->assembly) {
      $registry_name = $self->name ." ". $self->assembly;
      if(Bio::EnsEMBL::Registry->alias_exists($registry_name)) {
        $coreDBA = Bio::EnsEMBL::Registry->get_DBAdaptor($registry_name, 'core');
      }
    }
    if( not defined($coreDBA) and Bio::EnsEMBL::Registry->alias_exists($self->name)) {
      $coreDBA = Bio::EnsEMBL::Registry->get_DBAdaptor($self->name, 'core');
      Bio::EnsEMBL::Registry->add_alias($self->name, $registry_name) if ($registry_name);
    }

    if($coreDBA) {
      #defined in registry so override any previous connection
      #and set in GenomeDB object (ie either locator or compara.conf)
      $self->db_adaptor($coreDBA);
    } elsif ($self->locator) {
      #fetch from genome_db which may be from a compara.conf or from a locator
      $coreDBA = $self->db_adaptor();
      if(defined($coreDBA)) {
        if (Bio::EnsEMBL::Registry->alias_exists($self->name)) {
          Bio::EnsEMBL::Registry->add_alias($self->name, $registry_name) if ($registry_name);
        } else {
          Bio::EnsEMBL::Registry->add_DBAdaptor($registry_name, 'core', $coreDBA);
          Bio::EnsEMBL::Registry->add_alias($registry_name, $self->name) if ($registry_name);
        }
      }
    }
}


=head2 _get_unique_key

  Example     : $genome_db->_get_unique_key();
  Description : Returns a composite key that maps the UNIQUE KEY constraint of the genome_db table
  Returntype  : String
  Exceptions  : none

=cut

sub _get_unique_key {
    my $self = shift;
    return join('_____', lc $self->name, lc $self->assembly);
}

1;
