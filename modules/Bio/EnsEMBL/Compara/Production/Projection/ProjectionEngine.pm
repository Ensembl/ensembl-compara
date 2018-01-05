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

Bio::EnsEMBL::Compara::Production::Projection::ProjectionEngine

=head1 DESCRIPTION

This is a re-implementation of the code currently held in Ensembl's core
API checkout which can project DBEntries from one species to another
by using the Homologies projected from the Compara Genomics GeneTree
pipeline. Normally this is used to project GO terms from a well annotated
species to one which is not.

Ensembl's original implementation involved a monolithic script with
no scope for customisation. This implementation attempts to be as pluggable
as possible by leveraging L<Data::Predicate>s (a way of encapsulating logic
to allow a user to specify their own filters). This means the algorithm 
for projection becomes

=over 8

=item Get all homologies projected between two species (one given at construction) the other when we run C<project>

=item Filter them for allowed linkage using C<homology_predicate()> e.g. filter on allowed mappings or percentage identitiy limits 

=item Loop through these homologies

=item For each member of the homology get the DBEntry objects from the core database (delegates to Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder)

=item For each source DBEntry filter out using C<db_entry_predicate()> ensuring we want to work with this DBEntry type

=item If we still have a DBEntry then make sure the target does not already have the DBEntry linked to it

=item If still okay then build a C<Bio::EnsEMBL::Compara::Production::Projection::Projection> object based on this

=item Return an ArrayRef of these projection objects 

=back

The main way to cut into this procedure is to give your own predicates
during construction or to extend this module & reimplement the builder methods.

=head1 CAVEATS

=over 8

=item This version is designed for a basic plant transfer algorithm

=item We must consult both GO and PO External DBs because plant databases have mixed usage of these types

=item We only project GOs

=back

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::ProjectionEngine;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use Data::Predicate::Predicates qw(:all);
use Bio::EnsEMBL::Compara::Production::Projection::Projection;

=head2 new()

  Arg[-dbentry_predicate] : Predicate used to filter out DBEntry instances
  Arg[-homology_predicate] : Predicate used to filter out Homology instances
  Arg[-log] : Logger instance. Can be a Log::Log4perl::Logger instance or a class which implements the methods 
  Arg[-dba] : required; Compara adaptor to get homologies from
  Arg[-method_link_type] : Method link to get homologies from
  Arg[-genome_db] : required; GenomeDB to use as the source of the homologies
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my (  $dbentry_predicate, $homology_predicate, $log, $dba,
        $method_link_type, $genome_db ) = rearrange([ qw(
      dbentry_predicate homology_predicate log 
      dba method_link_type genome_db )
  ], @args);

  assert_ref( $dbentry_predicate, 'Data::Predicate' )
    if defined $dbentry_predicate;
  $self->{dbentry_predicate} = $dbentry_predicate
    if defined $dbentry_predicate;

  assert_ref( $homology_predicate, 'Data::Predicate' )
    if defined $homology_predicate;
  $self->{homology_predicate} = $homology_predicate
    if defined $homology_predicate;

  $log = $self->_log_builder() if !defined $log;
  confess('The attribute log must be specified during construction or provide a builder subroutine') if !defined $log;
  $self->{log} = $log if defined $log;

  assert_ref( $dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor' );
  confess('The attribute dba must be specified during construction or provide a builder subroutine') if !defined $dba;
  $self->{dba} = $dba if defined $dba;

  $method_link_type = $self->_method_link_type_builder()
    if !defined $method_link_type;
  $self->{method_link_type} = $method_link_type if defined $method_link_type;

  assert_ref( $genome_db, 'Bio::EnsEMBL::Compara::GenomeDB' );
  confess('The attribute genome_db must be specified during construction or provide a builder subroutine' ) if !defined $genome_db;
  $self->{genome_db} = $genome_db if defined $genome_db;

  return $self;
}

=head2 dbentry_predicate()

  Description : Getter. Predicate used to filter out DBEntry instances
  Can be customised by overriding C<_dbentry_predicate_builder>().

