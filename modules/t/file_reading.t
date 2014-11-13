use strict;
use warnings;

use Test::More;

use EnsEMBL::Web::File::Utils::IO qw/:all/;

my $test_file = "modules/t/data.bed";

ok(file_exists($test_file));
## Read one line of file
ok(preview_file($test_file, {limit => 1}), 'browser position chr19:6704537-7704536');

done_testing();
