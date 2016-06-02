=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Page::Component;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {}

sub initialize_Text {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Content));
}

sub initialize_XML {
  my $self = shift;
  my $doctype_version = shift;
  
  if (!$doctype_version) {
    $doctype_version = 'xhtml';
    warn '[WARN] No DOCTYPE_VERSION (hence DTD) specified. Defaulting to xhtml, which is probably not what is required.';
  }
  
  $self->set_doc_type('XML', $doctype_version);
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Content));
}

sub initialize_Excel  { shift->initialize_Text; }
sub initialize_RTF    { shift->initialize_HTML; }
sub initialize_JSON   { shift->initialize_Text; }
sub initialize_TextGz { shift->initialize_Text; }

1;
