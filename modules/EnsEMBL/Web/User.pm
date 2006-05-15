package EnsEMBL::Web::User;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::UserDetails;

sub new {
  my $class = shift;

  ## is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER'} || 0;

  my $details;
  if ($user_id) {
   # $details = EnsEMBL::Web::UserDetails->new($user_id);
  } 

  my $self = {
    '_user_id'      => $user_id,
    '_user_details' => $details,
  };
  bless($self, $class);
  return $self;
}


sub id       { return $_[0]{'_user_id'}; }
sub details  { return $_[0]{'_user_details'}; }

1;

__END__
                                                                                
=head1 Ensembl::Web::User
                                                                                
=head2 SYNOPSIS
                                                                                
This object is instantiated by either Apache::SendDecPage or ??, thus it should not need to
to be called by any other script or module. If the user is not logged in, the object is
instantiated with a zero ID, thus avoiding unnecessary repetition of cookie-checking, etc.

=head2 DESCRIPTION
                                                                                
The User object is a simple wrapper for the E::W::UserDetails object, thus allowing both
user authentication and user account management to get access to the same information without
duplication. See also E::W::Object::User

=head2 METHODS

=head3 B<new>

Description: Constructor. Checks for a user ID as an environmental variable (which should have
been set by Apache::Handlers::initHandler), and stores it. If an ID is found, it instantiates 
an embedded object, E::W::UserDetails

Arguments: class  
                                                                                
Returns: EnsEMBL::Web::User object

=head3 B<id>

Description: accessor method.

Arguments: User object

Returns: positive integer, or zero if user is not logged in.

=head3 B<details>

Description: accessor method.

Arguments: User object

Returns: reference to an E::W::UserDetails object

=head2 BUGS AND LIMITATIONS
                                                                                
None known at present.

=head2 AUTHOR
                                                                                
[you], Ensembl Web Team
Support enquiries: helpdesk\@ensembl.org
                                                                                
=head2 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html
                                                                                
=cut

