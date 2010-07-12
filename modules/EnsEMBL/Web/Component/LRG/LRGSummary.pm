package EnsEMBL::Web::Component::LRG::LRGSummary;

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::TwoCol;

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self  = shift;
  my $label = 'Prediction Method';
  my $text  = 'Data from LRG database';
  my $table = new EnsEMBL::Web::Document::HTML::TwoCol;
  
  $table->add_row($label, "<p>$text</p>", 1);
  
  return $table->render;
}


1;