=cut

sub dbentry_predicate {
  my ($self) = @_;
  if ( !exists $self->{dbentry_predicate} ) {
    $self->{dbentry_predicate} = $self->_dbentry_predicate_builder();
  }

  return $self->{dbentry_predicate};
}

=head2 homology_predicate()

  Description : Getter. Predicate used to filter out Homology instances
  Can be customised by overriding C<_homology_predicate_builder>().

=cut

sub homology_predicate {
  my ($self) = @_;
  if ( !exists $self->{homology_predicate} ) {
    $self->{homology_predicate} = $self->_homology_predicate_builder();
  }
  return $self->{homology_predicate};
}

=head2 log()

  Description : Getter. Logger instance

=cut

sub log {
  my ($self) = @_;
  return $self->{log};
}

=head2 dba()

  Description : Getter. Compara adaptor to get homologies from

=cut

sub dba {
  my ($self) = @_;
  return $self->{dba};
}

=head2 method_link_type()

  Description : Getter. Method link to get homologies from
  Can be customised by overriding C<_method_link_type_builder>(). Defaults to
  ENSEMBL_ORTHOLOGUES.

=cut

sub method_link_type {
  my ($self) = @_;
  return $self->{method_link_type};
}

=head2 genome_db()

  Description : Getter. GenomeDB to use as the source of the homologies

=cut

sub genome_db {
  my ($self) = @_;
  return $self->{genome_db};
}


######BUILDERS

sub _method_link_type_builder {
  my ($self) = @_;
  return 'ENSEMBL_ORTHOLOGUES';
}

my $imported_log4p = 0;

