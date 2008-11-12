package EnsEMBL::Web::Input::CGI;

=head1 NAME

EnsEMBL::Web::Input::CGI.pm 

=head1 SYNOPSIS

Used to get CGI type input for web API view scripts

=head1 DESCRIPTION

 my $input = new EnsEMBL::Web::Input::CGI( $ENV{'ENSEMBL_SCRIPT'} );
 
 Sorts CGI parameters into object and check that the parameters are valid,
 Also checks for alternative parameter names

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Brian Gibbins - bg2@sanger.ac.uk

=head1 APPENDIX

'_get_input_parameters' method is required when creating a new module

=cut

use strict;
use CGI;
use EnsEMBL::Web::Input;
@EnsEMBL::Web::Input::CGI::ISA = qw(EnsEMBL::Web::Input);

=head2 _get_input_parameters

 Example 	: $self->_get_input_parameters()
 Description: Internal call from parent INPUT class to Sort parameters into hash
 Returns 	: reference to paramter hash

=cut

sub _get_input_parameters {
  my $self = shift;
  my $cgi = new CGI;
  my %pars = map { ($self->_alt_names()->{$_} || $_) => $cgi->param( $_ ) } $cgi->param();
  $pars{'page_type'} 	= ($cgi->param( 'db' ) || 'core' );	### hack to get page type passed down  will be added to analysis table soon
  $pars{'species'} 		= $ENV{'ENSEMBL_SPECIES'} ;
  $pars{'session'} 		= $ENV{'ENSEMBL_SESSION'}  ;	# change to get sessions (for submission and contigview) at later date
  $pars{'script_name'}  = $ENV{'ENSEMBL_SCRIPT'};

  return \%pars;
}

1;
