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

Bio::EnsEMBL::Compara::Production::Projection::GOAProjectionEngine

=head1 DESCRIPTION

This is an extension of the ProjectionEngine object which provides methods
for filtering according to rules discussed with the GOA team at the EBI.

=head1 FILTERS

=head2 DBEntry Filtering

DBEntry objects are filtered based on the following

=over 8

=item The DB name equals GO

=item DBEntry is defined and isa OntologyXref

=item The GO term has one of the following evidence tags; IDA IEP IGI IMP IPI

=back

=head2 Homology Filtering

Homology objects are filtered accordingly

=over 8

=item The description field is set to ortholog_one2one, ortholog_one2many or ortholog_many2many

=item Percentage identity of both homologous pepetides is greater than 40%

=back

=cut

package Bio::EnsEMBL::Compara::Production::Projection::GOAProjectionEngine;

use strict;
use warnings;

use base qw( Bio::EnsEMBL::Compara::Production::Projection::ProjectionEngine );

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);

use Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder;

use Data::Predicate::ClosurePredicate;
use Data::Predicate::Predicates qw(:all);

=head2 new()

  Arg[-dbentry_types] : The DBEntry database name to use. Defaults to GO
  Arg[-source]: String; defines the level to use for finding xrefs to project
                which should be assigned to the SOURCE_NAME used in MEMBER
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  
  my ($dbentry_types, $source) = rearrange([qw(dbentry_types source)], @args);
  
  $dbentry_types = $self->_dbentry_types_builder() if ! defined $dbentry_types;
  assert_ref( $dbentry_types, 'ARRAY' );
  $self->{dbentry_types} = $dbentry_types;
  
  $source ||= q{ENSEMBLPEP};
  throw "Do not understand the source $source" unless $self->_valid_sources()->{$source};
  $self->{source} = $source;
  
  return $self;
}

=head2 source()

  Description : Getter. Source used to define the level we use to get DBEntries
  from

=cut

sub source {
  my ($self, $source) = @_;
  return $self->{source};
}

=head2 dbentry_types()

  Description : Getter. Percentage identity in the source
  Can be customised by overriding C<_dbentry_types_builder>(). Defaults to
  an arrayref containing GO by default.

=cut

sub dbentry_types {
  my ($self) = @_;
  return $self->{dbentry_types};
}

=head2 excluded_terms()

Used to remove terms from the projected items which are deemed as not-useful.
This defaults to GO:0005515 (protein binding)

=cut

sub excluded_terms {
  my ($self) = @_;
  return [qw(GO:0005515)];
}

=head2 dbentry_source_object()

Override of the method from the super engine which uses the FakeXrefHolder
object to get Xrefs quickly. The class returned responds to the
C<get_all_DBEntries()> subroutine call returning all of those Translation
based DBEntry objects.

The method looks at the type of member given which will instruct the level
we perform projections at i.e. ENSEMBLGENE or ENSEMBLPEP

=cut

sub dbentry_source_object {
  my ($self, $member) = @_;
  my $decoded = $self->_decode_member($member);
  return Bio::EnsEMBL::Compara::Production::Projection::FakeXrefHolder->build_peptide_dbentries_from_Member($decoded, $self->dbentry_types());
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
    -FROM => $self->_decode_member($query_member),
    -TO => $self->_decode_member($target_member),
    -FROM_IDENTITY => $query_member->perc_id(),
    -TO_IDENTITY => $target_member->perc_id(),
    -TYPE => $homology->description()
  );
}

sub _decode_member {
  my ($self, $member) = @_;
  my $dispatch = {
    ENSEMBLPEP => sub {
      my ($member) = @_;
      if($member->source_name() eq 'ENSEMBLPEP') {
        return $member;
      }
      else {
        return $member->get_canonical_SeqMember();
      }
    },
    ENSEMBLGENE => sub {
      my ($member) = @_;
      if($member->source_name() eq 'ENSEMBLGENE') {
        return $member;
      }
      else {
        return $member->gene_member();
      }
    }
  };
  return $dispatch->{$self->source()}->($member);
}

###### BUILDERS

sub _dbentry_types_builder {
  my ($self) = @_;
  return ['GO'];
}