sub _log_builder {
  my ($self) = @_;
  if(! $imported_log4p) {
    eval {require Log::Log4perl};
    if($@) {
      throw('Cannot build a logger because Log::Log4perl is not available. Detected error: '.$@);
    }
    $imported_log4p = 1;
  }
  return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _homology_predicate_builder {
  my ($self) = @_;
  throw('Override to provide a default Homology predicate');
}

sub _dbentry_predicate_builder {
  my ($self) = @_;
  throw('Override to provide a default DBEntry predicate');
}

######LOGIC

=head2 project()

  Arg[0]      : GenomeDB object which is used as the projection target
  Description : Workhorse subroutine which loops through homologies and filters
                through those and DBEntry objects using L<Data::Predicate>
                objects. See class description for more information on the
                filtering process.
  Returntype  : Bio::EnsEMBL::Compara::Production::Projection::Projection
  Exceptions  : If we cannot contact the target databases 

=cut

sub project {
  my ($self, $target_genome_db) = @_;
  
  my $log = $self->log();
  
  $log->info('Processing '.$self->genome_db()->name().' Vs. '.$target_genome_db->name());
  
  my $mlss = $self->_get_mlss($target_genome_db);
  my $homologies = $self->_homologies($mlss);
  
  my @projections;
  
  $log->info('Looping over '.scalar(@{$homologies}).' homologies');
  foreach my $homology (@{$homologies}) {
    my ($query_member, $target_member) = $self->_decode_homology($homology);
    
    if($self->log()->is_trace()) {
      my $q_id = $query_member->stable_id();
      my $t_id = $target_member->stable_id();
      $log->trace(sprintf('Projecting from %s to %s', $q_id, $t_id));
    }
    
    my $query_dbentry_holder = $self->dbentry_source_object($query_member);
    my $target_dbentry_holder = $self->dbentry_source_object($target_member);
    my $db_entries = $query_dbentry_holder->get_all_DBEntries();
    foreach my $dbentry (@{$db_entries}) {
      
      if($log->is_trace()) {
        $log->trace(sprintf('Working with %s from external db %s', $dbentry->primary_id(), $dbentry->dbname()));
      }
      
      my $filter_dbentry = $self->_filter_dbentry($dbentry, $target_dbentry_holder);
      if($filter_dbentry) {
        
        if($log->is_trace()) {
          $log->trace('Passes DBEntry filter');
        }
        
        if($self->_transfer_dbentry_by_targets($dbentry, $target_dbentry_holder->get_all_DBEntries(), $target_member->stable_id())) {
          $log->trace('DBEntry will be transferred');
          my $projection = $self->build_projection($query_member, $target_member, $dbentry, $homology);
          push(@projections, $projection) if defined $projection;
        }
        else {
          if($log->is_trace()) {
            $log->trace('Failed target entry transfer; check target for existing annotation or better quality annotation');
          }
        }
      }
      else {
        if($log->is_trace()) {
          $log->trace('Fails DBEntry filter');
        }
      }
    }
  }
  
  $log->info('Finished homology and have found '.scalar(@projections).' projection(s)');
  
  return \@projections;
}

=head2 build_projection()

  Arg[1]      : Member; source member of projection
  Arg[2]      : Member; target member of projection
  Arg[3]      : DBEntry projected
  Arg[4]      : The homology used for projection
  Description : Provides an abstraction to building a projection from a 
                set of elements.
  Returntype  : Projection object. Can be null & the current projection code
                will ignore it

=cut

sub build_projection {
  my ($self, $query_member, $target_member, $dbentry, $homology) = @_;
  return Bio::EnsEMBL::Compara::Production::Projection::Projection->new(
    -ENTRY => $dbentry,
    -FROM => $query_member->get_canonical_SeqMember(),
    -TO => $target_member->get_canonical_SeqMember(),
    -FROM_IDENTITY => $query_member->perc_id(),
    -TO_IDENTITY => $target_member->perc_id(),
    -TYPE => $homology->description()
  );
}

sub _get_mlss {
  my ($self, $target_genome_db) = @_;
  my $mlssa = $self->dba()->get_MethodLinkSpeciesSetAdaptor();
  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs(
    $self->method->type(), [$self->genome_db(), $target_genome_db]);
  return $mlss;
}

sub _homologies {
  my ($self, $mlss) = @_;
  $self->log()->debug('Retriving homologies');
  my $homologies = $self->_get_homologies($mlss);
  $self->log()->debug('Filtering homologies');
  my $predicate = $self->homology_predicate();
  my $log = $self->log();
  my $trace = $log->is_trace();
  my @filtered;
  foreach my $h (@{$homologies}) {
    $log->trace(sprintf('Filtering homology %d', $h->dbID())) if $trace;
    if($predicate->apply($h)) {
      $log->trace('Accepted homology') if $trace;
      push(@filtered, $h);
    }
    else {
      $log->trace('Rejected homology') if $trace;
    }
  }
  $self->log()->debug('Finished filtering');
  return \@filtered;
}

sub _filter_dbentry {
  my ($self, $dbentry, $target_dbentry_holder) = @_;
  return $self->dbentry_predicate()->apply($dbentry);
}

sub _transfer_dbentry_by_targets {
  my ($self, $source, $targets) = @_;

  my $source_ref = ref($source);

  foreach my $target_xref (@{$targets}) {
    next unless check_ref($target_xref, $source_ref);
    #Reject if it was the same
    if ( $source->dbname() eq $target_xref->dbname() &&
	    $source->primary_id() eq $target_xref->primary_id()) {
      return 0;
    }
  }

  return 1;
}

sub _decode_homology {
  my ($self, $homology) = @_;
  
  my $query;
  my $target;
  
  foreach my $member (@{$homology->get_all_Members}) {
    if($member->genome_db()->dbID() == $self->genome_db()->dbID()) {
      $query = $member;
    }
    else {
      $target = $member;
    }
  }
  
  return ($query, $target);
}

sub _get_homologies {
  my ($self, $mlss) = @_;
  my $ha = $self->dba()->get_HomologyAdaptor();
  $self->log()->debug('Fetching homologues');
  my $homologies = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss);
  return $homologies;
}

=head2 dbentry_source_object()

  Arg[1] : Member to get the DBEntry objects for

=cut

sub dbentry_source_object {
  my ($self, $member) = @_;
  throw('Unsupported operation called; override in the implementing class');
}

1;
