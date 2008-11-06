package EnsEMBL::Web::Component::Gene::GeneSNPInfo;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}


sub content {
  my $self = shift;

  ### Adds text to Genetic variation nodes
  my $html = $self->_info(
    'Configuring the display',
    "<p>The <strong>'Configure this page'</strong> link in the menu on the left hand side of this page can be used to customise the exon context and types of SNPs displayed in both the tables below and the variation image.<br /> Please note the default 'Context' settings will probably filter out some intronic SNPs.</p><br />"
  );
 

  return $html;
}

1;


