use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use File::Basename qw( dirname );

use EnsEMBL::Web::File::Utils::IO qw/:all/;

my $SERVERROOT = dirname( $Bin );

my $test_file = $SERVERROOT."/t/output.txt";

## Read one line of file
my $input = [
            'This little piggy went to market',
            'This little piggy stayed at home',
            'This little piggy had roast beef',
            'This little piggy had none.',
            'And this little piggy went wheee-wheee-wheee, all the way home!',
            ];


ok(write_lines($test_file, {lines => $input}), "Wrote example content to test file $test_file.");

done_testing();
