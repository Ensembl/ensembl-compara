package EnsEMBL::Web::Problem;

=head1 NAME

EnsEMBL::Web::Problem.pm 

=head1 SYNOPSIS

Object to store error type things for new web api

=head1 DESCRIPTION

 my $problem =  EnsEMBL::Web::Problem->new( $problem_type, $title, $description );
 if ($problem->isFatal){..}
 
 Creates a problem object and also has some accessors to print and check for errors/problems
 
 Possible error types: 
	mapped_id, 
	multiple_matches, 
	no_match, 
	fatal_error

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Brian Gibbins - bg2@sanger.ac.uk

=cut

use strict;

sub new{
  my $class = shift;       
  my ($type,$name,$description) = @_;
  my $self = { 	'type'=>$type, 
  				'name'=>$name, 
				'description'=>$description };
  bless $self,$class;
}

=head2 type

 Description : To get type of error
 Return type : string

=cut

sub type {$_[0]->{type}}

=head2 name

 Description : To get title of error
 Return type : string

=cut

sub name {$_[0]->{name}}

=head2 description

 Description : To get description of error
 Return type : string

=cut

sub description {$_[0]->{description}}

=head2 isFatal, isNoMatch, isMultipleMatches, isMappedId

 Description : checks to see if an error is fatal, nomatch, mutliple or mappedId
 Return type : bool (1:0)

=cut

sub get_by_type       {$_[0]->{type} =~ /$_[1]/i}
sub isFatal           {$_[0]->{type} =~ /fatal/i}
sub isNoMatch         {$_[0]->{type} =~ 'no_match'}
sub isMultipleMatches {$_[0]->{type} =~ 'multiple_matches'}
sub isMappedId        {$_[0]->{type} =~ 'mapped_id'}

sub isNonFatal        {
  my $self = shift;
  my $non_fatal = 1 ;
  if( ($self->{'type'} eq 'non_fatal' || $self->isNoMatch || $self->isMultipleMatches || $self->isMappedId ) &&  !$self->isFatal){
    return $non_fatal;
  }
  return 0;
}

1;
