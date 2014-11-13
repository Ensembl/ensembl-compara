use strict;
use warnings;

use Test::More;

use EnsEMBL::Web::File::Utils::IO qw/:all/;

my $test_file = "modules/t/data.bed";

ok(file_exists($test_file), 'Test file exists');
## Read one line of file
my $A = preview_file($test_file);
ok($A->[0] =~ /browser position chr19:6704537-7704536/, 'First line of file matches test');

done_testing();
