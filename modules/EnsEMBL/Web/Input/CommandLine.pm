package EnsEMBL::Web::Input::CommandLine;

=head1 NAME

EnsEMBL::Web::Input::CommandLine.pm 

=head1 SYNOPSIS

Used to get parameter input from the command line for web API view scripts

=head1 DESCRIPTION

 my $input = new EnsEMBL::Web::Input::ComandLine( 'script_name' );
 
 Sorts parameters from command line into object and check that the parameters are valid, Also checks for alternative parameter names

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Brian Gibbins - bg2@sanger.ac.uk

=head1 APPENDIX

'_get_input_parameters' method is required when creating a new module

=cut

use strict;
use File::Basename;
use EnsEMBL::Web::Input;
@EnsEMBL::Web::Input::CommandLine::ISA = qw(EnsEMBL::Web::Input);

=head2 _get_input_parameters

 Example 	: $self->_get_input_parameters()
 Description: Internal call from parent INPUT class to Sort parameters into hash
 Returns 	: reference to paramter hash

=cut

sub _get_input_parameters {
  my $self = shift;
  my @lineArgs = split /-(\w+)[\s+=]/ ,(join ' ', @ARGV) ;
  shift @lineArgs;
  for (@lineArgs){ s/(\S+\s?\S*)\s+/$1/; }
  my (%parameters) = @lineArgs;
	
  my %pars = map { ($self->_alt_names()->{$_} || $_) => $parameters{ $_ }  } keys %parameters;
  $pars{'species'} 	   = ($parameters{ 'species' } || 'Homo_sapiens') ;
  $pars{'page_type'}   = ($parameters{ 'db' } || 'core' );	
  $pars{'script_name'} = basename($0) ;
  $pars{'species'}		=~ s/\s*(\w+)\s*/$1/;
  $pars{'page_type'}	=~ s/\s*(\w+)\s*/$1/;

  $ENV{'ENSEMBL_SPECIES'} = $pars{'species'}; 
  $ENV{'ENSEMBL_script'} = $pars{'script_name'};
  
  return \%pars;
}

1;
