# Perl module for Bio::EnsEMBL::Compara::DBSQL::SimpleRuleAdaptor
#
# Date of creation: 22.03.2004
# Original Creator : Jessica Severin <jessica@ebi.ac.uk>
#
# Copyright EMBL-EBI 2004
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::SimpleRuleAdaptor 

=head1 SYNOPSIS

  $simpleRuleAdaptor = $db_adaptor->get_SimpleRuleAdaptor;
  $simpleRuleAdaptor = $simpleRuleObj->adaptor;

=head1 DESCRIPTION
  
  Module to encapsulate all db access for persistent class SimpleRule.
  There should be just one per application and database connection.

=head1 CONTACT

    Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
    Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::SimpleRuleAdaptor;

use strict;
use Carp;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::SimpleRule;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);



=head2 fetch_by_goal

  Args       : Bio::EnsEMBL::Analysis
  Example    : my @rules = @{$ruleAdaptor->fetch_by_goal($goalAnalysis)};
  Description: searches database for rules with given goal analysis
               returns all such rules in a list (by reference)
  Returntype : reference to list of Bio::EnsEMBL::Pipeline::SimpleRule objects
  Exceptions : none
  Caller     : ?

=cut
sub fetch_by_goal_analysis
{
  my $self = shift;
  my $goalAnalysis = shift;
  my $rule;
  my @rules;
  
  $self->throw("arg is required\n")
    unless($goalAnalysis);
  $self->throw("arg must be a [Bio::EnsEMBL::Analysis] not a $goalAnalysis")
    unless ($goalAnalysis->isa('Bio::EnsEMBL::Analysis'));
  $self->throw("analysis arg must be presistent\n")
    unless($goalAnalysis->dbID);

  my $constraint = "r.goal_analysis_id = '".$goalAnalysis->dbID."'";

  return $self->_generic_fetch($constraint);
}


=head2 fetch_by_condition_and_goal

  Args       : Bio::EnsEMBL::Analysis
  Example    : my $rule = $ruleAdaptor->fetch_by_condition_and_goal($goalAnalysis);
  Description: searches database for rules with given condition and goal analysis
               returns the rule (single) in a list (by reference)
  Returntype : a Bio::EnsEMBL::Pipeline::SimpleRule object
  Exceptions : none
  Caller     : ?

=cut
sub fetch_by_condition_and_goal
{
  my $self = shift;
  my $conditionAnalysis = shift;
  my $goalAnalysis = shift;
  my $rule;
  my @rules;

  $self->throw("arg is required\n")
    unless($goalAnalysis);
  $self->throw("arg must be a [Bio::EnsEMBL::Analysis] not a $goalAnalysis")
    unless ($goalAnalysis->isa('Bio::EnsEMBL::Analysis'));
  $self->throw("analysis arg must be presistent\n")
    unless($goalAnalysis->dbID);

  my $constraint = "r.condition_analysis_id = '".$conditionAnalysis->dbID."'";
  $constraint   .= " AND r.goal_analysis_id = '".$goalAnalysis->dbID."'";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}


=head2 store

  Title   : store
  Usage   : $self->store( $rule );
  Function: Stores a rule in db
            Sets adaptor and dbID in SimpleRule
  Returns : -
  Args    : Bio::EnsEMBL::Pipeline::SimpleRule

=cut

sub store {
  my ( $self, $rule ) = @_;

  #print("\nSimpleRuleAdaptor->store()\n");
  my $simple_rule_id;
  
  my $sth = $self->prepare( q{INSERT INTO simple_rule
       SET condition_analysis_id = ?, goal_analysis_id = ? } );
  if($sth->execute($rule->conditionAnalysis->dbID, $rule->goalAnalysis->dbID)) {
    $simple_rule_id = $sth->{'mysql_insertid'};
    $sth->finish();
    $rule->dbID($simple_rule_id);
    #print("  stored with dbID = $simple_rule_id\n");
  } else {
    #print("  failed to execute -> already inserted -> need to get dbID\n");
    $sth->finish();   
    $sth = $self->prepare(q{SELECT simple_rule_id FROM simple_rule WHERE
         condition_analysis_id = ? AND goal_analysis_id = ? } );
    $sth->execute($rule->conditionAnalysis->dbID, $rule->goalAnalysis->dbID);
    $sth->bind_columns(\$simple_rule_id);
    if($sth->fetch()) {
      $rule->dbID($simple_rule_id);
    }
    $sth->finish;
  }
  #print("  simple_rule_id = '".$rule->dbID."'\n");
  $rule->adaptor( $self );
}


