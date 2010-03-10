package EnsEMBL::Web::Data::News;

### NAME: EnsEMBL::Web::Data::News

### STATUS: Under Development

### DESCRIPTION:

use strict;
use warnings;

no warnings qw(uninitialized);

use EnsEMBL::Data::Manager::News;

use base qw(EnsEMBL::Web::Data);

sub get_stories {
  my $self = shift;
  my $criteria = shift || {};
  my $stories = [];

  ## Set some sensible defaults
  unless ($criteria->{'release'}) {
    $criteria->{'release'} = $self->hub->species_defs->ENSEMBL_VERSION;
  }
  unless ($criteria->{'status'}) {
    $criteria->{'status'} = 'handed_over';
  }

  $stories = EnsEMBL::Data::Manager::News->get_newsitems(
    query => [
      release_id  => $criteria->{'release'},
      status      => $criteria->{'status'},
    ],
    sort_by => 'priority',
  );

  return $stories;
}


1;

