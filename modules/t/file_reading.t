use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use File::Basename qw( dirname );

use EnsEMBL::Web::File::Utils::IO qw/:all/;

my $SERVERROOT = dirname( $Bin );

my $test_file = $SERVERROOT."/t/data.bed";

ok(file_exists($test_file), 'Test file exists');

## Read file into an array and check first line
my $A = read_lines($test_file);

ok($A->[0] =~ /browser position chr19:6704537-7704536/, 'First line of file matches test');

done_testing();