=head2 remove

  Title   : remove
  Usage   : $self->remove( $rule );
  Function: removes given object from database.
  Returns : -
  Args    : Bio::EnsEMBL::Pipeline::SimpleRule which must be persistent.
            ( dbID set )
=cut

sub remove {
  my ( $self, $rule ) = @_;

  my $dbID = $rule->dbID;
  if( !defined $dbID ) {
    $self->throw( "SimpleRuleAdaptor->remove called with non persistent SimpleRule" );
  }

  my $sth = $self->prepare("DELETE FROM simple_rule WHERE simple_rule_id = $dbID");
  $sth->execute;
}

############################
#
# INTERNAL METHODS
# (pseudo subclass methods)
#
############################

#internal method used in multiple calls above to build objects from table data

sub _tables {
  my $self = shift;

  return (['simple_rule', 'r']);
}

sub _columns {
  my $self = shift;

  return qw (r.simple_rule_id
             r.condition_analysis_id
             r.goal_analysis_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @rules = ();

  #$self->add_CanonicalAdaptor('Analysis'  , 'Bio::EnsEMBL::Pipeline::DBSQL::AnalysisAdaptor');
  #my $analysisDBA = $self->db->get_adaptor("Analysis");
  my $analysisDBA = $self->db->get_AnalysisAdaptor;
  #print("!!!!USING get_AnalysisAdaptor\n");

  my ($simple_rule_id, $condition_analysis_id, $goal_analysis_id);
  $sth->bind_columns(\$simple_rule_id, \$condition_analysis_id, \$goal_analysis_id);

  while ($sth->fetch()) {
    print("fetch dbID=$simple_rule_id  condition_id=$condition_analysis_id  goal_id=$goal_analysis_id\n");
    my $condition_analysis = $analysisDBA->fetch_by_dbID($condition_analysis_id);
    my $goal_analysis      = $analysisDBA->fetch_by_dbID($goal_analysis_id);
    
    push @rules, Bio::EnsEMBL::Compara::SimpleRule->new(
       -adaptor             => $self,
       -dbID                => $simple_rule_id,
       -condition_analysis  => $condition_analysis,
       -goal_analysis       => $goal_analysis);
  }

  return \@rules;
}

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;
  return '';
}

###############################################################################
#
# General access methods that could be moved
# into a superclass
#
###############################################################################

=head2 list_internal_ids

  Arg        : None
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub list_internal_ids {
  my $self = shift;

  my @tables = $self->_tables;
  my ($name, $syn) = @{$tables[0]};
  my $sql = "SELECT ${syn}.${name}_id from ${name} ${syn}";

  my $sth = $self->prepare($sql);
  $sth->execute;

  my $internal_id;
  $sth->bind_columns(\$internal_id);

  my @internal_ids;
  while ($sth->fetch()) {
    push @internal_ids, $internal_id;
  }

  $sth->finish;

  return \@internal_ids;
}

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the Member created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Member
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_by_source_stable_id

  Arg [1]    : string $source_name
  Arg [2]    : string $stable_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub fetch_by_source_stable_id {
  my ($self,$source_name, $stable_id) = @_;

  unless(defined $source_name) {
    $self->throw("fetch_by_source_stable_id must have an source_name");
  }
  unless(defined $stable_id) {
    $self->throw("fetch_by_source_stable_id must have an stable_id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};
  my ($source_table, $source_syn) = @{$tabs[1]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${source_syn}.source_name = '$source_name' AND ${syn}.stable_id = '$stable_id'";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_all

  Arg        : None
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}

=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::_generic_fetch

=cut

sub _generic_fetch {
  my ($self, $constraint, $join) = @_;

  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());

  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;

        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      }
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }

  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) {
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause";

  my $sth = $self->prepare($sql);
  $sth->execute;

#  print STDERR $sql,"\n";

  return $self->_objs_from_sth($sth);
}


1;

