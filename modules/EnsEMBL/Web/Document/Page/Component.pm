package EnsEMBL::Web::Document::Page::Component;

use strict;
use base qw(EnsEMBL::Web::Document::Page::Common);

sub _initialize_HTML {
  my $self = shift;
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::HTML::Content));
  $self->_init;
}

sub _initialize_Text {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Text::Content));
  $self->_init;
}

sub _initialize_Excel {
  my $self = shift; 
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Excel::Content));
  $self->_init;
}

sub _initialize_XML {
  my $self = shift;
  my $doctype_version = shift;
  
  if (!$doctype_version) {
    $doctype_version = 'xhtml';
    warn '[WARN] No DOCTYPE_VERSION (hence DTD) specified. Defaulting to xhtml, which is probably not what is required.';
  }
  
  $self->set_doc_type('XML', $doctype_version);
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::XML::Content));
  $self->_init;
}

sub _initialize_TextGz { shift->_initialize_Text; }
sub _initialize_DAS    { shift->_initialize_XML('DASGFF'); }

1;
