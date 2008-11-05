package EnsEMBL::Web::Component::Info::SpeciesBurp;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Apache::Error;
use EnsEMBL::Web::Apache::SendDecPage;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $object = $self->object;

  my $error_messages = \%EnsEMBL::Web::Apache::Error::error_messages;
  my $error_text     = $error_messages->{$ENV{ENSEMBL_FUNCTION}}->[1];
  
  my $html .= "<p>$error_text</p><br>";
  my $file  = '/ssi/species/ERROR_4xx.html';
  $html    .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file); 

  return $html;
}

1;
