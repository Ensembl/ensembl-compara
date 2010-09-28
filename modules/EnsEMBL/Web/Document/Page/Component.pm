# $Id$

package EnsEMBL::Web::Document::Page::Component;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub initialize_HTML {
  my $self = shift;
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Element::Content));
}

sub initialize_Text {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Content));
}

sub initialize_Excel {
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

sub initialize_TextGz { shift->initialize_Text; }
sub initialize_DAS    { shift->initialize_XML('DASGFF'); }

1;