sub _homology_predicate_builder {
  my ($self) = @_;
  
  $self->log()->debug('Creating default Homology predicate');
  
  my @types = qw(ortholog_one2one ortholog_one2many ortholog_many2many);
  
  my $type_predicate = p_or(map { p_string_equals($_, 'description') } @types);
  
  my $percentage_identity_predicate = Data::Predicate::ClosurePredicate->new(closure => sub {
    my ($homology) = @_;
    my ($member_a, $member_b) = @{$homology->get_all_Members()};
    return $member_a->perc_id() >= 40 && $member_b->perc_id() >= 40;
  }, description => 'Filtering of homology where both members had >= 40% identity');
  
  return p_and($type_predicate, $percentage_identity_predicate);
}

sub _dbentry_predicate_builder {
  my ($self) = @_;
  
  $self->log()->debug('Creating default DBEntry predicate');
  
  #Only accept if it is defined, was blessed, dbname == GO || PO & is a OntologyXref object
  my $entry_type_predicate = p_or(map { p_string_equals($_, 'dbname') } @{$self->dbentry_types()});
  my $correct_type_predicate = p_and(p_defined(), p_blessed(), $entry_type_predicate, p_isa('Bio::EnsEMBL::OntologyXref'));
  
  #Allowed linkage types; can be any of these so it's an OR
  #  IDA Inferred from direct assay
  #  IEA Inferred from electronic annotation
  #  IGI Inferred from genetic interaction
  #  IMP Inferred from mutant phenotype
  #  IPI Inferred from physical interaction

  #We do not use these  
  #  IC Inferred by curator
  #  ISS Inferred from sequence or structural similarity
  #  NAS Non-traceable author statement
  #  ND No biological data available
  #  RCA Reviewed computational analysis
  #  TAS Traceable author statement
  # check the $_->type() method
  my $allowed_linkage_predicate = p_or(map { p_string_equals($_) } qw(IDA IEP IGI IMP IPI));
  
  #Quick closure predicate which asserts that all the linkage types from a DBEntry can be found
  my $dbentry_has_allowed_linkage_predicate = Data::Predicate::ClosurePredicate->new(closure => sub {
    my ($dbentry) = @_;
    return $allowed_linkage_predicate->all_true($dbentry->get_all_linkage_types());
  });
  
  #Filter the excluded terms (defaults to protein_binding GO:0005515)
  my $excluded_terms = $self->excluded_terms();
  my @excluded_terms_predicates = map { p_string_equals($_, 'primary_id') } @{$excluded_terms};
  my $go_term_removal_predicate = p_not(p_or(@excluded_terms_predicates));
  
  #Build it together & return
  return p_and($correct_type_predicate, $go_term_removal_predicate, $dbentry_has_allowed_linkage_predicate);
}

############### LOGIC

=pod

Override to provide more specific rules about allowing go xref transfer
based on evidence tags.

=cut

sub _transfer_dbentry_by_targets {
  my ($self, $source, $targets) = @_;
  
  my $source_ref = ref($source);
  
  my $link_join = sub {
    my ($xref) = @_;
    return join(q{}, sort @{$source->get_all_linkage_types()});
  };
  
  foreach my $target_xref (@{$targets}) {
    
    next unless check_ref($target_xref, $source_ref);
    
    #Reject if it was the same
    if ( 
        $source->dbname() eq $target_xref->dbname() &&
	      $source->primary_id() eq $target_xref->primary_id() &&
	      $link_join->($source) eq $link_join->($target_xref)) {
	      
      if($self->log()->is_trace()) {
        my $linkage_join = $link_join->($source);
        $self->log()->trace(sprintf(
          'Rejecting because target entity had a DBEntry (%d) with the same dbnames, primary ids & linkage type (%s) as the source DBEntry (%d)',
          $target_xref->dbID(), $linkage_join, $source->dbID()
        ));
      }
      
      return 0;
    }

    # if a GO term with the same accession, but IEA evidence code, exists, also don't project, as this
    # will lead to duplicates when the projected term has its evidence code changed to IEA after projection
    if ($source->primary_id() eq $target_xref->primary_id()) {
      foreach my $evidence_code (@{$target_xref->get_all_linkage_types()}) {
        if($evidence_code eq 'IEA') {
          if($self->log()->is_trace()) {
  	        $self->log()->trace(sprintf('Rejecting because %s is already projected by IEA', 
    	       $target_xref->primary_id()
    	      ));
  	      }
          return 0;
        }
      }
    }
  }
  
  return 1;
}

sub _valid_sources {
  my ($self) = @_;
  my %valid = map { $_ => 1} qw(ENSEMBLGENE ENSEMBLPEP);
  return \%valid;
}

1;
