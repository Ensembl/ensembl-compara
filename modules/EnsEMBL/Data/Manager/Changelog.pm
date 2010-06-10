package EnsEMBL::Data::Manager::Changelog;

### NAME: EnsEMBL::Data::Manager::Changelog
### Module to handle multiple Changelog entries 

### STATUS: Under Development

### DESCRIPTION:
### Enables fetching, counting, etc., of multiple E::D::Changelog objects

use strict;
use warnings;

use base qw(EnsEMBL::Data::Manager);

sub object_class { 'EnsEMBL::Data::Changelog' }

## Auto-generate query methods: get_changelogs, count_changelogs, etc
__PACKAGE__->make_manager_methods('changelogs');



1;
