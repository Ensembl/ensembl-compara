#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME
Bio::EnsEMBL::Compara::Hive::Queen
=cut

=head1 SYNOPSIS
The Queen of the Hive based job control system
=cut

=head1 DESCRIPTION
The Queen of the Hive based job control system is responsible to 'birthing' the
correct number of workers of the right type so that they can find jobs to do.
It will also free up jobs of Workers that died unexpectantly so that other workers
can claim them to do.
=cut

=head1 CONTACT

Jessica Severin, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Hive::Queen;

use strict;

use Bio::EnsEMBL::Root;
use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Root);


1;
