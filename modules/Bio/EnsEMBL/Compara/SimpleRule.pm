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

1;



