package Preload;
use strict;
use warnings;

# This file potentially contains a load of use statements for modules which
# are needed by worker processes to service requests. These get loaded at
# child-init time, which is before a request comes in, so stops the first
# request being delayed. This seems to affect 20%-25% of requests, so is
# significant.
#
# In practice, at the moment, by far the biggest contributor to this time
# is ROSE, which is in the ensembl-orm plugin, so the only actual use
# statements are there, overriding this file.

1;
