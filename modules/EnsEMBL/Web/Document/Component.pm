package EnsEMBL::Web::Document::Component;

use strict;
use EnsEMBL::Web::Document::Common;

our @ISA = qw(EnsEMBL::Web::Document::Common);

use Data::Dumper qw(Dumper);

sub set_title {
  my $self  = shift;
  my $title = shift;
  $self->title->set( $self->species_defs->ENSEMBL_SITE_NAME.' release '.$self->species_defs->ENSEMBL_VERSION.': '.$self->species_defs->SPECIES_BIO_NAME.' '.$title );
}

sub _initialize_TextGz {
  my $self = shift; 
  $self->add_body_elements qw(
    content EnsEMBL::Web::Document::Text::Content
  );
  $self->_init();
}

sub _initialize_Text {
  my $self = shift; 
  $self->add_body_elements qw(
    content EnsEMBL::Web::Document::Text::Content
  );
  $self->_init();
}

sub _initialize_Excel {
  my $self = shift; 
  $self->add_body_elements qw(
    content EnsEMBL::Web::Document::Excel::Content
  );
  $self->_init();
}

sub _initialize_DAS {
  my $self = shift;
  $self->_initialize_XML( 'DASGFF' );
}

sub _initialize_XML {
  my $self = shift;
  my $doctype_version = shift;
  unless( $doctype_version ){
    $doctype_version = 'xhtml';
    warn( "[WARN] No DOCTYPE_VERSION (hence DTD) specified. ".
          "Defaulting to xhtml, which is probably not what is required.");
  }
  $self->set_doc_type('XML',$doctype_version);
  #$self->set_doc_type('XML','rss version="0.91"');
  $self->add_body_elements qw(
    content     EnsEMBL::Web::Document::XML::Content
  );
  $self->_init();
}

sub _initialize_HTML {
  my $self = shift;

## General layout for dynamic pages...

  $self->add_body_elements qw(content EnsEMBL::Web::Document::HTML::Content);
  $self->_init;
}

1;
