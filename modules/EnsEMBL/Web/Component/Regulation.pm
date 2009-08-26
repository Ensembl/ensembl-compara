package EnsEMBL::Web::Component::Regulation;

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

CONTACT  <webmaster@sanger.ac.uk>

=cut

use EnsEMBL::Web::Component;
use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj;

use EnsEMBL::Web::Form;

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);


sub email_URL {
    my $email = shift;
    return qq(&lt;<a href='mailto:$email'>$email</a>&gt;) if $email;
}

1;
