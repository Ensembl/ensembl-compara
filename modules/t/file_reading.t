use strict;
use warnings;

use Test::More;

use EnsEMBL::Web::File::Utils::IO;

my $test_file = "modules/t/data.bed";

ok(file_exists($test_file));
#ok(preview_file($test_file, {}));

done_testing();
