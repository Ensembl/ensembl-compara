package EnsEMBL::Web::Record::Group;

=head1 NAME

EnsEMBL::Web::Record::Group - A class for managing information relating to a group of uses. This class demonstrates how to subclass EnsEMBL::Web::Record for more control.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

This class allows the easy management of persistent information relating to a group of users. 

It was initially developed for use with the Ensembl Genome Browser (http://www.ensembl.org).

    use EnsEMBL::Web::Record::Group;

    my $bookmark = EnsEMBL::Web::Record->new();
    $bookmark->url('http://www.ensembl.org');
    $bookmark->name('Ensembl');
    $bookmark->save;
    ...

=cut

=head1 FUNCTIONS
=cut

use strict;
use warnings;
use EnsEMBL::Web::Record;

our @ISA = qw(EnsEMBL::Web::Record);

{

=head2 new 
Instantiates a new EnsEMBL::Web::Record::Group object.
=cut

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  if ($params{'group'}) {
    $self->owner($params{'group'});
  }
  return $self;
}

=head2 group
An alias to the owner method.
=cut

sub group {
  my ($self) = shift;
  $self->owner(@_);
}

=head2 delete 
Deletes an record (ie, a row) from the database.
=cut

sub delete {
  my $self = shift;
  $self->adaptor->delete_record((
                                  id => $self->id,
                               table => 'group'
                               ));
}

=head2 save 
Saves a record.
=cut

sub save {
  my $self = shift;
  my $dump = $self->dump_data;
  if ($self->id) {
    $self->adaptor->update_record((
                                    id => $self->id,
                                  user => $self->user,
                                  type => $self->type,
                                  data => $dump, 
                                 table => 'group'
                                 ));
  } else {
    my $new_id = $self->adaptor->insert_record((
                                  user => $self->user,
                                  type => $self->type,
                                  data => $dump,
                                 table => 'group'
                                 ));
    $self->id($new_id);
  }
  return 1;
}

}
=head1 AUTHOR

Matt Wood, C<< <mjw at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-ensembl-web-record at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=EnsEMBL-Web-Record>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc EnsEMBL::Web::Record

You can also look for information at: http://www.ensembl.org

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/EnsEMBL-Web-Record>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/EnsEMBL-Web-Record>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=EnsEMBL-Web-Record>

=item * Search CPAN

L<http://search.cpan.org/dist/EnsEMBL-Web-Record>

=back

=head1 ACKNOWLEDGEMENTS

Many thanks to everyone on the Ensembl team, in particular James Smith, Anne Parker, Fiona Cunningham and Beth Prichard.

=head1 COPYRIGHT & LICENSE

Copyright (c) 1999-2006 The European Bioinformatics Institute and Genome Research Limited, and others. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
   3. The name Ensembl must not be used to endorse or promote products derived from this software without prior written permission. For written permission, please contact ensembl-dev@ebi.ac.uk
   4. Products derived from this software may not be called "Ensembl" nor may "Ensembl" appear in their names without prior written permission of the Ensembl developers.
   5. Redistributions of any form whatsoever must retain the following acknowledgment: "This product includes software developed by Ensembl (http://www.ensembl.org/).

THIS SOFTWARE IS PROVIDED BY THE ENSEMBL GROUP "AS IS" AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE ENSEMBL GROUP OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut


1;
