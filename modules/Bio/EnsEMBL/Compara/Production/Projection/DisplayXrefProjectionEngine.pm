=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::DisplayXrefProjectionEngine

=head1 DESCRIPTION

This is an extension of the ProjectionEngine object which provides methods
for filtering according to rules originally used in the Ensembl projection
pipeline. This contains the rules for allowing a transfer to occur;
the original pipeline had rules for the formatting of the final
DBEntry so look in the corresponding writer for that information.

=head1 FILTERS

=head2 Source DBEntry Filtering

=over 8

=item Value is defined, a DBEntry & is one 

=item DB name is not a clone

=item If the source GenomeDB had a restriction from species_dbname_map 

=back

=cut

=head2 Target DBEntry Filtering

=over 8

=item If the external name was undefined

=item If it was defined but it was set to a RefSeq prediction type

=back

=head2 Homology Filtering

Homology objects are filtered accordingly

=over 8

=item The description field is set to ortholog_one2one, ortholog_one2many or ortholog_many2many

=item Percentage identity of both homologous pepetides is greater than 40%

=back

=cut

package Bio::EnsEMBL::Compara::Production::Projection::DisplayXrefProjectionEngine;

use strict;
use warnings;

use base qw( Bio::EnsEMBL::Compara::Production::Projection::ProjectionEngine );


use Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder;
use Bio::EnsEMBL::Compara::Production::Projection::DisplayProjection;
use Data::Predicate::ClosurePredicate;
use Data::Predicate::Predicates qw(:all);

use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

=head2 new()

  Arg[-species_dbname_map]    : A hash which maps GenomeDB names to DBNames in
                                a DBEntry if we wish to restrict the source
                                DataSet. Defaults to to H.sap to HGNC & M.mus
                                to MarkerSymbol
  Arg[-all_sources]           : Used to relax the checks for DBName on a DBEntry
                                allowing for any display ID to be projected.
                                Defaults to false
  Arg[-one_to_many]           : Lets the relationships which are not just 
                                1:1 through. Defaults to false
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  
  my ($species_dbname_map, $all_sources, $one_to_many) = rearrange([qw(species_dbname_map all_sources one_to_many)], @args);
  
  $species_dbname_map = $self->_species_dbname_map_builder() if ! defined $species_dbname_map;
  assert_ref( $species_dbname_map, 'HASH' );
  $self->{species_dbname_map} = $species_dbname_map;
  
  $all_sources = $self->_all_sources_builder() if ! defined $all_sources;
  $self->{all_sources} = $all_sources;
  
  $one_to_many = $self->_one_to_many_builder() if ! defined $one_to_many;
  $self->{one_to_many} = $one_to_many;
  
  return $self;
}

=head2 species_dbname_map()

Returns the map of Species Name (GenomeDB.Name) to the valud type of 
DBEntry. Value can be an array.

=cut

sub species_dbname_map {
  my ($self) = @_;
  return $self->{species_dbname_map};
}

=head2 all_sources()

Returns if we allow all sources to be mapped from

=cut

sub all_sources {
  my ($self) = @_;
  return $self->{all_sources};
}

=head2 one_to_many()

Returns if we allow one to many relationships through

=cut

sub one_to_many {
  my ($self) = @_;
  return $self->{one_to_many};
}

=head2 _homology_descriptor() 

Used to hold a hash of the following format

  {
    STABLE_ID => {
      current_index => 0,
      total => 3,
      last_projection => ProjectionObj
    },
    STABLE_ID => {
      current_index => 0,
      total => 2,
      last_projection => ProjectionObj
    },
  }

It is used for providing more useful information to display IDs when working
with 1:m relationships. Also allows us to resolve the trickier situation
of rejecting a projection because a more suitable one could appear

=cut

sub _homology_descriptor {
  my ($self, $_homology_descriptor) = @_;
  $self->{_homology_descriptor} = $_homology_descriptor if defined $_homology_descriptor;
  return $self->{_homology_descriptor};
}

=head2 project()

Override of the default project which does post filtering of the projections
in order to remove any unecessary duplications.

=cut

sub project {
  my ($self, $target_genome_db) = @_;
  my $projections = $self->SUPER::project($target_genome_db);
  $self->log()->info('Filtering projections flagged as ignore');
  my @new_projections = grep { ! $_->ignore() } @{$projections};
  $self->log()->info('Finished filtering');
  return \@new_projections; 
}


=head2 build_projection()

  Arg[1]      : Member; source member of projection
  Arg[2]      : Member; target member of projection
  Arg[3]      : DBEntry projected
  Arg[4]      : The homology used for projection
  Description : Provides an abstraction to building a projection from a 
                set of elements.
  Returntype  : Projection object

=cut

