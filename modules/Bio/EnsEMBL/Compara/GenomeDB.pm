=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::GenomeDB

=head1 DESCRIPTION

The GenomeDB object stores information about each species including the taxon id, species name, assembly, genebuild and the location of the core database.

The end-user is probably only interested in the following methods:
 - dBID() # this value is also called genome_db_id
 - name() and get_short_name()
 - assembly()
 - taxon_id() and taxon()
 - genebuild()
 - has_karyotype()
 - is_good_for_alignment()
 - genome_component()
 - db_adaptor() (returns a Bio::EnsEMBL::DBSQL::DBAdaptor for this species)
 - toString()

More advanced use-cases include:
 - the methods exposed by StorableWithReleaseHistory
 - locator() (when the species is on a different server
 - sync_with_registry() (if you gradually build your Registry and the GenomeDB objects. Very unlikely !!)

The constructor is able to confront the asked parameters (taxon_id, assembly, etc) to the ones that are actually stored in the core database if the db_adaptor parameter is given.

=cut

package Bio::EnsEMBL::Compara::GenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Utils::Exception qw(warning throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

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

    my($db_adaptor, $name, $assembly, $taxon_id,  $genebuild, $has_karyotype, $genome_component, $strain_name, $display_name, $is_good_for_alignment) =
        rearrange([qw(DB_ADAPTOR NAME ASSEMBLY TAXON_ID GENEBUILD HAS_KARYOTYPE GENOME_COMPONENT STRAIN_NAME DISPLAY_NAME IS_GOOD_FOR_ALIGNMENT)], @_);

    $name         && $self->name($name);
    $assembly     && $self->assembly($assembly);
    $taxon_id     && $self->taxon_id($taxon_id);
    $genebuild    && $self->genebuild($genebuild);
    $db_adaptor   && $self->db_adaptor($db_adaptor);
    defined $has_karyotype      && $self->has_karyotype($has_karyotype);
    defined $genome_component   && $self->genome_component($genome_component);
    defined $is_good_for_alignment && $self->is_good_for_alignment($is_good_for_alignment);
    defined $strain_name        && $self->strain_name($strain_name);
    defined $display_name        && $self->display_name($display_name);

    return $self;
}


=head2 new_from_DBAdaptor

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor $db_adaptor
  Arg [2]    : (optional) string $genome_component
  Example    : my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor( $dba );
  Description: Creates a new GenomeDB object from a Core DBAdaptor.
               All the fields are populated from the Core database, with the exception of
               the genome_component which has to provided here (only for polyploid genomes)
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new_from_DBAdaptor {
    my ($caller, $db_adaptor, $genome_component) = @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new();        # deal with Storable stuff

    $self->db_adaptor($db_adaptor, 1);

    if ($genome_component) {
        if (grep {$_ eq $genome_component} @{$db_adaptor->get_GenomeContainer->get_genome_components}) {
            $self->genome_component($genome_component);
            $self->display_name($self->display_name . sprintf(' (component %s)', $genome_component));
        } else {
            die "The required genome component '$genome_component' cannot be found in the database, please investigate\n";
        }
    }

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
        assert_ref($dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor', 'db_adaptor');
        throw('$db_adaptor must refer to a Core database') unless $dba->group eq 'core';
        $self->{'_db_adaptor'} = $dba;
        Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor->pool_one_DBConnection($dba);
        if ($update_other_fields) {
            my $was_connected       = $dba->{_dbc}->connected;
            my $meta_container      = $dba->get_MetaContainer;
            my $genome_container    = $dba->get_GenomeContainer;
            my $strain_type         = $meta_container->single_value_by_key('strain.type');
            my $strain_name         = $meta_container->single_value_by_key('species.strain');

            if ($strain_name) {
                $strain_type //= 'strain';
                if ($strain_name =~ /\breference\b/i) {
                    $strain_name = "$strain_name $strain_type";
                } else {
                    $strain_name = "$strain_type $strain_name";
                }
            }

            $self->name( $meta_container->get_production_name );
            $self->assembly( $dba->assembly_name );
            $self->taxon_id( $meta_container->get_taxonomy_id );
            $self->genebuild( $meta_container->get_genebuild );
            $self->has_karyotype( $genome_container->has_karyotype );
            $self->is_good_for_alignment( 0 );  # Cannot be inferred without the dnafrags
            $self->strain_name( $strain_name ) if $strain_name;
            $self->display_name( $meta_container->get_display_name );
            $dba->{_dbc}->disconnect_if_idle unless $was_connected;
        }
    }

    unless (exists $self->{'_db_adaptor'}) {
        if ($self->locator) {
            eval {$self->{'_db_adaptor'} = Bio::EnsEMBL::DBLoader->new($self->locator); };
            warn sprintf("The locator '%s' of %s could not be loaded because: %s\n", $self->locator, $self->name, $@) if $@;
            Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor->pool_one_DBConnection($self->{'_db_adaptor'});
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
    foreach my $field (qw(assembly taxon_id genebuild name strain_name display_name has_karyotype)) {
        if (($self->$field() xor $ref_genome_db->$field()) or ($self->$field() and $ref_genome_db->$field() and ($self->$field() ne $ref_genome_db->$field()))) {
            $diffs .= sprintf("%s differs between this GenomeDB (%s) and the reference one (%s)\n", $field, $self->$field() // '<NULL>', $ref_genome_db->$field() // '<NULL>');
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

=head2 get_distinct_name

  Example     : print $genome_db->get_distinct_name();
  Description : Returns the name of the GenomeDB, with additional information
                (e.g. genome component) appended if relevant to allow it to be
                distinguished from other GenomeDBs with the same name.
  Returntype  : String
  Exceptions  : none

=cut

sub get_distinct_name {
    my $self = shift;
    return $self->genome_component ? $self->name . '_' . $self->genome_component : $self->name;
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
  $name .= ".".(uc $self->genome_component) if $self->genome_component;
  return $name;
}


=head2 _get_unique_name

  Example     : print $genome_db->_get_unique_name();
  Description : Returns the name of the GenomeDB augmented with any information
                (such as the genome-component) to make it unique
  Returntype  : String
  Exceptions  : none

=cut

sub _get_unique_name {
    my $self = shift;
    my $n = $self->name;
    $n .= '.'.$self->genome_component if $self->genome_component;
    return $n;
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
  $self->{'_taxon_id'} = shift if (@_);
  return $self->{'_taxon_id'};
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
  $self->{'_taxon'} = $ncbi_taxon_adaptor->fetch_node_by_taxon_id($self->{'_taxon_id'});
  return $self->{'_taxon'};
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
  return $self->{'locator'};
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


=head2 is_good_for_alignment

  Arg [1]    : (optional) boolean
  Example    : if ($gdb->is_good_for_alignment()) { ... }
  Description: Whether the genomeDB is suitable for being used in alignments analysis.
  Returntype : boolean
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub is_good_for_alignment {
  my $self = shift;
  $self->{'is_good_for_alignment'} = shift if (@_);
  return $self->{'is_good_for_alignment'};
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
    $copy_genome_db->display_name($self->display_name . sprintf(' (component %s)', $component_name));
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


#######################
# Methods for strains #
#######################

=head2 strain_name

  Example     : my $strain_name = $genome_db->strain_name();
  Example     : $genome_db->strain_name($strain_name);
  Description : The "strain" name of this genome. Includes the correct term for
                the "type" of strain, e.g. "strain C3H/HeJ" or "breed berkshire"
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub strain_name {
    my $self = shift;
    $self->{'_strain_name'} = shift if @_;
    return $self->{'_strain_name'};
}


#######################
# Methods for display #
#######################

=head2 display_name

  Example     : my $display_name = $genome_db->display_name();
  Example     : $genome_db->display_name($display_name);
  Description : The display name of this genome
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub display_name {
    my $self = shift;
    $self->{'_display_name'} = shift if @_;
    return $self->{'_display_name'};
}


=head2 get_common_name

  Example     : my $common_name = $genome_db->get_common_name();
  Description : Returns the common (English) name of this GenomeDB. This is a wrapper around
                display_name() that discards scientific (latin) names.
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Experimental

=cut

sub get_common_name {
    my $self = shift;
    warning('GenomeDB::get_common_name is experimental and may be removed soon. Do not use');
    my $display_name = $self->display_name;
    if ($self->taxon_id && ($self->{'_taxon'} || $self->adaptor)) {
        my $scientific_name = $self->taxon->scientific_name;
        # Be careful not to exclude Rat (Rattus norvegicus) or Gorilla (Gorilla gorilla gorilla)
        if ($scientific_name && $display_name && ($scientific_name =~ /^$display_name\b/) && ($display_name =~ / /)) {
            return;
        }
    }
    return $display_name;
}


=head2 get_scientific_name

  Example     : my $get_scientific_name = $genome_db->get_scientific_name();
  Description : Returns the scientific name of this GenomeDB (incl. the strain and component names)
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_scientific_name {
    my ($self, $make_unique) = @_;

    my $n = $self->taxon_id ? (($self->{'_taxon'} || $self->adaptor) ? $self->taxon->scientific_name : 'Taxon ' . $self->taxon_id) : $self->name;
    if (my $strain_name = $self->strain_name) {
        my ($foo, $unqualified_strain_name) = split(/ +/, $strain_name, 2);
        $n .= " $strain_name" if $n !~ /\b$unqualified_strain_name$/;
    }
    $n .= sprintf(' (component %s)', $self->genome_component) if $self->genome_component;

    if ($make_unique and not ($self->strain_name or $self->genome_component)) {
        # Try to make the name unique
        my $competitors = $self->adaptor ? ($self->taxon_id ? $self->adaptor->fetch_all_by_taxon_id($self->taxon_id) : $self->adaptor->fetch_all_by_name($self->name)) : [];
        if (scalar(grep {$_ ne $self} @$competitors)) {
            return $n . " " . $self->assembly;
        }
    }
    return $n;
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
    my $txt = sprintf('GenomeDB dbID=%s %s (%s)', ($self->dbID || '?'), $self->name, $self->assembly);
    $txt .= ' scientific_name='.$self->get_scientific_name if $self->taxon_id;
    $txt .= sprintf(' genebuild="%s"', $self->genebuild);
    $txt .= ', ' . ($self->is_good_for_alignment ? 'is' : 'not') . ' good for aln';
    $txt .= ', ' . ($self->has_karyotype ? 'with' : 'without') . ' karyotype';
    $txt .= ' ' . $self->SUPER::toString();
    return $txt;
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

  eval {
      require Bio::EnsEMBL::Registry;
  };
  return if $@;

  #print("Registry eval TRUE\n");

    return if $self->locator and not $self->locator =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/;

    my $coreDBA;
    my $registry_name;

    # Rule 1. The Registry doesn't natively support multiple assemblies of
    # the same species. We bypass this by trying aliases that contain the
    # assembly names.
    if ($self->assembly) {
      $registry_name = $self->name ." ". $self->assembly;
      if(Bio::EnsEMBL::Registry->alias_exists($registry_name)) {
        $coreDBA = Bio::EnsEMBL::Registry->get_DBAdaptor($registry_name, 'core');
      }
    }

    # Rule 2. For ancestral_sequences, the Registry's database scanner adds
    # the division name as a prefix (except for Vertebrates).
    if (($self->name eq 'ancestral_sequences') and ($self->adaptor)) {
      my $division_name = $self->adaptor->db->get_division;
      # Vertebrates' "ancestral_sequences" will be matched by the next rule
      if ($division_name and ($division_name ne 'vertebrates')) {
        $registry_name = $division_name . '_' . $self->name;
        if(Bio::EnsEMBL::Registry->alias_exists($registry_name)) {
          $coreDBA = Bio::EnsEMBL::Registry->get_DBAdaptor($registry_name, 'core');
        }
      }
    }

    # Rule 3. $self->name is expected to be a Registry key, i.e. a species
    # name or an alias. As far as I'm aware, only "ancestral_sequences" is
    # ever an alias (of "Ancestral sequences" in the Registry's database
    # scanner, and "MULTI" in the webcode), all others are actual names.
    if( not defined($coreDBA) and Bio::EnsEMBL::Registry->get_alias($self->name, 'no_warn')) {
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
      if(defined($coreDBA) && $registry_name) {
        if (Bio::EnsEMBL::Registry->alias_exists($self->name)) {
          Bio::EnsEMBL::Registry->add_alias($self->name, $registry_name);
        } else {
          Bio::EnsEMBL::Registry->add_DBAdaptor($registry_name, 'core', $coreDBA);
          Bio::EnsEMBL::Registry->add_alias($registry_name, $self->name);
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


=head2 _get_genome_dump_path

  Arg[1]      : String $dir. Base directory in which to find / place the Fasta files
  Arg[2]      : (optional) String $mask
  Arg[3]      : (optional) Boolean $non_ref
  Example     : $genome_db->_get_genome_dump_path($base_dir);
                $genome_db->_get_genome_dump_path($base_dir, 'hard');
                $genome_db->_get_genome_dump_path($base_dir, 'soft', 'non_ref');
  Description : Returns the expected path for the Fasta dump of this genome, given the
                requested dump options. This method allows pipelines to refer to and use
                files that are centrally created.
                To behave nicely at scale, the files are expected to be spread according
                to the dbID of the GenomeDB, using eHive's dir_revhash, e.g.
                "123456789" => "9/8/7/6/5/4/3/2", and to be named "$name.$assembly.*.fa".
                We currently use two optional markers (in this order):
                  - 'soft' / 'mask' / undef - to use the masked sequence
                  - 'non_ref' (or anything "true") / undef - to refer to the non-reference
                    sequences, also known as alt-regions (e.g. patches and haplotypes)
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub _get_genome_dump_path {
    my $self = shift;
    my $dir  = shift;
    my $mask = shift;
    my $non_reference = shift;

    require Bio::EnsEMBL::Hive::Utils;
    my $subdir = $self->dbID ? Bio::EnsEMBL::Hive::Utils::dir_revhash($self->dbID) : '';

    my @name_components = (
        $self->name,
        $self->assembly,
    );
    push @name_components, 'comp' . $self->genome_component if $self->genome_component;
    push @name_components, 'non_ref' if $non_reference;
    push @name_components, $mask if $mask;

    my $filename = join('.', @name_components) . '.fa';
    return "$dir/$subdir/$filename";
}


=head2 get_faidx_helper

  Arg[1]      : (optional) String $mask
  Arg[2]      : (optional) Boolean $non_reference
  Example     : $genome_db->get_faidx_helper('hard');
                $genome_db->get_faidx_helper('soft', 'non_ref');
  Description : Return the instance of Bio::DB::HTS::Faidx for this type of Fasta file, if
                a directory has been registered (see L<GenomeDBADaptor::dump_dir_location>).
                A description of the options ($mask, etc) can be found in L<_get_genome_dump_path>
  Returntype  : Bio::DB::HTS::Faidx instance
  Exceptions  : Will die if dump_dir_location is set but the file is not found
  Caller      : general

=cut

sub get_faidx_helper {
    my $self = shift;

    # Ancestral sequences are not dumped
    return undef if $self->name eq 'ancestral_sequences';

    if ($self->adaptor and (my $dump_dir_location = $self->adaptor->dump_dir_location)) {
        my $path = $self->_get_genome_dump_path($dump_dir_location, @_);
        $self->{'_faidx_helper'} //= {};
        unless (exists $self->{'_faidx_helper'}->{$path}) {
            if (-e $path) {
                require Bio::DB::HTS::Faidx;
                $self->{'_faidx_helper'}->{$path} = Bio::DB::HTS::Faidx->new($path);
            } else {
                die "Could not find $path";
            }
        }
        return $self->{'_faidx_helper'}->{$path};
    }
}


1;
