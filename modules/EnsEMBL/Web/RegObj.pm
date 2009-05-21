package EnsEMBL::Web::RegObj;

use strict;

use EnsEMBL::Web::Registry;

use base qw(Exporter);

our @EXPORT    = qw($ENSEMBL_WEB_REGISTRY);
our @EXPORT_OK = qw($ENSEMBL_WEB_REGISTRY);

our $ENSEMBL_WEB_REGISTRY;

1;