sub build_projection {
  my ($self, $query_member, $target_member, $dbentry, $homology) = @_;
  
  my $target_gene_member  = ($target_member->source_name eq 'ENSEMBLGENE') 
                          ? $target_member 
                          : $target_member->gene_member();
  my $stable_id = $target_gene_member->stable_id();
  my $descriptor = $self->_homology_descriptor()->{$stable_id};
  
  my $p = Bio::EnsEMBL::Compara::Production::Projection::DisplayProjection->new(
    -ENTRY => $dbentry,
    -FROM => ($query_member->source_name eq 'ENSEMBLGENE') ? $query_member : $query_member->gene_member(),
    -TO => $target_gene_member,
    -FROM_IDENTITY => $query_member->perc_id(),
    -TO_IDENTITY => $target_member->perc_id(),
    -TYPE => $homology->description(),
    -TOTAL => $descriptor->{total},
    -CURRENT_INDEX => $descriptor->{current_index}
  );
  $descriptor->{last_projection}->ignore(1) if defined $descriptor->{last_projection};
  $descriptor->{last_projection} = $p;
  
  return $p;
}

sub _homology_predicate_builder {
  my ($self) = @_;
  
  $self->log()->debug('Creating default Homology predicate');
  
  my @one_types = qw(ortholog_one2one);
  my @many_types = qw(ortholog_one2many);  
  my @types = @one_types;
  push(@types, @many_types) if $self->one_to_many();
  
  my $type_predicate = p_or(map { p_string_equals($_, 'description') } @types);
  
  #Con worker which increments our current homology counter. Always returns
  #true and will always be run if the type predicate worked
  my $worker_predicate = Data::Predicate::ClosurePredicate->new( closure => sub {
    my ($homology) = @_;
    my ($query_member, $target_member) = $self->_decode_homology($homology);
    my $sid = $target_member->stable_id();
    $self->_homology_descriptor()->{$sid}->{current_index}++;
    return 1;
  });
  
  return p_and($type_predicate, $worker_predicate);
}

sub _dbentry_predicate_builder {
  my ($self) = @_;
  
  $self->log()->debug('Creating default DBEntry predicate');
  
  #Make sure it's defined & is a DBEntry
  my $entry_okay = p_and(p_defined(), p_blessed(), p_isa('Bio::EnsEMBL::DBEntry'));
  
  #We don't allow anything with the dbname of clone
  my $clone_predicate = p_not(p_regex(qr/clone/i, 'dbname'));
  
  #Detect if we are in a species where we only want one type of DBEntry.
  #If not default it ot true (allow everything)
  my $dbname            = $self->species_dbname_map()->{$self->genome_db()->name};
  my @dbname_array      = (check_ref($dbname, 'ARRAY')) ? @{$dbname} : ($dbname);
  my $dbname_predicate  = ($self->all_sources()) 
                        ? p_always_true() 
                        : (defined $dbname ) 
                        ? p_or( map { p_string_equals($_, 'dbname') } @dbname_array )
                        : p_always_true();
                  
  return p_and($entry_okay, $clone_predicate, $dbname_predicate);
}

sub _transfer_dbentry_by_targets {
  my ($self, $source, $targets, $target_stable_id) = @_;
  
  #Getting out the current xref
  my $current_display_xref = shift @{$targets};
  #Getting last projection
  my $last_projection = $self->_homology_descriptor()->{$target_stable_id}->{last_projection};
  
  #If we had a projection for the stable ID already then assign for a check
  #if the display was not null
  if($last_projection) {
    $current_display_xref = $last_projection->entry() if ! defined $current_display_xref;
  }
  else {
    #Return true if empty (means we had nothing)
    return 1 if ! defined $current_display_xref;
  }
  
  #Pickup on RefSeqs
  my $target_refseq = p_or( 
    p_string_equals('RefSeq_dna_predicted', 'dbname'),
    p_string_equals('RefSeq_peptide_predicted', 'dbname') 
  );
  
  #If we can replace the existing projection if it was defined && it matched
  #one of our previous RefSeq DBs. Otherwise we ignore this 
  my $can_be_replaced = $target_refseq->apply($current_display_xref);
  $last_projection->ignore(1) if defined $last_projection && $can_be_replaced;
  return $can_be_replaced;
}

=head2 dbentry_source_object()

  Arg[1] : Member to get the DBEntry objects for

=cut

sub dbentry_source_object {
  my ($self, $member) = @_;
  return Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder->build_display_xref_from_Member($member);
}

sub _species_dbname_map_builder {
  my ($self) = @_;
  return {
    homo_sapiens => 'HGNC',
    mus_musculus => 'MarkerSymbol'
  };
}

sub _all_sources_builder {
  my ($self) = @_;
  return 0;
}

sub _one_to_many_builder {
  my ($self) = @_;
  return 0;
}

#Override used to generate the homology descriptor
sub _get_homologies {
  my ($self, $mlss) = @_;
  my $h = $self->SUPER::_get_homologies($mlss);
  my $descriptor = $self->_generate_homology_descriptor($h);
  $self->_homology_descriptor($descriptor);
  return $h;
}

#Used to do some quick generation of where in the current total of
#homologies we are processing
sub _generate_homology_descriptor {
  my ($self, $homologies) = @_;
  my $descriptor = {};
  foreach my $h (@{$homologies}) {
    my ($query_member, $target_member) = $self->_decode_homology($h);
    my $sid = $target_member->stable_id();
    if(! exists $descriptor->{$sid}) {
      $descriptor->{$sid} = { current_index => 0, total => 0 };
    }
    $descriptor->{$sid}->{total}++;
  }
  return $descriptor;
}

1;
