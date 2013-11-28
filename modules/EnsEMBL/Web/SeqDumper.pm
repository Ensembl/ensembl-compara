=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::SeqDumper;

use strict;
use Bio::EnsEMBL::Utils::SeqDumper;

our @ISA = qw(Bio::EnsEMBL::Utils::SeqDumper);

=head2 EnsEMBL::Web::SeqDumper

This package is an extension of the Bio::EnsEMBL::Utils::SeqDumper
written so that it can print to a EnsEMBL::Web::Document::Panel
object (this requires that we override the print module to print
to a panel handle), and also override the dump function so that
it passes an EnsEMBL::Web::Document::Panel object around rather
than the "tied" file handle that the Bio::EnsEMBL::Utils::SeqDumper
does

=head3 sub print( $panel, $string );

This method overrides the parent class method so that "print"
print uses the panel's print function.

=cut

sub print {
  my ($self, $panel, $string) = @_;
  
  $self->{'string'} .= $string;
}

=head3 sub dump( $slice, $format, $panel );

This method overrides the parent class dump method so that
it passes the $panel around rather than the file handle that
the parent class passes around

=cut

sub dump {
  my ($self, $slice, $format, $panel) = @_;

  my $dump_handler = 'dump_' . lc($format);
  
  $self->{'string'} = '';
  
  if ($self->can($dump_handler)) {
    $self->$dump_handler($slice, $panel);
  }
  
  $self->{'string'} =~ s/\n/\r\n/g;
  
  return $self->{'string'};
}

1;
