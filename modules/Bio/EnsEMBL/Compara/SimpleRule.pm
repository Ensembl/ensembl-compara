# Perl module for Bio::EnsEMBL::Compara::SimpleRule
#
# Creator: Jessica Severin <jessica@ebi.ac.uk>
# Date of creation: 22.03.2004
#
# Copyright EMBL-EBI 2000-2004
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SimpleRule

=head1 SYNOPSIS


=head1 DESCRIPTION

  Needed a more robust and simpler rule table
  For compara pipeline where Analyses in the pipeline can robustly define
  new analyses and rules.  New design has a single table where a 'rule'
  is a simple link from one analysis (condition) to another (goal).
  Does away with accumulators.

=head1 CONTACT

    Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
    Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SimpleRule;

use vars qw(@ISA);
use Bio::EnsEMBL::Root;
use strict;

@ISA = qw( Bio::EnsEMBL::Root );

=head2 Constructor

  Title   : new
  Usage   : ...SimpleRule->new($analysis);
  Function: Constructor for SimpleRule object
  Returns : Bio::EnsEMBL::Pipeline::SimpleRule
  Args    : A Bio::EnsEMBL::Analysis object. Conditions are added later,
            adaptor and dbid only used from the adaptor.
=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  my ( $goal, $adaptor, $dbID, $condition ) =
    $self->_rearrange( [ qw (GOAL_ANALYSIS ADAPTOR DBID CONDITION_ANALYSIS) ], @args );
    
  $self->dbID( $dbID );
  $self->conditionAnalysis( $condition );
  $self->goalAnalysis( $goal );
  $self->adaptor( $adaptor );

  return $self;
}

=head2 conditionAnalysis

  Title   : conditionAnalysis
  Usage   : $self->conditionAnalysis($anal);
  Function: Get/set method for the condition analysis object of this rule.
  Returns : Bio::EnsEMBL::Analysis
  Args    : Bio::EnsEMBL::Analysis

=cut

sub conditionAnalysis {
  my ($self,$analysis) = @_;

  if( defined $analysis ) {
    unless ($analysis->isa('Bio::EnsEMBL::Analysis')) {
      $self->throw(
        "conditionAnalysis arg must be a [Bio::EnsEMBL::Analysis]".
        "not a [$analysis]");
    }
    $self->{'_condition_analysis'} = $analysis;
  }
  return $self->{'_condition_analysis'};
}


=head2 goalAnalysis

  Title   : goalAnalysis
  Usage   : $self->goalAnalysis($anal);
  Function: Get/set method for the goal analysis object of this rule.
  Returns : Bio::EnsEMBL::Analysis
  Args    : Bio::EnsEMBL::Analysis

=cut

sub goalAnalysis {
  my ($self,$analysis) = @_;

  if( defined $analysis ) {
    unless ($analysis->isa('Bio::EnsEMBL::Analysis')) {
      $self->throw(
        "goalAnalysis arg must be a [Bio::EnsEMBL::Analysis]".
        "not a [$analysis]");
    }
    $self->{'_goal_analysis'} = $analysis;
  }
  return $self->{'_goal_analysis'};
}


sub dbID {
  my ( $self, $dbID ) = @_;
  $self->{'_dbID'} = $dbID if defined $dbID;
  return $self->{'_dbID'};
}

sub adaptor {
  my ( $self, $adaptor ) = @_;
  $self->{'_adaptor'} = $adaptor if defined $adaptor;
  return $self->{'_adaptor'};
}

=head2
  Override these methods to maintain compatibility with Rule.pm
  to allow faster development until I can disentangle things
  - Rule.pm stores 'conditions' as logic_names rather than objects
    so these routines expect to input/ouput via logic_name
=cut

sub add_condition {
  my $self = shift;
  my $logic_name = shift;
  $self->throw("Can't add_condition unless SimpleRule is presistent") unless($self->adaptor)
  my $condition = $self->adaptor->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);
  $self->conditionAnalysis($condition);
}

sub list_conditions {
  my $self = shift;
  my @condition_logic_names;
  push @condition_logic_names, $self->conditionAnalysis()->logic_name();
  return \@condition_logic_names;
}

sub has_condition_of_input_id_type {
  my $self = shift;
  my $input_type = shift;

  $self->throw("No condition defined") unless($self->conditionAnalysis);

  return 1 if($self->conditionAnalysis->input_id_type eq $input_type);
  return 0;
}

=head2 check_for_analysis

 -args: [analysis list], 'input id type', {completed accumulators}, verbose
 -returns: Either bits for status if nothing can be done;
           1 - Failed Input_Id_Type Check.
           2 - Failed Already Complete Check [so is complete].
           4 - Failed Condition Check.
           Or;
           $goalAnalysis if it should be done
=cut


sub check_for_analysis {
  my $self = shift;
  my ($analist, $input_id_type, $completed_accumulator_href, $verbose) = @_;
  my %anaHash;
  my $return = 0;

  # reimplement with proper identity check!
  my $goal_anal    = $self->goalAnalysis;
  my $goal         = $goal_anal->dbID;
  my $goal_id_type = $goal_anal->input_id_type;

  print "\nHave goal type ".$goal_id_type." and input id type ".$input_id_type."\n" if($verbose);

#This id isn't of the right type so doesn't satify goal
  if ($goal_id_type ne 'ACCUMULATOR' &&
      $goal_id_type ne $input_id_type) {
    print "In check_for_analysis failed input_id_type check as goal input_id type ".
      "isn't the same as the input_id type\n" if($verbose);
    $return += 1;
  }


  print "My goal is " . $goal_anal->logic_name . "\n" if($verbose);

  for my $analysis ( @$analist ) {

    print " Analysis " . $analysis->logic_name . " " . $analysis->dbID . "\n" if($verbose);
    $anaHash{$analysis->logic_name} = $analysis;

    if ($goal == $analysis->dbID) {
      # already done
      print $goal_anal->logic_name." already done\n" if($verbose);
      $return += 2;
    }
  }

#the completed_accumulator_href contains input_id_type ACCUMULATOR anals that have completed
  for my $cond ( @{$self->{'_conditions'}} ) {
    if ( ! exists $anaHash{$cond} && ! exists $completed_accumulator_href->{$cond}) {
      print " failed condition check for $cond\n" if($verbose);
      $return += 4;
    }
  }

  return $return if $return;
  return $goal_anal;
}


1;



